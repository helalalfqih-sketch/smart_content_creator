import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart' as sp;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../../controllers/catalog_controller.dart';
import '../../models/catalog_product_model.dart';
import '../../theme/app_theme.dart';
import '../../services/secure_storage_service.dart';
import '../../core/storage/app_storage_service.dart';
import 'widgets/product_card.dart';
import 'product_form_screen.dart';
import '../../services/facebook_page_service.dart';
import '../../controllers/settings_controller.dart';


class ProductCatalogScreen extends StatelessWidget {
  const ProductCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<CatalogController>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(ctrl),
          SliverToBoxAdapter(child: _buildFeedUrlCard(ctrl)),
          SliverToBoxAdapter(child: _buildActionButtons(ctrl)),
          SliverToBoxAdapter(child: _buildSearchBar(ctrl)),
          SliverToBoxAdapter(child: _buildSortSelector(ctrl)),
          SliverToBoxAdapter(child: _buildCategoryFilter(ctrl)),
          SliverToBoxAdapter(child: _buildStatsRow(ctrl)),
          _buildProductGrid(ctrl),
        ],
      ),
      floatingActionButton: _buildFab(ctrl),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 🔝 App Bar
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildSliverAppBar(CatalogController ctrl) {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: const Color(0xFF0D0D1A),
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          '🛍️ كتالوج ميتا',
          style: TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF1877F2), Color(0xFF0A0A0F)],
            ),
          ),
        ),
      ),
      actions: [
        Obx(() => ctrl.isSyncing.value
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                tooltip: 'مزامنة مع Meta',
                onPressed: ctrl.syncToMeta,
              )),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 🔗 بطاقة رابط التغذية
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildFeedUrlCard(CatalogController ctrl) {
    return Obx(() {
      final url = ctrl.feedUrl.value;
      if (url.isEmpty) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF1877F2).withValues(alpha: 0.2), Colors.transparent],
            begin: Alignment.topLeft,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1877F2).withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link_rounded, color: Color(0xFF1877F2), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'رابط الكتالوج الجاهز لـ Meta',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'IBMPlexSansArabic',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy_rounded,
                      color: Color(0xFF1877F2), size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: url));
                    Get.snackbar(
                      '✅ تم النسخ',
                      'الرابط جاهز للصق في Meta Commerce Manager',
                      backgroundColor: Colors.green.withValues(alpha: 0.2),
                      colorText: Colors.white,
                      duration: const Duration(seconds: 3),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              url,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                fontFamily: 'IBMPlexSansArabic',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📌 كيف تربطه بـ Meta Commerce Manager:',
                    style: TextStyle(
                      color: Colors.amber,
                      fontFamily: 'IBMPlexSansArabic',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...[
                    '1.'
                    
                  ]
                      .map((step) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              step,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontFamily: 'IBMPlexSansArabic',
                                fontSize: 11,
                              ),
                            ),
                          ))
                      ,
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 🔘 أزرار الإجراءات
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildActionButtons(CatalogController ctrl) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _ActionChip(
            icon: Icons.table_chart_rounded,
            label: 'استيراد Excel',
            color: Colors.green,
            isLoading: ctrl.isImporting,
            onTap: ctrl.importFromExcel,
          ),
          _ActionChip(
            icon: Icons.cloud_sync_rounded,
            label: 'مزامنة مع Meta',
            color: const Color(0xFF1877F2),
            isLoading: ctrl.isSyncing,
            onTap: ctrl.syncToMeta,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 🔍 شريط البحث
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildSearchBar(CatalogController ctrl) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: TextField(
        onChanged: (v) => ctrl.searchQuery.value = v,
        style: const TextStyle(color: Colors.white, fontFamily: 'IBMPlexSansArabic'),
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: 'ابحث عن منتج...',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontFamily: 'IBMPlexSansArabic',
          ),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.4)),
          filled: true,
          fillColor: const Color(0xFF1A1A2E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ↕️ محدد الترتيب (الأحدث/الأقدم/السعر)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildSortSelector(CatalogController ctrl) {
    return Obx(() {
      final currentSort = ctrl.selectedSortOption.value;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => _showSortBottomSheet(ctrl),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sort_rounded, color: Color(0xFF1877F2), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'ترتيب: $currentSort',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'IBMPlexSansArabic',
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70, size: 16),
                  ],
                ),
              ),
            ),
            if (ctrl.selectedCategory.value != 'الكل' || ctrl.selectedSortOption.value != 'الأحدث')
              GestureDetector(
                onTap: () {
                  ctrl.selectedCategory.value = 'الكل';
                  ctrl.selectedSortOption.value = 'الأحدث';
                },
                child: const Text(
                  'إعادة تعيين 🔄',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontFamily: 'IBMPlexSansArabic',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  void _showSortBottomSheet(CatalogController ctrl) {
    final options = ['الأحدث', 'الأقدم', 'السعر: من الأعلى', 'السعر: من الأقل', 'بدون فيديو أولاً', 'حسب الفئة'];
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ترتيب المنتجات حسب:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'IBMPlexSansArabic',
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ...options.map((opt) {
              final isSelected = ctrl.selectedSortOption.value == opt;
              return ListTile(
                title: Text(
                  opt,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF1877F2) : Colors.white70,
                    fontFamily: 'IBMPlexSansArabic',
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF1877F2))
                    : null,
                onTap: () {
                  ctrl.selectedSortOption.value = opt;
                  Get.back();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 🗂️ فلاتر الفئات
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildCategoryFilter(CatalogController ctrl) {
    return Obx(() {
      final cats = ctrl.categories;
      if (cats.length <= 1) return const SizedBox.shrink();

      return Container(
        height: 54,
        margin: const EdgeInsets.only(top: 12),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: cats.length,
          itemBuilder: (context, index) {
            final cat = cats[index];
            final isSelected = ctrl.selectedCategory.value == cat;
            
            // حساب عدد المنتجات والأشكال لهذه الفئة
            final count = ctrl.products.where((p) => cat == 'الكل' ? true : p.resolvedCategoryName == cat).length;
            
            String subtext = '';
            if (count == 1) {
              subtext = 'منتج واحد · شكل واحد';
            } else if (count == 2) {
              subtext = 'منتجين · شكلين';
            } else {
              subtext = '$count منتج · $count شكل متنوع';
            }

            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: () {
                  ctrl.selectedCategory.value = cat;
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1877F2) : const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF1877F2) : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat,
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtext,
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 9,
                          color: isSelected ? Colors.white.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 📊 إحصائيات الكتالوج
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildStatsRow(CatalogController ctrl) {
    return Obx(() => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              _StatBadge(
                label: 'المنتجات',
                value: ctrl.products.length.toString(),
                color: AppTheme.primary,
              ),
              const SizedBox(width: 10),
              _StatBadge(
                label: 'غير متزامن',
                value: ctrl.unsyncedCount.toString(),
                color: Colors.orange,
              ),
              const SizedBox(width: 10),
              _StatBadge(
                label: 'متزامن',
                value: (ctrl.products.length - ctrl.unsyncedCount).toString(),
                color: Colors.green,
              ),
            ],
          ),
        ));
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 🗂️ شبكة المنتجات
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildProductGrid(CatalogController ctrl) {
    return Obx(() {
      if (ctrl.isLoading.value) {
        return const SliverFillRemaining(
          child: Center(
            child: CircularProgressIndicator(color: Color(0xFF1877F2)),
          ),
        );
      }

      final items = ctrl.filteredProducts;
      if (items.isEmpty) {
        return SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_bag_outlined,
                    size: 72, color: Colors.white.withValues(alpha: 0.1)),
                const SizedBox(height: 16),
                Text(
                  'لا توجد منتجات بعد',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'اضغط + لإضافة منتج جديد أو استورد من Excel',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (_, i) => ProductCard(
              product: items[i],
              onEdit: () => _openProductForm(ctrl, product: items[i]),
              onDelete: () => _confirmDelete(ctrl, items[i]),
              onShare: () => _shareProduct(items[i], toFacebook: false),
              onShareFacebook: () => _shareProduct(items[i], toFacebook: true),
            ),
            childCount: items.length,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.72,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
        ),
      );
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ➕ زر الإضافة
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildFab(CatalogController ctrl) {
    return FloatingActionButton.extended(
      backgroundColor: const Color(0xFF1877F2),
      onPressed: () => _openProductForm(ctrl),
      icon: const Icon(Icons.add_rounded),
      label: const Text(
        'منتج جديد',
        style: TextStyle(fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.bold),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 📝 فتح نموذج إضافة / تعديل المنتج
  // ─────────────────────────────────────────────────────────────────────────────
  void _openProductForm(CatalogController ctrl, {CatalogProduct? product}) {
    ctrl.startEditing(product);
    Get.to(
      () => ProductFormScreen(editProduct: product),
      transition: Transition.downToUp,
    );
  }

  void _confirmDelete(CatalogController ctrl, CatalogProduct product) {
    Get.defaultDialog(
      title: 'حذف المنتج',
      titleStyle: const TextStyle(
        fontFamily: 'IBMPlexSansArabic',
        fontWeight: FontWeight.bold,
      ),
      middleText: 'هل أنت متأكد من حذف "${product.title}"؟',
      textConfirm: 'حذف',
      textCancel: 'إلغاء',
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () {
        Get.back();
        ctrl.deleteProduct(product.id!);
      },
    );
  }

  static Future<void> shareProductWithImages({
    required String title,
    required String description,
    required String formattedPrice,
    required String shareUrl,
    required List<String> images,
  }) async {
    // نعرض رابطاً نظيفاً فقط (بدون المعلمات المشفَّرة)
    final cleanLink = shareUrl.contains('wa.me/')
        ? 'للتواصل عبر واتساب 💬'
        : shareUrl;
    final text = '$title\n\n'
        '$description\n\n'
        'السعر: $formattedPrice\n\n'
        '$cleanLink';

    // نسخ النص للحافظة تلقائياً لسهولة اللصق في فيسبوك
    try {
      await Clipboard.setData(ClipboardData(text: text));
      Get.snackbar(
        '📋 تم نسخ الوصف للحافظة',
        'تم نسخ وصف المنتج تلقائياً! يمكنك لصقه بسهولة عند مشاركته في فيسبوك.',
        backgroundColor: const Color(0xFF1A1A3A),
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      debugPrint('Failed to copy description to clipboard: $e');
    }

    final List<sp.XFile> xFiles = [];
    final allImages = images.where((img) {
      if (img.isEmpty) return false;
      final lower = img.toLowerCase();
      // استبعاد الفيديوهات لتجنب فتح تيك توك أو تعليق المشاركة
      return !lower.endsWith('.mp4') &&
             !lower.endsWith('.mov') &&
             !lower.endsWith('.avi') &&
             !lower.endsWith('.3gp') &&
             !lower.endsWith('.mkv');
    }).toList();

    if (allImages.isNotEmpty) {
      Get.dialog(
        const Center(
          child: Card(
            color: Color(0xFF111122),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1877F2)),
                  SizedBox(height: 16),
                  Text(
                    'جاري تجهيز الصور للمشاركة...',
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      try {
        final tempDir = await getTemporaryDirectory();
        for (int i = 0; i < allImages.length; i++) {
          final imgPath = allImages[i];
          if (imgPath.startsWith('http')) {
            final response = await http.get(Uri.parse(imgPath));
            if (response.statusCode == 200) {
              final file = File('${tempDir.path}/share_temp_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg');
              await file.writeAsBytes(response.bodyBytes);
              xFiles.add(sp.XFile(file.path));
            }
          } else {
            final file = File(imgPath);
            if (await file.exists()) {
              xFiles.add(sp.XFile(imgPath));
            }
          }
        }
      } catch (e) {
        debugPrint('Error preparing images for share: $e');
      } finally {
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }
      }
    }

    if (xFiles.isNotEmpty) {
      await sp.SharePlus.instance.share(
        sp.ShareParams(
          files: xFiles,
          text: text,
        ),
      );
    } else {
      await sp.SharePlus.instance.share(
        sp.ShareParams(
          text: text,
        ),
      );
    }
  }

  Future<void> _shareProduct(CatalogProduct product, {bool toFacebook = false}) async {
    String shareUrl = product.link.trim();
    if (shareUrl.isEmpty) {
      // أولوية: صفحة المنتج في الموقع → واتساب (بدون معرف المنتج)
      if (product.id != null && product.id!.isNotEmpty) {
        shareUrl = 'https://smartcontentcreator-d49f2.web.app/app/product/${product.id}';
      } else {
        try {
          final secure = Get.find<SecureStorageService>();
          final sig = await secure.getStoreSignature();
          final phone = sig['phone'] ?? '';
          if (phone.isNotEmpty) {
            String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
            if (!cleanPhone.startsWith('967') && cleanPhone.length == 9) {
              cleanPhone = '967$cleanPhone';
            }
            final text = Uri.encodeComponent('السلام عليكم، أريد الاستفسار عن منتج: ${product.title}');
            shareUrl = 'https://wa.me/$cleanPhone?text=$text';
          } else {
            final appStorage = Get.find<AppStorageService>();
            final inst = appStorage.readString('instagram_profile_url') ?? '';
            shareUrl = inst.isNotEmpty ? inst : 'https://smartcontentcreator-d49f2.web.app/app';
          }
        } catch (_) {
          shareUrl = 'https://smartcontentcreator-d49f2.web.app/app';
        }
      }
    }

    if (toFacebook) {
      _startFacebookPublishFlow(product, shareUrl);
      return;
    }

    await shareProductWithImages(
      title: product.title,
      description: product.description,
      formattedPrice: product.formattedPrice,
      shareUrl: shareUrl,
      images: [product.imageLink, ...product.additionalImageLinks],
    );
  }

  Future<void> _startFacebookPublishFlow(CatalogProduct product, String shareUrl) async {
    final settings = Get.find<SettingsController>();
    if (settings.fbPageId.value.isEmpty || settings.fbPageToken.value.isEmpty) {
      Get.snackbar(
        '⚠️ فيسبوك غير مرتبط',
        'يرجى الذهاب للإعدادات وربط صفحة فيسبوك أولاً.',
        backgroundColor: const Color(0xFF3A3A1A),
        colorText: const Color(0xFFFFC107),
        duration: const Duration(seconds: 4),
      );
      return;
    }

    // تجهيز النص الأولي بدون روابط مع إضافة هاشتاقات ذكية للمنتج واليمن
    final categoryTags = _getCategoryHashtags(product);
    final initialText = '🛍️ ${product.title}\n\n${product.description}\n\n💰 السعر: ${product.formattedPrice}\n\n$categoryTags';
    final textCtrl = TextEditingController(text: initialText);

    // تجميع كل الصور المتوفرة
    final allPhotos = <String>[];
    if (product.imageLink.isNotEmpty) allPhotos.add(product.imageLink);
    allPhotos.addAll(product.additionalImageLinks.where((img) => img.isNotEmpty));

    // قائمة تفاعلية بالصور المختارة
    final selectedPhotos = <String>[].obs;
    selectedPhotos.addAll(allPhotos);

    // مقطع الفيديو المختار
    final hasVideo = product.videoUrl != null && product.videoUrl!.trim().isNotEmpty;
    final selectedVideo = (hasVideo ? product.videoUrl!.trim() : '').obs;

    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF0F0F1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // رأس النافذة
                Row(
                  children: [
                    const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 28),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'معاينة وتعديل المنشور 📢',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'IBMPlexSansArabic',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close, color: Colors.white60),
                    ),
                  ],
                ),
                const Divider(color: Colors.white10),
                const SizedBox(height: 12),

                // حقل تحرير النص
                const Text(
                  'نص المنشور (يمكنك تعديله وإضافة وسوم أو روابط):',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: textCtrl,
                  maxLines: 6,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'IBMPlexSansArabic'),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF161626),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1877F2), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),

                // شبكة الميديا
                if (allPhotos.isNotEmpty || hasVideo) ...[
                  const Text(
                    'الصور والفيديوهات المرفقة (اضغط لتضمين/إلغاء الميديا):',
                    style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Obx(() {
                    final items = <Widget>[];

                    // 1. مقطع الفيديو
                    if (hasVideo) {
                      final isVideoSelected = selectedVideo.value.isNotEmpty;
                      items.add(
                        GestureDetector(
                          onTap: () {
                            if (isVideoSelected) {
                              selectedVideo.value = '';
                            } else {
                              selectedVideo.value = product.videoUrl!.trim();
                              selectedPhotos.clear(); // إلغاء الصور
                            }
                          },
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E2F),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isVideoSelected ? const Color(0xFF4CAF50) : Colors.white10,
                                width: 1.5,
                              ),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.videocam_rounded, color: Colors.green, size: 28),
                                  SizedBox(height: 4),
                                  Text(
                                    'مقطع فيديو',
                                    style: TextStyle(color: Colors.white70, fontSize: 9, fontFamily: 'IBMPlexSansArabic'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    // 2. الصور
                    for (final photoUrl in allPhotos) {
                      final isPhotoSelected = selectedPhotos.contains(photoUrl);
                      items.add(
                        GestureDetector(
                          onTap: () {
                            if (isPhotoSelected) {
                              selectedPhotos.remove(photoUrl);
                            } else {
                              selectedPhotos.add(photoUrl);
                              selectedVideo.value = ''; // إلغاء الفيديو
                            }
                          },
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isPhotoSelected ? const Color(0xFF1877F2) : Colors.white10,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: photoUrl.startsWith('http')
                                      ? CachedNetworkImage(
                                          imageUrl: photoUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => const Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            color: const Color(0xFF1E1E2F),
                                            child: const Icon(Icons.broken_image, color: Colors.white30),
                                          ),
                                        )
                                      : kIsWeb
                                          ? Image.network(
                                              photoUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                color: const Color(0xFF1E1E2F),
                                                child: const Icon(Icons.broken_image, color: Colors.white30),
                                              ),
                                            )
                                          : Image.file(
                                              File(photoUrl),
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                color: const Color(0xFF1E1E2F),
                                                child: const Icon(Icons.broken_image, color: Colors.white30),
                                              ),
                                            ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Icon(
                                  isPhotoSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: isPhotoSelected ? const Color(0xFF1877F2) : Colors.white24,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.start,
                      children: items,
                    );
                  })
                ],
                const SizedBox(height: 24),

                // أزرار التحكم
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('إلغاء 🚫', style: TextStyle(color: Colors.white30, fontFamily: 'IBMPlexSansArabic')),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1877F2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: () {
                        final editedText = textCtrl.text.trim();
                        if (editedText.isEmpty) {
                          Get.snackbar('⚠️ تنبيه', 'نص المنشور لا يمكن أن يكون فارغاً');
                          return;
                        }
                        Get.back(); // إغلاق نافذة المعاينة
                        _executeFacebookCustomPublish(
                          product: product,
                          message: editedText,
                          photos: selectedPhotos.toList(),
                          video: selectedVideo.value,
                        );
                      },
                      child: const Text('تأكيد ونشر 🚀', style: TextStyle(color: Colors.white, fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _executeFacebookCustomPublish({
    required CatalogProduct product,
    required String message,
    required List<String> photos,
    required String video,
  }) async {
    final fbService = Get.find<FacebookPageService>();

    Get.dialog(
      const Center(
        child: Card(
          color: Color(0xFF111122),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF1877F2)),
                SizedBox(height: 16),
                Text(
                  'جاري نشر المنتج على صفحة فيسبوك...',
                  style: TextStyle(color: Colors.white, fontFamily: 'IBMPlexSansArabic', fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );

    try {
      final success = await fbService.publishCustomPost(
        message: message,
        selectedPhotos: photos,
        selectedVideo: video,
      );

      if (Get.isDialogOpen ?? false) Get.back();

      if (success) {
        Get.snackbar(
          '✅ تم النشر بنجاح',
          'تم نشر المنتج "${product.title}" على صفحة فيسبوك الخاصة بك.',
          backgroundColor: const Color(0xFF1A3A1A),
          colorText: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 4),
        );
      } else {
        Get.snackbar(
          '❌ فشل النشر',
          'تعذر نشر المنتج على صفحة فيسبوك. يرجى التحقق من الاتصال أو صلاحيات الرمز.',
          backgroundColor: const Color(0xFF3A1A1A),
          colorText: const Color(0xFFE57373),
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        '❌ خطأ في النشر',
        e.toString(),
        backgroundColor: const Color(0xFF3A1A1A),
        colorText: const Color(0xFFE57373),
        duration: const Duration(seconds: 4),
      );
    }
  }

  String _getCategoryHashtags(CatalogProduct product) {
    final title = product.title.toLowerCase();
    final category = (product.categoryName ?? '').toLowerCase();
    final List<String> tags = ['#اندكس_ستور', '#صنعاء', '#اليمن'];
    
    // تصنيف ذكي للمنتج بناءً على العنوان أو الفئة لإدراج هاشتاقات ملائمة
    if (category.contains('ملابس') || category.contains('أزياء') || title.contains('قميص') || title.contains('فستان') || title.contains('بنطلون') || title.contains('جاكيت')) {
      tags.addAll(['#ملابس', '#موضة', '#أزياء_اليمن']);
    } else if (category.contains('إلكترونيات') || category.contains('طاقة') || title.contains('شاحن') || title.contains('سماعة') || title.contains('هاتف') || title.contains('تلفون')) {
      tags.addAll(['#إلكترونيات', '#تقنية', '#اكسسوارات_جوال']);
    } else if (category.contains('مطبخ') || category.contains('منزل') || category.contains('تخزين') || title.contains('مطبخ') || title.contains('ديكور') || title.contains('منظم')) {
      tags.addAll(['#أدوات_منزلية', '#منزل_جميل', '#مطبخ_عصري']);
    } else if (category.contains('جمال') || category.contains('عناية') || category.contains('صحة') || title.contains('عطر') || title.contains('كريم') || title.contains('بشرة') || title.contains('مساج')) {
      tags.addAll(['#جمال_وعناية', '#عناية_بالبشرة', '#صحة_وجمال']);
    } else if (category.contains('سيارات') || title.contains('سيارة') || title.contains('منظف سيارة')) {
      tags.addAll(['#سيارات', '#اكسسوارات_سيارات', '#اليمن_سيارات']);
    } else if (category.contains('رياضة') || title.contains('رياضي') || title.contains('تنحيف') || title.contains('تمارين')) {
      tags.addAll(['#رياضة', '#لياقة', '#صحة_ورشاقة']);
    } else {
      tags.addAll(['#تسوق_اونلاين', '#عروض_تخفيضات', '#توصيل_سريع']);
    }
    
    return tags.join(' ');
  }
}

// =============================================================================
// 🔧 Widgets مساعدة
// =============================================================================
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final RxBool isLoading;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() => GestureDetector(
          onTap: isLoading.value ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                isLoading.value
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: color, strokeWidth: 2),
                      )
                    : Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontFamily: 'IBMPlexSansArabic',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontFamily: 'IBMPlexSansArabic',
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
