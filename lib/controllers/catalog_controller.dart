import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/catalog_product_model.dart';
import '../models/catalog_media_model.dart';
import '../services/db_service.dart';
import '../services/back4app_catalog_media_service.dart';
import '../services/secure_storage_service.dart';
import '../services/catalog_xlsx_import_service.dart';
import '../controllers/auth_controller.dart';
import '../core/storage/app_storage_service.dart';
import '../core/repositories/catalog_repository.dart';
import '../core/repositories/back4app_catalog_repository.dart';
import '../screens/catalog/widgets/catalog_product_image.dart';

/// 🛍️ CatalogController
/// متحكم إدارة الكتالوج الحصري عبر Back4App Cloud Code و SQLite:
/// إضافة / تعديل / حذف المنتجات، إدارة الوسائط، استيراد Excel، ومزامنة Meta
class CatalogController extends GetxController {
  DBService get _db => Get.find<DBService>();
  AppStorageService get _appStorage => Get.find<AppStorageService>();
  Back4AppCatalogMediaService get _mediaService =>
      Get.isRegistered<Back4AppCatalogMediaService>()
          ? Get.find<Back4AppCatalogMediaService>()
          : Get.put(Back4AppCatalogMediaService());

  // ---------------------------------------------------------------------------
  // 📊 المتغيرات التفاعلية (Reactive State)
  // ---------------------------------------------------------------------------
  final products = <CatalogProduct>[].obs;
  final isLoading = false.obs;
  final isSyncing = false.obs;
  final isImporting = false.obs;
  final isUploadingMedia = false.obs;
  final searchQuery = ''.obs;
  final feedUrl = ''.obs; // رابط الكتالوج لـ Meta
  final gridColumns = 2.obs; // تفضيل عدد الأعمدة في شبكة المنتجات

  // ---------------------------------------------------------------------------
  // 🖊️ حالة نموذج إضافة/تعديل المنتج
  // ---------------------------------------------------------------------------
  final editingProduct = Rx<CatalogProduct?>(null);
  final pickedImages = <String>[].obs; // مسارات الصور المحلية
  final uploadedImageUrls = <String>[].obs; // روابط الصور بعد الرفع
  final pickedVideoPath = ''.obs;
  final uploadedVideoUrl = ''.obs;

  String? get _uid => Get.isRegistered<AuthController>() ? Get.find<AuthController>().firebaseUid : null;

  CatalogRepository get _catalogRepo {
    if (Get.isRegistered<CatalogRepository>()) {
      return Get.find<CatalogRepository>();
    }
    return Back4AppCatalogRepository(
      dbService: _db,
      getFirebaseIdToken: () async {
        final user = firebase_auth.FirebaseAuth.instance.currentUser;
        if (user == null) return null;
        try {
          return await user.getIdToken(true);
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Failed to get Firebase ID token: $e');
          return null;
        }
      },
      getCurrentUid: () => _uid,
    );
  }

  @override
  void onInit() {
    super.onInit();
    loadCustomCategories();
    feedUrl.value = _appStorage.readString('catalog_feed_url') ?? '';
    gridColumns.value = _appStorage.readInt('catalog_grid_columns', defaultValue: 2) ?? 2;
    
    // 🏛️ تحميل المنتجات من Back4App مع الكاش المحلي SQLite
    loadProducts();
  }

  /// تحديث عدد الأعمدة في شبكة المنتجات وحفظ التفضيل محلياً
  Future<void> updateGridColumns(int count) async {
    if (count < 1 || count > 8) return;
    gridColumns.value = count;
    await _appStorage.writeInt('catalog_grid_columns', count);
  }

  // ---------------------------------------------------------------------------
  // 🏛️ التحميل الحصري للكتالوج: Back4App Primary -> SQLite Cache
  // ---------------------------------------------------------------------------
  Future<void> loadProducts() async {
    isLoading.value = true;
    CatalogProductImage.clearFailedCache();
    try {
      // 1. القراءة الأساسية لجميع الصفحات من Back4App CatalogRepository
      final b4aProducts = await _catalogRepo.getProducts(limit: 100, forceRefresh: true);

      if (b4aProducts.isNotEmpty) {
        // 2. قراءة كاش SQLite المحدث
        final sqliteRows = await _db.getRecords('catalog_products', where: 'deleted_at IS NULL');
        final sqliteCount = sqliteRows.length;

        // 3. عرض المنتجات في الواجهة
        b4aProducts.sort((a, b) {
          final aTime = a.createdAt ?? DateTime.now();
          final bTime = b.createdAt ?? DateTime.now();
          return bTime.compareTo(aTime);
        });
        products.value = b4aProducts;
        isLoading.value = false;

        // 4. طباعة سجلات الحالة الحصرية
        debugPrint('[CATALOG_SOURCE] primary=back4app');
        debugPrint('[CATALOG_COUNT] back4app=${b4aProducts.length}');
        debugPrint('[CATALOG_CACHE] sqlite=$sqliteCount');
        debugPrint('[CATALOG_UI] rendered=${products.length}');
        return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ [CATALOG_SOURCE] Back4App fetch exception: $e');
    }

    // 5. Fallback إلى كاش SQLite المحلي في حال عدم توفر الاتصال
    try {
      final localRows = await _db.getRecords('catalog_products', where: 'deleted_at IS NULL');
      final localProducts = localRows.map((r) => CatalogProduct.fromMap(r)).toList();
      localProducts.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.now();
        final bTime = b.createdAt ?? DateTime.now();
        return bTime.compareTo(aTime);
      });
      products.value = localProducts;
      debugPrint('[CATALOG_SOURCE] fallback=sqlite');
      debugPrint('[CATALOG_CACHE] sqlite=${localProducts.length}');
      debugPrint('[CATALOG_UI] rendered=${products.length}');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ SQLite local cache read error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ---------------------------------------------------------------------------
  // 🗂️ إدارة الفئات المخصصة (Custom Categories Management)
  // ---------------------------------------------------------------------------
  final customCategories = <ProductCategoryInfo>[].obs;

  List<ProductCategoryInfo> get allCategories => [...predefinedCategories, ...customCategories];

  void loadCustomCategories() {
    try {
      final jsonStr = _appStorage.readString('custom_categories');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = json.decode(jsonStr);
        customCategories.value = list
            .map((item) => ProductCategoryInfo.fromMap(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ CatalogController: loadCustomCategories error: $e');
    }
  }

  Future<void> saveCustomCategories() async {
    try {
      final list = customCategories.map((c) => c.toMap()).toList();
      await _appStorage.writeString('custom_categories', json.encode(list));
      products.refresh();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ CatalogController: saveCustomCategories error: $e');
    }
  }

  void addCustomCategory(ProductCategoryInfo cat) {
    customCategories.add(cat);
    saveCustomCategories();
  }

  void updateCustomCategory(String id, ProductCategoryInfo newCat) {
    final idx = customCategories.indexWhere((c) => c.id == id);
    if (idx != -1) {
      customCategories[idx] = newCat;
      saveCustomCategories();
    }
  }

  void deleteCustomCategory(String id) {
    customCategories.removeWhere((c) => c.id == id);
    saveCustomCategories();
  }

  final selectedCategory = 'الكل'.obs;
  final selectedSortOption = 'الأحدث'.obs;

  List<String> get categories {
    final list = <String>{};
    for (final p in products) {
      list.add(p.resolvedCategoryName);
    }
    final sorted = list.toList()..sort();
    return ['الكل', ...sorted];
  }

  // ---------------------------------------------------------------------------
  // 🔍 بحث وتصفية وترتيب المنتجات
  // ---------------------------------------------------------------------------
  List<CatalogProduct> get filteredProducts {
    final q = searchQuery.value.trim().toLowerCase();
    
    // 1. تصفية بالبحث
    var list = products.toList();
    if (q.isNotEmpty) {
      list = list.where((p) =>
          p.title.toLowerCase().contains(q) ||
          (p.brand?.toLowerCase().contains(q) ?? false) ||
          (p.description.toLowerCase().contains(q))).toList();
    }
    
    // 2. تصفية بالفئة
    final cat = selectedCategory.value;
    if (cat != 'الكل') {
      list = list.where((p) => p.resolvedCategoryName == cat).toList();
    }
    
    // 3. الترتيب
    final sort = selectedSortOption.value;
    if (sort == 'الأحدث') {
      list.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.now();
        final bTime = b.createdAt ?? DateTime.now();
        return bTime.compareTo(aTime);
      });
    } else if (sort == 'الأقدم') {
      list.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.now();
        final bTime = b.createdAt ?? DateTime.now();
        return aTime.compareTo(bTime);
      });
    } else if (sort == 'السعر: من الأعلى') {
      list.sort((a, b) => b.price.compareTo(a.price));
    } else if (sort == 'السعر: من الأقل') {
      list.sort((a, b) => a.price.compareTo(b.price));
    } else if (sort == 'بدون فيديو أولاً') {
      list.sort((a, b) {
        final aHasVideo = a.videoUrl != null && a.videoUrl!.trim().isNotEmpty;
        final bHasVideo = b.videoUrl != null && b.videoUrl!.trim().isNotEmpty;
        if (!aHasVideo && bHasVideo) return -1;
        if (aHasVideo && !bHasVideo) return 1;
        return 0;
      });
    } else if (sort == 'حسب الفئة') {
      list.sort((a, b) {
        final aCat = a.categoryName ?? '';
        final bCat = b.categoryName ?? '';
        return aCat.compareTo(bCat);
      });
    }
    
    return list;
  }

  /// التحقق من رفع جميع الوسائط المحلية إلى Back4App Parse Files والحصول على روابط HTTPS
  Future<void> _ensureMediaUploaded(String uid) async {
    for (int i = 0; i < pickedImages.length; i++) {
      final path = pickedImages[i];
      if (path.startsWith('http://') || path.startsWith('https://')) {
        if (!uploadedImageUrls.contains(path)) {
          uploadedImageUrls.add(path);
        }
      } else {
        final file = File(path);
        if (await file.exists()) {
          final url = await _mediaService.uploadProductMedia(
            file: file,
            mediaType: 'image',
            uid: uid,
          );
          if (url != null && url.startsWith('http')) {
            if (!uploadedImageUrls.contains(url)) {
              uploadedImageUrls.add(url);
            }
          }
        }
      }
    }

    if (pickedVideoPath.isNotEmpty && !pickedVideoPath.value.startsWith('http')) {
      final file = File(pickedVideoPath.value);
      if (await file.exists()) {
        final url = await _mediaService.uploadProductMedia(
          file: file,
          mediaType: 'video',
          uid: uid,
        );
        if (url != null && url.startsWith('http')) {
          uploadedVideoUrl.value = url;
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // ➕ إضافة / تعديل منتج (Authoritative Back4App Write)
  // ---------------------------------------------------------------------------
  Future<bool> saveProduct(CatalogProduct product) async {
    try {
      final uid = _uid ?? 'guest';
      await _ensureMediaUploaded(uid);

      // تنظيف واستخراج روابط الوسائط المعتمدة (HTTPS فقط)
      String finalImageLink = '';
      List<String> finalAdditionalLinks = [];
      String? finalVideoUrl;

      // 1. تحديد الصورة الرئيسية والصور الإضافية
      final validHttpsImages = uploadedImageUrls
          .where((u) => u.startsWith('http://') || u.startsWith('https://'))
          .toList();

      if (validHttpsImages.isNotEmpty) {
        finalImageLink = validHttpsImages.first;
        finalAdditionalLinks = validHttpsImages.length > 1 ? validHttpsImages.sublist(1) : [];
      } else if (product.imageLink.startsWith('http')) {
        finalImageLink = product.imageLink;
        finalAdditionalLinks = product.additionalImageLinks
            .where((u) => u.startsWith('http'))
            .toList();
      }

      // 2. تحديد الفيديو
      if (uploadedVideoUrl.value.startsWith('http')) {
        finalVideoUrl = uploadedVideoUrl.value;
      } else if (product.videoUrl != null && product.videoUrl!.startsWith('http')) {
        finalVideoUrl = product.videoUrl;
      }

      // تسجيل وسائط المنتج
      debugPrint('[CATALOG_MEDIA] imageLink=$finalImageLink');
      if (finalVideoUrl != null && finalVideoUrl.isNotEmpty) {
        debugPrint('[CATALOG_MEDIA] videoUrl=$finalVideoUrl');
      }

      // 🛑 التحقق الصارم من اكتمال رفع الوسائط المختارة قبل إنشاء المنتج
      final hasSelectedImages = pickedImages.isNotEmpty;
      final hasSelectedVideo = pickedVideoPath.isNotEmpty;

      if (hasSelectedImages && finalImageLink.isEmpty) {
        Get.snackbar(
          '❌ فشل رفع الصور',
          'فشل رفع الوسائط إلى الخادم. لم يتم حفظ المنتج.',
          backgroundColor: const Color(0xFF3A1A1A),
          colorText: const Color(0xFFE57373),
          duration: const Duration(seconds: 4),
        );
        return false;
      }

      if (hasSelectedVideo && (finalVideoUrl == null || finalVideoUrl.isEmpty)) {
        Get.snackbar(
          '❌ فشل رفع الفيديو',
          'فشل رفع الوسائط إلى الخادم. لم يتم حفظ المنتج.',
          backgroundColor: const Color(0xFF3A1A1A),
          colorText: const Color(0xFFE57373),
          duration: const Duration(seconds: 4),
        );
        return false;
      }

      // إنشاء معرف فريد وثابت (Idempotent)
      final now = DateTime.now();
      final pid = (product.id != null && product.id!.isNotEmpty)
          ? product.id!
          : (editingProduct.value?.id != null && editingProduct.value!.id!.isNotEmpty)
              ? editingProduct.value!.id!
              : 'prd_${now.millisecondsSinceEpoch}_${math.Random().nextInt(9999)}';

      final toSave = product.copyWith(
        id: pid,
        imageLink: finalImageLink,
        additionalImageLinks: finalAdditionalLinks,
        videoUrl: finalVideoUrl,
        createdAt: product.createdAt ?? now,
        updatedAt: now,
        isSynced: false,
        creatorUid: product.creatorUid ?? uid,
        status: product.status,
        syncVersion: product.syncVersion,
      );

      final isEdit = editingProduct.value != null || products.any((p) => p.id == pid);

      // 🏛️ الخطوة 1: الكتابة المعتمدة في Back4App كخادم أساسي وحيد
      final bool primarySuccess = isEdit
          ? await _catalogRepo.updateProduct(toSave)
          : await _catalogRepo.saveProduct(toSave);

      if (!primarySuccess) {
        Get.snackbar(
          '❌ خطأ في الحفظ',
          'تعذر حفظ المنتج في خادم Back4App. يرجى التحقق من الاتصال والمحاولة ثانية.',
          backgroundColor: const Color(0xFF3A1A1A),
          colorText: const Color(0xFFE57373),
          duration: const Duration(seconds: 4),
        );
        return false;
      }

      // 🎬 الخطوة 2: مزامنة كائنات وسائط المنتج CatalogProductMedia في Back4App
      if (finalImageLink.isNotEmpty && finalImageLink.startsWith('http')) {
        _catalogRepo.addProductMedia(CatalogProductMedia(
          productId: pid,
          type: 'image',
          url: finalImageLink,
          isPrimary: true,
          sortOrder: 0,
          dedupeKey: sha256.convert(utf8.encode('$pid|image|$finalImageLink')).toString(),
        )).catchError((e) {
          debugPrint('⚠️ Partial media add failure (primary image): $e');
          return false;
        });
      }

      for (int i = 0; i < finalAdditionalLinks.length; i++) {
        final addUrl = finalAdditionalLinks[i];
        _catalogRepo.addProductMedia(CatalogProductMedia(
          productId: pid,
          type: 'image',
          url: addUrl,
          isPrimary: false,
          sortOrder: i + 1,
          dedupeKey: sha256.convert(utf8.encode('$pid|image|$addUrl')).toString(),
        )).catchError((e) {
          debugPrint('⚠️ Partial media add failure (additional image $i): $e');
          return false;
        });
      }

      if (finalVideoUrl != null && finalVideoUrl.isNotEmpty && finalVideoUrl.startsWith('http')) {
        _catalogRepo.addProductMedia(CatalogProductMedia(
          productId: pid,
          type: 'video',
          url: finalVideoUrl,
          isPrimary: true,
          sortOrder: 0,
          dedupeKey: sha256.convert(utf8.encode('$pid|video|$finalVideoUrl')).toString(),
        )).catchError((e) {
          debugPrint('⚠️ Partial media add failure (video): $e');
          return false;
        });
      }

      // 🔄 الخطوة 3: تحديث الواجهة والكتالوج
      resetForm();
      await loadProducts();

      Get.snackbar(
        '✅ تم الحفظ',
        isEdit ? 'تم تحديث بيانات المنتج والوسائط بنجاح' : 'تم حفظ المنتج الجديد والوسائط بنجاح',
        backgroundColor: const Color(0xFF1A3A1A),
        colorText: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 3),
      );
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ CatalogController: saveProduct error: $e');
      Get.snackbar(
        '❌ خطأ',
        'فشل حفظ المنتج: $e',
        backgroundColor: const Color(0xFF3A1A1A),
        colorText: const Color(0xFFE57373),
        duration: const Duration(seconds: 4),
      );
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // 🔗 دمج صور إضافية مع منتج موجود مسبقاً
  // ---------------------------------------------------------------------------
  Future<void> mergeProductImages(CatalogProduct existingProduct, List<String> newLocalImages, List<String> newUrls) async {
    isSyncing.value = true;
    try {
      final List<String> uploadedUrls = [];
      final uid = existingProduct.creatorUid ?? _uid ?? 'guest';
      
      // رفع أي صور محلية جديدة عبر Back4App
      for (final path in newLocalImages) {
        if (path.startsWith('http')) {
          uploadedUrls.add(path);
          continue;
        }
        final file = File(path);
        if (await file.exists()) {
          final url = await _mediaService.uploadProductMedia(
            file: file,
            mediaType: 'image',
            uid: uid,
          );
          if (url != null && url.startsWith('http')) {
            uploadedUrls.add(url);
          }
        }
      }

      // دمج الصور الجديدة
      final mergedUrls = <String>{
        ...existingProduct.additionalImageLinks,
        ...uploadedUrls,
        ...newUrls
      }.where((u) => u.startsWith('http')).toList();

      final updatedProduct = existingProduct.copyWith(
        additionalImageLinks: mergedUrls,
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      final ok = await _catalogRepo.updateProduct(updatedProduct);
      if (ok) {
        for (final u in uploadedUrls) {
          _catalogRepo.addProductMedia(CatalogProductMedia(
            productId: existingProduct.id!,
            type: 'image',
            url: u,
            isPrimary: false,
            sortOrder: mergedUrls.indexOf(u) + 1,
            dedupeKey: sha256.convert(utf8.encode('${existingProduct.id}|image|$u')).toString(),
          )).catchError((_) => false);
        }
        await loadProducts();

        Get.snackbar(
          '✅ تم دمج الصور',
          'تم إضافة الصور الجديدة للمنتج "${existingProduct.title}" بنجاح.',
          backgroundColor: const Color(0xFF1A3A1A),
          colorText: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ CatalogController: mergeProductImages error: $e');
      Get.snackbar(
        '❌ فشل الدمج',
        'عفواً، تعذر دمج الصور: $e',
        backgroundColor: const Color(0xFF3A1A1A),
        colorText: const Color(0xFFE57373),
        duration: const Duration(seconds: 4),
      );
    } finally {
      isSyncing.value = false;
      resetForm();
    }
  }

  // ---------------------------------------------------------------------------
  // ✏️ تحديث منتج موجود بالكامل ببيانات الذكاء الاصطناعي الجديدة
  // ---------------------------------------------------------------------------
  Future<void> updateProductWithAiData(CatalogProduct existingProduct, Map<String, String> aiData, List<String> newLocalImages, List<String> newUrls) async {
    isSyncing.value = true;
    try {
      final List<String> uploadedUrls = [];
      final uid = existingProduct.creatorUid ?? _uid ?? 'guest';
      
      // رفع أي صور محلية جديدة عبر Back4App
      for (final path in newLocalImages) {
        if (path.startsWith('http')) {
          uploadedUrls.add(path);
          continue;
        }
        final file = File(path);
        if (await file.exists()) {
          final url = await _mediaService.uploadProductMedia(
            file: file,
            mediaType: 'image',
            uid: uid,
          );
          if (url != null && url.startsWith('http')) {
            uploadedUrls.add(url);
          }
        }
      }

      // دمج الصور
      final mergedUrls = <String>{
        ...existingProduct.additionalImageLinks,
        ...uploadedUrls,
        ...newUrls
      }.where((u) => u.startsWith('http')).toList();

      final extractedTitle = aiData['TITLE']?.trim() ?? aiData['product_name']?.trim() ?? existingProduct.title;
      final extractedBrand = aiData['BRAND']?.trim() ?? aiData['brand']?.trim() ?? existingProduct.brand;
      final extractedModel = aiData['MODEL']?.trim() ?? aiData['model']?.trim() ?? existingProduct.itemGroupId;
      final extractedBarcode = aiData['BARCODE']?.trim() ?? aiData['barcode']?.trim() ?? aiData['gtin']?.trim() ?? existingProduct.gtin;
      final extractedCategoryName = aiData['CATEGORY']?.trim() ?? aiData['category']?.trim() ?? existingProduct.categoryName;
      final extractedColor = aiData['COLOR']?.trim() ?? aiData['color']?.trim() ?? existingProduct.color;
      final extractedSize = aiData['SIZE']?.trim() ?? aiData['size']?.trim() ?? existingProduct.size;
      final extractedDesc = aiData['DESCRIPTION']?.trim() ?? aiData['description']?.trim() ?? existingProduct.description;
      final double extractedPrice = double.tryParse(aiData['PRICE']?.trim() ?? '') ?? existingProduct.price;

      final updatedProduct = existingProduct.copyWith(
        title: extractedTitle,
        description: extractedDesc,
        price: extractedPrice,
        brand: extractedBrand,
        itemGroupId: extractedModel,
        gtin: extractedBarcode,
        color: extractedColor,
        size: extractedSize,
        categoryName: extractedCategoryName,
        additionalImageLinks: mergedUrls,
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      final ok = await _catalogRepo.updateProduct(updatedProduct);
      if (ok) {
        for (final u in uploadedUrls) {
          _catalogRepo.addProductMedia(CatalogProductMedia(
            productId: existingProduct.id!,
            type: 'image',
            url: u,
            isPrimary: false,
            sortOrder: mergedUrls.indexOf(u) + 1,
            dedupeKey: sha256.convert(utf8.encode('${existingProduct.id}|image|$u')).toString(),
          )).catchError((_) => false);
        }
        await loadProducts();

        Get.snackbar(
          '✅ تم تحديث المنتج',
          'تم تحديث حقول وصور منتج "${existingProduct.title}" بنجاح بالبيانات الجديدة.',
          backgroundColor: const Color(0xFF1A3A1A),
          colorText: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ CatalogController: updateProductWithAiData error: $e');
      Get.snackbar(
        '❌ فشل التحديث',
        'عفواً، تعذر تحديث بيانات المنتج: $e',
        backgroundColor: const Color(0xFF3A1A1A),
        colorText: const Color(0xFFE57373),
        duration: const Duration(seconds: 4),
      );
    } finally {
      isSyncing.value = false;
      resetForm();
    }
  }

  // ---------------------------------------------------------------------------
  // 🗑️ حذف منتج من Back4App و SQLite
  // ---------------------------------------------------------------------------
  Future<void> deleteProduct(String id) async {
    try {
      final ok = await _catalogRepo.deleteProduct(id);
      if (ok) {
        products.removeWhere((p) => p.id == id);
        Get.snackbar(
          '🗑️ تم الحذف',
          'تم حذف المنتج من الكتالوج',
          backgroundColor: const Color(0xFF1A1A3A),
          colorText: const Color(0xFF90CAF9),
          duration: const Duration(seconds: 2),
        );
      } else {
        Get.snackbar(
          '❌ خطأ في الحذف',
          'تعذر حذف المنتج من خادم Back4App',
          backgroundColor: const Color(0xFF3A1A1A),
          colorText: const Color(0xFFE57373),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ CatalogController: deleteProduct error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 🖼️ اختيار صور المنتج ورفعها إلى Back4App Parse Files
  // ---------------------------------------------------------------------------
  Future<void> pickImages() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage(imageQuality: 85);
      if (picked.isEmpty) return;

      isUploadingMedia.value = true;
      final uid = _uid ?? 'guest';

      for (final xf in picked) {
        pickedImages.add(xf.path);
        final file = File(xf.path);
        final url = await _mediaService.uploadProductMedia(
          file: file,
          mediaType: 'image',
          uid: uid,
        );
        if (url != null && url.startsWith('http')) {
          uploadedImageUrls.add(url);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ CatalogController: pickImages error: $e');
    } finally {
      isUploadingMedia.value = false;
    }
  }

  // ---------------------------------------------------------------------------
  // 🎥 اختيار فيديو المنتج ورفعه إلى Back4App Parse Files
  // ---------------------------------------------------------------------------
  Future<void> pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final path = result.files.first.path;
      if (path == null) return;

      isUploadingMedia.value = true;
      pickedVideoPath.value = path;

      final uid = _uid ?? 'guest';
      final url = await _mediaService.uploadProductMedia(
        file: File(path),
        mediaType: 'video',
        uid: uid,
      );
      if (url != null && url.startsWith('http')) {
        uploadedVideoUrl.value = url;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ CatalogController: pickVideo error: $e');
    } finally {
      isUploadingMedia.value = false;
    }
  }

  void removeImage(int index) {
    if (index < pickedImages.length) pickedImages.removeAt(index);
    if (index < uploadedImageUrls.length) uploadedImageUrls.removeAt(index);
  }

  void removeVideo() {
    pickedVideoPath.value = '';
    uploadedVideoUrl.value = '';
  }

  // ---------------------------------------------------------------------------
  // 📂 استيراد منتجات من Excel (.xlsx) عبر Back4App Cloud Code
  // ---------------------------------------------------------------------------
  Future<void> importFromExcel() async {
    isImporting.value = true;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final path = result.files.first.path;
      if (path == null) return;

      final rawBytes = File(path).readAsBytesSync();
      final importResult = CatalogXlsxImportService.parseBytes(
        rawBytes,
        targetSheetName: 'recovery_reference',
      );

      final parsedProducts = importResult.products;
      final totalValid = importResult.validProductsCount;
      final skipped = importResult.invalidProductsCount;

      if (parsedProducts.isNotEmpty) {
        final uid = _uid ?? 'helal_admin';
        final prepared = parsedProducts.map((p) {
          final pid = (p.id != null && p.id!.isNotEmpty)
              ? p.id!
              : 'prd_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(9999)}';
          return p.copyWith(id: pid, creatorUid: uid, status: 'pending');
        }).toList();

        // حفظ دفعي مع Back4App
        final savedCount = await _catalogRepo.batchSaveProducts(prepared, batchSize: 25);

        await loadProducts();
        Get.snackbar(
          '📂 اكتمل الاستيراد',
          'تم استيراد $savedCount من إجمالي $totalValid منتج بنجاح${skipped > 0 ? " (تم تخطي $skipped صف غير صالح)" : ""}',
          backgroundColor: const Color(0xFF1A3A1A),
          colorText: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e, st) {
      debugPrint('❌ CatalogController: importFromExcel error: $e\n$st');
      Get.snackbar(
        '❌ خطأ في الاستيراد',
        e.toString(),
        backgroundColor: const Color(0xFF3A1A1A),
        colorText: const Color(0xFFE57373),
        duration: const Duration(seconds: 4),
      );
    } finally {
      isImporting.value = false;
    }
  }

  // ---------------------------------------------------------------------------
  // ☁️ مزامنة الكتالوج مع Meta (رفع CSV إلى Back4App Parse Files)
  // ---------------------------------------------------------------------------
  Future<void> syncToMeta() async {
    final approvedProducts = products.where((p) => p.status == 'approved').toList();

    if (approvedProducts.isEmpty) {
      Get.snackbar(
        '⚠️ لا توجد منتجات معتمدة',
        'يجب وجود منتجات معتمدة (approved) في الكتالوج للمزامنة مع Meta',
        backgroundColor: const Color(0xFF3A3A1A),
        colorText: const Color(0xFFFFC107),
        duration: const Duration(seconds: 4),
      );
      return;
    }

    final uid = _uid;
    if (uid == null) {
      Get.snackbar(
        '⚠️ تسجيل الدخول مطلوب',
        'يرجى تسجيل الدخول لمزامنة الكتالوج',
        backgroundColor: const Color(0xFF3A3A1A),
        colorText: const Color(0xFFFFC107),
        duration: const Duration(seconds: 3),
      );
      return;
    }

    isSyncing.value = true;
    try {
      // 1. توليد محتوى CSV
      final signature = await Get.find<SecureStorageService>().getStoreSignature();
      final phone = signature['phone'] ?? '';
      final instagramUrl = _appStorage.readString('instagram_profile_url') ?? '';
      const String storeBaseUrl = 'https://smartcontentcreator2.web.app/app';

      final buffer = StringBuffer();
      buffer.writeln(CatalogProduct.csvHeader);
      for (final product in approvedProducts) {
        String fallbackLink;
        if (product.link.trim().isNotEmpty) {
          fallbackLink = product.link.trim();
        } else if (product.id != null && product.id!.isNotEmpty) {
          fallbackLink = '$storeBaseUrl/product/${product.id}';
        } else if (phone.isNotEmpty) {
          String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
          if (!cleanPhone.startsWith('967') && cleanPhone.length == 9) {
            cleanPhone = '967$cleanPhone';
          }
          final text = Uri.encodeComponent('السلام عليكم، أريد الاستفسار عن منتج: ${product.title}');
          fallbackLink = 'https://wa.me/$cleanPhone?text=$text';
        } else if (instagramUrl.isNotEmpty) {
          fallbackLink = instagramUrl;
        } else {
          fallbackLink = storeBaseUrl;
        }

        buffer.writeln(product.toCsvRow(defaultLink: fallbackLink));
      }
      final csvContent = buffer.toString();

      // 2. رفع CSV إلى Back4App Parse Files
      final url = await _mediaService.uploadCatalogFeed(
        uid: uid,
        csvContent: csvContent,
      );

      if (url == null) {
        Get.snackbar(
          '❌ فشل الرفع',
          'حدث خطأ أثناء رفع ملف الكتالوج إلى الخادم',
          backgroundColor: const Color(0xFF3A1A1A),
          colorText: const Color(0xFFE57373),
          duration: const Duration(seconds: 4),
        );
        return;
      }

      // 3. حفظ الرابط ونسخه للحافظة
      feedUrl.value = url;
      await _appStorage.writeString('catalog_feed_url', url);

      try {
        await Clipboard.setData(ClipboardData(text: url));
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Failed to copy to clipboard: $e');
      }

      Get.snackbar(
        '✅ تمت المزامنة ونسخ الرابط',
        'تم رفع الكتالوج بنجاح ونسخ الرابط إلى الحافظة! 📋',
        backgroundColor: const Color(0xFF1A3A1A),
        colorText: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('❌ CatalogController: syncToMeta error: $e');
      Get.snackbar(
        '❌ خطأ في المزامنة',
        e.toString(),
        backgroundColor: const Color(0xFF3A1A1A),
        colorText: const Color(0xFFE57373),
        duration: const Duration(seconds: 4),
      );
    } finally {
      isSyncing.value = false;
    }
  }

  // ---------------------------------------------------------------------------
  // 🔧 مساعدات
  // ---------------------------------------------------------------------------
  void startEditing(CatalogProduct? product) {
    editingProduct.value = product;
    resetForm();
    if (product != null) {
      uploadedImageUrls.value = [product.imageLink, ...product.additionalImageLinks]
          .where((u) => u.isNotEmpty)
          .toList();
      pickedImages.value = List.from(uploadedImageUrls);
      uploadedVideoUrl.value = product.videoUrl ?? '';
      pickedVideoPath.value = product.videoUrl ?? '';
    }
  }

  void resetForm() {
    pickedImages.clear();
    uploadedImageUrls.clear();
    pickedVideoPath.value = '';
    uploadedVideoUrl.value = '';
    editingProduct.value = null;
  }

  int get unsyncedCount => products.where((p) => !p.isSynced).length;
}
