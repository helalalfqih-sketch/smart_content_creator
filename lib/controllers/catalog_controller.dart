import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/catalog_product_model.dart';
import '../services/db_service.dart';
import '../services/firebase_storage_service.dart';
import '../services/secure_storage_service.dart';
import '../controllers/auth_controller.dart';
import '../core/storage/app_storage_service.dart';
import '../core/repositories/catalog_repository.dart';
import '../core/repositories/back4app_catalog_repository.dart';

/// 🛍️ CatalogController
/// متحكم إدارة الكتالوج: إضافة / تعديل / حذف المنتجات، استيراد Excel، ومزامنة Meta
class CatalogController extends GetxController {
  DBService get _db => Get.find<DBService>();
  FirebaseStorageService get _storage => Get.find<FirebaseStorageService>();
  AppStorageService get _appStorage => Get.find<AppStorageService>();

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
  final isMigrating = false.obs; // تتبع حالة الترحيل السحابي
  final gridColumns = 2.obs; // تفضيل عدد الأعمدة في شبكة المنتجات

  // ---------------------------------------------------------------------------
  // 🖊️ حالة نموذج إضافة/تعديل المنتج
  // ---------------------------------------------------------------------------
  final editingProduct = Rx<CatalogProduct?>(null);
  final pickedImages = <String>[].obs; // مسارات الصور المحلية
  final uploadedImageUrls = <String>[].obs; // روابط الصور بعد الرفع
  final pickedVideoPath = ''.obs;
  final uploadedVideoUrl = ''.obs;

  StreamSubscription<QuerySnapshot>? _productsSubscription;

  String? get _uid => Get.isRegistered<AuthController>() ? Get.find<AuthController>().firebaseUid : null;

  CatalogRepository get _catalogRepo {
    if (Get.isRegistered<CatalogRepository>()) {
      return Get.find<CatalogRepository>();
    }
    return Back4AppCatalogRepository(
      dbService: _db,
      getFirebaseIdToken: () async {
        // Provide a real Firebase ID token for authenticated catalog access.
        // Returns null for anonymous/public catalog reads.
        final user = firebase_auth.FirebaseAuth.instance.currentUser;
        if (user == null) return null;
        try {
          return await user.getIdToken();
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
    
    // 🔄 Dual-Read Verification Mode: Back4App primary with Firestore fallback
    loadProducts();

    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      ever(auth.firebaseUidRx, (String? newUid) {
        if (newUid != null) {
          runMigrationIfNeeded();
        }
      });

      if (auth.firebaseUid != null) {
        runMigrationIfNeeded();
      }
    }
  }

  /// تحديث عدد الأعمدة في شبكة المنتجات وحفظ التفضيل محلياً
  Future<void> updateGridColumns(int count) async {
    if (count < 1 || count > 8) return;
    gridColumns.value = count;
    await _appStorage.writeInt('catalog_grid_columns', count);
  }

  void _cancelSubscription() {
    _productsSubscription?.cancel();
    _productsSubscription = null;
  }

  @override
  void onClose() {
    _cancelSubscription();
    super.onClose();
  }

  // ---------------------------------------------------------------------------
  // 🔄 Dual-Read Verification: Back4App Primary مع المقارنة والتخزين في SQLite
  // ---------------------------------------------------------------------------
  Future<void> loadProducts() async {
    isLoading.value = true;
    try {
      // 1. القراءة الأساسية من Back4App CatalogRepository
      final b4aProducts = await _catalogRepo.getProducts(forceRefresh: true);

      if (b4aProducts.isNotEmpty) {
        // 2. تخزين المنتجات في SQLite
        for (final p in b4aProducts) {
          await _db.insertRecord('catalog_products', p.toMap());
        }

        // 3. قراءة عدد السجلات من كاش SQLite
        final sqliteRows = await _db.getRecords('catalog_products', where: 'deleted_at IS NULL');
        final sqliteCount = sqliteRows.length;

        // 4. عرض المنتجات في الواجهة من نتيجة الـ Repository
        b4aProducts.sort((a, b) {
          final aTime = a.createdAt ?? DateTime.now();
          final bTime = b.createdAt ?? DateTime.now();
          return bTime.compareTo(aTime);
        });
        products.value = b4aProducts;
        isLoading.value = false;

        // 5. طباعة سجلات التحقق المطلوبة
        debugPrint('[CATALOG_SOURCE] primary=back4app');
        debugPrint('[CATALOG_COUNT] back4app=${b4aProducts.length}');
        debugPrint('[CATALOG_CACHE] sqlite=$sqliteCount');
        debugPrint('[CATALOG_UI] rendered=${products.length}');

        // 6. مقارنة غير متزامنة مع Firestore في الخلفية
        _compareWithFirestoreCount(b4aProducts.length);
        return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ [CATALOG_SOURCE] Back4App dual-read exception, falling back to Firestore: $e');
    }

    // 7. Fallback إلى Firestore عند حدوث أي خطأ بدون فقدان للبيانات
    debugPrint('[CATALOG_SOURCE] fallback=firestore');
    setupProductsListener();
  }

  void _compareWithFirestoreCount(int b4aCount) {
    FirebaseFirestore.instance
        .collection('catalog_products')
        .get()
        .then((snapshot) {
      final firestoreCount = snapshot.docs.length;
      debugPrint('[CATALOG_COMPARE] back4app=$b4aCount firestore=$firestoreCount delta=${b4aCount - firestoreCount}');
    }).catchError((e) {
      if (kDebugMode) debugPrint('⚠️ [CATALOG_COMPARE] Firestore comparison query: $e');
    });
  }

  // ---------------------------------------------------------------------------
  // 🎧 الاستماع للكتالوج من Firestore بالوقت الفعلي (Fallback Listener)
  // ---------------------------------------------------------------------------
  void setupProductsListener() {
    _cancelSubscription();
    isLoading.value = true;
    try {
      _productsSubscription = FirebaseFirestore.instance
          .collection('catalog_products')
          .snapshots()
          .listen((snapshot) {
        final parsed = snapshot.docs
            .map((doc) => CatalogProduct.fromMap(doc.data(), docId: doc.id))
            .toList();
        
        // ترتيب المنتجات حسب الأحدث
        parsed.sort((a, b) {
          final aTime = a.createdAt ?? DateTime.now();
          final bTime = b.createdAt ?? DateTime.now();
          return bTime.compareTo(aTime);
        });
        
        products.value = parsed;
        isLoading.value = false;
      }, onError: (e) {
        isLoading.value = false;
        if (kDebugMode) debugPrint('❌ CatalogController: Firestore listen error: $e');
      });
    } catch (e) {
      isLoading.value = false;
      if (kDebugMode) debugPrint('❌ CatalogController: setupProductsListener error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 🔍 تفكيك محتوى CSV بشكل آمن متوافق مع RFC 4180
  // ---------------------------------------------------------------------------
  List<List<String>> _parseCsv(String csvContent) {
    final lines = <List<String>>[];
    final currentFields = <String>[];
    final currentField = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < csvContent.length; i++) {
      final char = csvContent[i];

      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < csvContent.length && csvContent[i + 1] == '"') {
            currentField.write('"');
            i++; // تخطي علامة الاقتباس المزدوجة المهروبة
          } else {
            inQuotes = false;
          }
        } else {
          currentField.write(char);
        }
      } else {
        if (char == '"') {
          inQuotes = true;
        } else if (char == ',') {
          currentFields.add(currentField.toString());
          currentField.clear();
        } else if (char == '\n' || char == '\r') {
          if (char == '\r' && i + 1 < csvContent.length && csvContent[i + 1] == '\n') {
            i++;
          }
          currentFields.add(currentField.toString());
          currentField.clear();
          if (currentFields.isNotEmpty && currentFields.any((f) => f.isNotEmpty)) {
            lines.add(List.from(currentFields));
          }
          currentFields.clear();
        } else {
          currentField.write(char);
        }
      }
    }
    if (currentField.isNotEmpty || currentFields.isNotEmpty) {
      currentFields.add(currentField.toString());
      lines.add(currentFields);
    }
    return lines;
  }

  // ---------------------------------------------------------------------------
  // 🚀 ترحيل البيانات السابقة لمرة واحدة إلى Firestore
  // ---------------------------------------------------------------------------
  Future<void> runMigrationIfNeeded() async {
    final uid = _uid;
    if (uid == null) return;

    // 1. ترحيل المنتجات من SQLite/Cloud CSV القديم إلى Firestore العالمي
    final prefKey = 'catalog_migrated_to_firestore_$uid';
    final alreadyMigrated = _appStorage.readBool(prefKey) ?? false;
    if (!alreadyMigrated) {
      isMigrating.value = true;
      try {
        if (kDebugMode) debugPrint('🔄 CatalogController: البدء في ترحيل بيانات الكتالوج للمستخدم $uid');
        
        final localRows = await _db.getRecords(
          'catalog_products',
          orderBy: 'created_at DESC',
        );
        
        final List<CatalogProduct> toMigrate = [];
        if (localRows.isNotEmpty) {
          if (kDebugMode) debugPrint('📦 وجد ${localRows.length} منتج محلي في SQLite للترحيل');
          toMigrate.addAll(localRows.map((r) => CatalogProduct.fromMap(r)));
        } else {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final cloudFeedUrl = userDoc.data()?['catalog_feed_url'] as String?;
          
          if (cloudFeedUrl != null && cloudFeedUrl.isNotEmpty) {
            if (kDebugMode) debugPrint('☁️ SQLite فارغ. جاري سحب البيانات السحابية من: $cloudFeedUrl');
            final response = await http.get(Uri.parse(cloudFeedUrl));
            if (response.statusCode == 200) {
              final csvLines = _parseCsv(response.body);
              if (csvLines.length > 1) {
                for (int i = 1; i < csvLines.length; i++) {
                  final line = csvLines[i];
                  if (line.isEmpty || line[0].trim().isEmpty) continue;
                  try {
                    toMigrate.add(CatalogProduct.fromCsvFields(line));
                  } catch (e) {
                    if (kDebugMode) debugPrint('⚠️ فشل تحليل صف CSV رقم $i: $e');
                  }
                }
              }
            }
          }
        }

        if (toMigrate.isNotEmpty) {
          if (kDebugMode) debugPrint('⚡ جاري رفع ${toMigrate.length} منتج إلى Firestore...');
          
          final firestore = FirebaseFirestore.instance;
          final collRef = firestore.collection('catalog_products');
          
          final batchSize = 400;
          for (var i = 0; i < toMigrate.length; i += batchSize) {
            final batch = firestore.batch();
            final chunk = toMigrate.sublist(
              i,
              i + batchSize > toMigrate.length ? toMigrate.length : i + batchSize,
            );
            
            for (final prd in chunk) {
              final prdId = prd.id ?? 'prd_${DateTime.now().millisecondsSinceEpoch}_${prd.title.hashCode}';
              final docRef = collRef.doc(prdId);
              batch.set(
                docRef, 
                prd.copyWith(
                  id: prdId,
                  creatorUid: uid,
                  status: 'approved' // تعيين حالة المنتجات السابقة المهاجرة إلى approved لأنها كانت نشطة مسبقاً
                ).toMap(), 
                SetOptions(merge: true)
              );
            }
            await batch.commit();
          }
          if (kDebugMode) debugPrint('✅ تم رفع كافة المنتجات بنجاح لـ Firestore');
        }
        
        await _appStorage.writeBool(prefKey, true);
      } catch (e) {
        if (kDebugMode) debugPrint('❌ CatalogController: فشل ترحيل الكتالوج: $e');
      } finally {
        isMigrating.value = false;
      }
    }

    // 2. ترحيل المنتجات من مستودع Firestore الفردي (users/{uid}/catalog_products) إلى المستودع العالمي الجديد (catalog_products)
    final globalPrefKey = 'catalog_migrated_to_global_firestore_$uid';
    final alreadyGlobalMigrated = _appStorage.readBool(globalPrefKey) ?? false;
    if (!alreadyGlobalMigrated) {
      isMigrating.value = true;
      try {
        if (kDebugMode) debugPrint('🔄 CatalogController: البدء في نقل المنتجات من Firestore الفردي إلى العالمي للمستخدم $uid');
        
        final firestore = FirebaseFirestore.instance;
        final oldSnapshot = await firestore
            .collection('users')
            .doc(uid)
            .collection('catalog_products')
            .get();

        if (oldSnapshot.docs.isNotEmpty) {
          final batch = firestore.batch();
          final globalColl = firestore.collection('catalog_products');
          
          for (final doc in oldSnapshot.docs) {
            final oldData = doc.data();
            final product = CatalogProduct.fromMap(oldData);
            
            final updatedPrd = product.copyWith(
              creatorUid: uid,
              status: 'approved', // المنتجات المستوردة من السحابة الفردية تعتبر معتمدة مسبقاً
            );
            
            final docRef = globalColl.doc(doc.id);
            batch.set(docRef, updatedPrd.toMap(), SetOptions(merge: true));
          }
          await batch.commit();
          if (kDebugMode) debugPrint('✅ تم نقل ${oldSnapshot.docs.length} منتج بنجاح إلى المستودع العالمي.');
        }

        await _appStorage.writeBool(globalPrefKey, true);
      } catch (e) {
        if (kDebugMode) debugPrint('❌ CatalogController: فشل نقل المنتجات إلى المستودع العالمي: $e');
      } finally {
        isMigrating.value = false;
      }
    }

    // 3. إصلاح وتعديل حالة المنتجات الحالية المرفوعة لتصبح approved بشكل تلقائي لمرة واحدة
    final approvalPrefKey = 'catalog_existing_approved_fix';
    final alreadyApprovalFixed = _appStorage.readBool(approvalPrefKey) ?? false;
    if (!alreadyApprovalFixed) {
      try {
        final firestore = FirebaseFirestore.instance;
        final snapshot = await firestore.collection('catalog_products').get();
        if (snapshot.docs.isNotEmpty) {
          final batch = firestore.batch();
          for (final doc in snapshot.docs) {
            batch.update(doc.reference, {'status': 'approved'});
          }
          await batch.commit();
        }
        await _appStorage.writeBool(approvalPrefKey, true);
        if (kDebugMode) debugPrint('✅ تم تحويل جميع المنتجات المهاجرة إلى حالة معتمدة (Approved).');
      } catch (e) {
        if (kDebugMode) debugPrint('❌ CatalogController: فشل تعديل حالة المنتجات إلى Approved: $e');
      }
    }

    // 4. مسح روابط واتساب القديمة من حقل link في Firestore (مرة واحدة)
    final clearWaPrefKey = 'catalog_cleared_wa_links_v1';
    final alreadyClearedWa = _appStorage.readBool(clearWaPrefKey) ?? false;
    if (!alreadyClearedWa) {
      try {
        final firestore = FirebaseFirestore.instance;
        final snapshot = await firestore.collection('catalog_products').get();
        if (snapshot.docs.isNotEmpty) {
          const batchSize = 400;
          final docsToFix = snapshot.docs
              .where((d) {
                final lnk = (d.data()['link'] as String? ?? '');
                // امسح الرابط إذا كان رابط واتساب أو يحتوي على معرف المنتج (prd_)
                return lnk.contains('wa.me') || lnk.contains('prd_');
              })
              .toList();

          for (var i = 0; i < docsToFix.length; i += batchSize) {
            final batch = firestore.batch();
            final chunk = docsToFix.sublist(
              i,
              i + batchSize > docsToFix.length ? docsToFix.length : i + batchSize,
            );
            for (final doc in chunk) {
              // استبدل الرابط بصفحة المنتج في الموقع
              final productId = doc.data()['id']?.toString() ?? doc.id;
              final storeLink = productId.isNotEmpty
                  ? 'https://smartcontentcreator2.web.app/app/product/$productId'
                  : '';
              batch.update(doc.reference, {'link': storeLink});
            }
            await batch.commit();
          }

          if (kDebugMode) {
            debugPrint('✅ تم مسح روابط واتساب من ${docsToFix.length} منتج وتعيين روابط الموقع.');
          }
        }
        await _appStorage.writeBool(clearWaPrefKey, true);
      } catch (e) {
        if (kDebugMode) debugPrint('❌ CatalogController: فشل مسح روابط واتساب: $e');
      }
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
      products.refresh(); // تنشيط التحديث التفاعلي للمنتجات والترتيب
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

  // ---------------------------------------------------------------------------
  // ➕ إضافة منتج جديد
  // ---------------------------------------------------------------------------
  Future<bool> saveProduct(CatalogProduct product) async {
    try {
      final now = DateTime.now();
      final id = product.id?.isNotEmpty == true
          ? product.id!
          : 'prd_${now.millisecondsSinceEpoch}';

      final uid = _uid;

      final toSave = product.copyWith(
        id: id,
        imageLink: uploadedImageUrls.isNotEmpty
            ? uploadedImageUrls.first
            : product.imageLink,
        additionalImageLinks: uploadedImageUrls.length > 1
            ? uploadedImageUrls.sublist(1)
            : product.additionalImageLinks,
        videoUrl: uploadedVideoUrl.isNotEmpty
            ? uploadedVideoUrl.value
            : product.videoUrl,
        createdAt: product.createdAt ?? now,
        updatedAt: now,
        isSynced: false,
        creatorUid: product.creatorUid ?? uid ?? 'guest',
        status: product.status, // الحفاظ على حالة الموافقة أو وضع pending بشكل افتراضي
      );

      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('catalog_products')
            .doc(id)
            .set(toSave.toMap(), SetOptions(merge: true));
      } else {
        await _db.insertRecord('catalog_products', toSave.toMap());
      }
      
      resetForm();
      Get.snackbar(
        '✅ تم الحفظ',
        'تم حفظ المنتج بنجاح في الكتالوج',
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
  // 🔗 دمج صور إضافية مع منتج موجود مسبقاً (منع التكرار الهجين)
  // ---------------------------------------------------------------------------
  Future<void> mergeProductImages(CatalogProduct existingProduct, List<String> newLocalImages, List<String> newUrls) async {
    isSyncing.value = true;
    try {
      final List<String> uploadedUrls = [];
      
      // رفع أي صور محلية جديدة لم يتم رفعها بعد
      for (final path in newLocalImages) {
        if (path.startsWith('http')) {
          uploadedUrls.add(path);
          continue;
        }
        final file = File(path);
        if (await file.exists()) {
          final url = await Get.find<FirebaseStorageService>().uploadProductMedia(
            uid: existingProduct.creatorUid ?? _uid ?? 'guest',
            file: file,
            mediaType: 'image',
          );
          if (url != null) uploadedUrls.add(url);
        }
      }

      // دمج الصور الجديدة
      final mergedUrls = <String>{
        ...existingProduct.additionalImageLinks,
        ...uploadedUrls,
        ...newUrls
      }.toList();

      final updatedProduct = existingProduct.copyWith(
        additionalImageLinks: mergedUrls,
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      final uid = _uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('catalog_products')
            .doc(existingProduct.id)
            .set(updatedProduct.toMap(), SetOptions(merge: true));
      } else {
        await _db.updateRecord('catalog_products', updatedProduct.toMap(), where: 'id = ?', whereArgs: [existingProduct.id]);
      }

      Get.snackbar(
        '✅ تم دمج الصور',
        'تم إضافة الصور الجديدة للمنتج "${existingProduct.title}" بنجاح.',
        backgroundColor: const Color(0xFF1A3A1A),
        colorText: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 4),
      );
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
      
      // رفع أي صور محلية جديدة
      for (final path in newLocalImages) {
        if (path.startsWith('http')) {
          uploadedUrls.add(path);
          continue;
        }
        final file = File(path);
        if (await file.exists()) {
          final url = await Get.find<FirebaseStorageService>().uploadProductMedia(
            uid: existingProduct.creatorUid ?? _uid ?? 'guest',
            file: file,
            mediaType: 'image',
          );
          if (url != null) uploadedUrls.add(url);
        }
      }

      // دمج الصور
      final mergedUrls = <String>{
        ...existingProduct.additionalImageLinks,
        ...uploadedUrls,
        ...newUrls
      }.toList();

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

      final uid = _uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('catalog_products')
            .doc(existingProduct.id)
            .set(updatedProduct.toMap(), SetOptions(merge: true));
      } else {
        await _db.updateRecord('catalog_products', updatedProduct.toMap(), where: 'id = ?', whereArgs: [existingProduct.id]);
      }

      Get.snackbar(
        '✅ تم تحديث المنتج',
        'تم تحديث حقول وصور منتج "${existingProduct.title}" بنجاح بالبيانات الجديدة.',
        backgroundColor: const Color(0xFF1A3A1A),
        colorText: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 4),
      );
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
  // 🗑️ حذف منتج
  // ---------------------------------------------------------------------------
  Future<void> deleteProduct(String id) async {
    try {
      final uid = _uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('catalog_products')
            .doc(id)
            .delete();
      } else {
        await _db.deleteRecord(
          'catalog_products',
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      products.removeWhere((p) => p.id == id);
      Get.snackbar(
        '🗑️ تم الحذف',
        'تم حذف المنتج من الكتالوج',
        backgroundColor: const Color(0xFF1A1A3A),
        colorText: const Color(0xFF90CAF9),
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('❌ CatalogController: deleteProduct error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 🖼️ اختيار صور المنتج
  // ---------------------------------------------------------------------------
  Future<void> pickImages() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage(imageQuality: 85);
      if (picked.isEmpty) return;

      isUploadingMedia.value = true;
      final uid = _uid;
      if (uid == null) {
        // حفظ محلي مؤقت في غياب تسجيل الدخول
        pickedImages.addAll(picked.map((p) => p.path));
        uploadedImageUrls.addAll(picked.map((p) => p.path));
        return;
      }

      for (final xf in picked) {
        final file = File(xf.path);
        pickedImages.add(xf.path);
        final url = await _storage.uploadProductMedia(
          uid: uid,
          file: file,
          mediaType: 'image',
        );
        if (url != null) uploadedImageUrls.add(url);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ CatalogController: pickImages error: $e');
    } finally {
      isUploadingMedia.value = false;
    }
  }

  // ---------------------------------------------------------------------------
  // 🎥 اختيار فيديو المنتج
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

      final uid = _uid;
      if (uid == null) {
        uploadedVideoUrl.value = path;
        return;
      }

      final url = await _storage.uploadProductMedia(
        uid: uid,
        file: File(path),
        mediaType: 'video',
      );
      if (url != null) uploadedVideoUrl.value = url;
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
  // 📂 استيراد منتجات من Excel (.xlsx)
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

      final bytes = File(path).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      int imported = 0;
      int skipped = 0;

      final List<CatalogProduct> parsedProducts = [];

      for (final sheetName in excel.tables.keys) {
        final sheet = excel.tables[sheetName]!;
        final rows = sheet.rows;
        if (rows.isEmpty) continue;

        // تحديد سطر البداية (تخطي العناوين إن وجدت)
        int startRow = 0;
        if (rows.isNotEmpty) {
          final firstRowText = rows[0].map((c) => c?.value?.toString().toLowerCase() ?? '').toList();
          if (firstRowText.any((t) => t.contains('id') || t.contains('title') || t.contains('price') || t.contains('name'))) {
            startRow = 1;
          }
        }

        for (int i = startRow; i < rows.length; i++) {
          final row = rows[i];
          final cells = row.map((c) => c?.value).toList();
          if (cells.isEmpty) continue;

          // تخطي الصفوف الفارغة
          final firstCell = cells[0]?.toString().trim() ?? '';
          if (firstCell.isEmpty && (cells.length < 2 || (cells[1]?.toString().trim() ?? '').isEmpty)) {
            skipped++;
            continue;
          }

          try {
            final product = CatalogProduct.fromExcelRow(cells, i);
            parsedProducts.add(product);
            imported++;
          } catch (e) {
            skipped++;
            if (kDebugMode) debugPrint('⚠️ Skipped row $i: $e');
          }
        }
      }

      if (parsedProducts.isNotEmpty) {
        final uid = _uid;
        if (uid != null) {
          final firestore = FirebaseFirestore.instance;
          final collRef = firestore.collection('catalog_products');
          
          final batchSize = 400;
          for (var i = 0; i < parsedProducts.length; i += batchSize) {
            final batch = firestore.batch();
            final chunk = parsedProducts.sublist(
              i,
              i + batchSize > parsedProducts.length ? parsedProducts.length : i + batchSize,
            );
            
            for (final prd in chunk) {
              final prdId = prd.id?.isNotEmpty == true
                  ? prd.id!
                  : 'prd_${DateTime.now().millisecondsSinceEpoch}_${prd.title.hashCode}';
              final docRef = collRef.doc(prdId);
              batch.set(
                docRef, 
                prd.copyWith(
                  id: prdId,
                  creatorUid: uid,
                  status: 'pending' // الكتالوج المرفوع من Excel يحتاج مراجعة pending
                ).toMap(), 
                SetOptions(merge: true)
              );
            }
            await batch.commit();
          }
        } else {
          for (final prd in parsedProducts) {
            await _db.insertRecord('catalog_products', prd.toMap());
          }
        }
      }

      await loadProducts();
      Get.snackbar(
        '📂 اكتمل الاستيراد',
        'تم استيراد $imported منتج${skipped > 0 ? " (تم تخطي $skipped صف)" : ""}',
        backgroundColor: const Color(0xFF1A3A1A),
        colorText: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('❌ CatalogController: importFromExcel error: $e');
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
  // ☁️ مزامنة الكتالوج مع Meta (رفع CSV إلى Firebase Storage)
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
      // جلب بيانات المتجر وروابط التواصل الاجتماعي لتوليد روابط احتياطية ذكية
      final signature = await Get.find<SecureStorageService>().getStoreSignature();
      final phone = signature['phone'] ?? '';
      final instagramUrl = _appStorage.readString('instagram_profile_url') ?? '';

      // رابط الموقع الأساسي للمتجر
      const String storeBaseUrl = 'https://smartcontentcreator2.web.app/app';

      final buffer = StringBuffer();
      buffer.writeln(CatalogProduct.csvHeader);
      for (final product in approvedProducts) {
        // أولوية: رابط المنتج المحفوظ → صفحة المنتج في الموقع → واتساب
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

      // 2. رفع CSV إلى Firebase Storage (مسار عالمي موحد)
      final url = await _storage.uploadCatalogFeed(
        uid: uid,
        csvContent: csvContent,
      );

      if (url == null) {
        Get.snackbar(
          '❌ فشل الرفع',
          'حدث خطأ أثناء رفع ملف الكتالوج',
          backgroundColor: const Color(0xFF3A1A1A),
          colorText: const Color(0xFFE57373),
          duration: const Duration(seconds: 4),
        );
        return;
      }

      // 3. حفظ الرابط
      final formattedUrl = '$url&ext=.csv';
      feedUrl.value = formattedUrl;
      await _appStorage.writeString('catalog_feed_url', formattedUrl);

      // ✅ نسخ الرابط إلى الحافظة تلقائياً للتسهيل على المستخدم لمنع نسخ الروابط المبتورة (...)
      try {
        await Clipboard.setData(ClipboardData(text: formattedUrl));
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Failed to copy to clipboard: $e');
      }

      // 4. تحديث حالة المزامنة في قاعدة البيانات للمنتجات المعتمدة فقط
      final firestore = FirebaseFirestore.instance;
      final collRef = firestore.collection('catalog_products');
      
      final batchSize = 400;
      for (var i = 0; i < approvedProducts.length; i += batchSize) {
        final batch = firestore.batch();
        final chunk = approvedProducts.sublist(
          i,
          i + batchSize > approvedProducts.length ? approvedProducts.length : i + batchSize,
        );
        for (final prd in chunk) {
          if (prd.id != null) {
            final docRef = collRef.doc(prd.id);
            batch.update(docRef, {
              'is_synced': 1,
              'updated_at': DateTime.now().toIso8601String(),
            });
          }
        }
        await batch.commit();
      }

      // 5. حفظ الرابط في Firestore للمدير
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'catalog_feed_url': formattedUrl, 'catalog_synced_at': FieldValue.serverTimestamp()});
      } catch (_) {}

      Get.snackbar(
        '✅ تمت المزامنة ونسخ الرابط',
        'تم رفع الكتالوج ونسخ رابط التغذية تلقائياً إلى الحافظة! 📋',
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

  /// عدد المنتجات غير المتزامنة
  int get unsyncedCount => products.where((p) => !p.isSynced).length;
}
