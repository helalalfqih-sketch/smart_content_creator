import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart' as sp;
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../controllers/catalog_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../models/catalog_product_model.dart';
import '../../services/firebase_storage_service.dart';
import '../../services/unified_ai_service.dart';
import '../../services/secure_storage_service.dart';
import '../../core/storage/app_storage_service.dart';
import '../../theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';


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
            (_, i) => _ProductCard(
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
      () => _ProductFormScreen(editProduct: product),
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

    await shareProductWithImages(
      title: product.title,
      description: product.description,
      formattedPrice: product.formattedPrice,
      shareUrl: shareUrl,
      images: [product.imageLink, ...product.additionalImageLinks],
    );
  }
}

// =============================================================================
// 📦 بطاقة المنتج
// =============================================================================
class _ProductCard extends StatelessWidget {
  final CatalogProduct product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onShareFacebook;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
    required this.onShareFacebook,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = product.imageLink.isNotEmpty;
    final isNetwork = hasImage && product.imageLink.startsWith('http');

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111122),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: product.isSynced
                ? Colors.green.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صورة المنتج
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: SizedBox(
                      width: double.infinity,
                      child: hasImage
                          ? (isNetwork
                              ? Image.network(
                                  product.imageLink,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _placeholder(),
                                )
                              : Image.file(
                                  File(product.imageLink),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _placeholder(),
                                ))
                          : _placeholder(),
                    ),
                  ),
                  // شارة المزامنة والحالة
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // شارة الحالة (pending, approved, rejected)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: product.status == 'approved'
                                ? Colors.green.withValues(alpha: 0.85)
                                : product.status == 'rejected'
                                    ? Colors.red.withValues(alpha: 0.85)
                                    : Colors.amber.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            product.status == 'approved'
                                ? '✓ مقبول'
                                : product.status == 'rejected'
                                    ? '🚫 مرفوض'
                                    : '⏳ معلق',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontFamily: 'IBMPlexSansArabic',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // شارة المزامنة
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: product.isSynced
                                ? Colors.blue.withValues(alpha: 0.85)
                                : Colors.grey.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            product.isSynced ? '✓ متزامن Meta' : '⏳ غير متزامن',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontFamily: 'IBMPlexSansArabic',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // قائمة الإجراءات
                  Positioned(
                    top: 4,
                    right: 4,
                    child: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          color: Colors.white.withValues(alpha: 0.7), size: 18),
                      color: const Color(0xFF1A1A2E),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (_) {
                        final auth = Get.find<AuthController>();
                        final currentUid = auth.firebaseUid;
                        final isAdmin = auth.isAdmin;
                        final isOwner = product.creatorUid == currentUid;

                        return [
                          PopupMenuItem(
                            value: 'share',
                            child: Row(children: [
                              const Icon(Icons.share_rounded, color: Colors.purpleAccent, size: 16),
                              const SizedBox(width: 8),
                              const Text('مشاركة عامة',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'IBMPlexSansArabic')),
                            ]),
                          ),
                          PopupMenuItem(
                            value: 'facebook',
                            child: Row(children: [
                              const Icon(Icons.facebook_rounded, color: Color(0xFF1877F2), size: 16),
                              const SizedBox(width: 8),
                              const Text('نشر في فيسبوك',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'IBMPlexSansArabic')),
                            ]),
                          ),
                          if (isOwner || isAdmin) ...[
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [
                                const Icon(Icons.edit_rounded, color: Colors.blue, size: 16),
                                const SizedBox(width: 8),
                                const Text('تعديل',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'IBMPlexSansArabic')),
                              ]),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                const Icon(Icons.delete_outline_rounded,
                                    color: Colors.red, size: 16),
                                const SizedBox(width: 8),
                                const Text('حذف',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'IBMPlexSansArabic')),
                              ]),
                            ),
                          ],
                        ];
                      },
                      onSelected: (v) {
                        if (v == 'edit') {
                          onEdit();
                        } else if (v == 'delete') {
                          onDelete();
                        } else if (v == 'share') {
                          onShare();
                        } else if (v == 'facebook') {
                          onShareFacebook();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            // معلومات المنتج
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'IBMPlexSansArabic',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.formattedPrice,
                    style: const TextStyle(
                      color: Color(0xFF1877F2),
                      fontFamily: 'IBMPlexSansArabic',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (product.brand != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      product.brand!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Center(
        child: Icon(Icons.shopping_bag_outlined,
            color: Colors.white.withValues(alpha: 0.15), size: 36),
      ),
    );
  }
}

// =============================================================================
// 📝 شاشة نموذج إضافة / تعديل المنتج
// =============================================================================
class _ProductFormScreen extends StatefulWidget {
  final CatalogProduct? editProduct;
  const _ProductFormScreen({this.editProduct});

  @override
  State<_ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<_ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ctrl = Get.find<CatalogController>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _linkCtrl;
  late final TextEditingController _colorCtrl;
  late final TextEditingController _sizeCtrl;
  late final TextEditingController _gCategoryCtrl;
  late final TextEditingController _fbCategoryCtrl;
  late final TextEditingController _quantityCtrl;

  String _availability = 'in stock';
  String _condition = 'new';
  String _currency = 'YER';
  bool _isAnalyzing = false;
  bool _isOptimizingDesc = false;
  String _status = 'approved';
  String? _categoryId;

  final List<String> _currencies = ['YER', 'USD', 'SAR', 'AED', 'EGP'];
  final List<String> _availabilityOptions = ['in stock', 'out of stock'];
  final List<String> _conditionOptions = ['new', 'used'];

  @override
  void initState() {
    super.initState();
    final p = widget.editProduct;
    _titleCtrl = TextEditingController(text: p?.title ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _priceCtrl = TextEditingController(text: p != null ? p.price.toStringAsFixed(2) : '');
    _brandCtrl = TextEditingController(text: p?.brand ?? '');
    _linkCtrl = TextEditingController(text: p?.link ?? '');
    _colorCtrl = TextEditingController(text: p?.color ?? '');
    _sizeCtrl = TextEditingController(text: p?.size ?? '');
    _gCategoryCtrl = TextEditingController(text: p?.googleProductCategory ?? '');
    _fbCategoryCtrl = TextEditingController(text: p?.fbProductCategory ?? '');
    _quantityCtrl = TextEditingController(text: p != null ? p.quantity.toString() : '1');
    _availability = p?.availability ?? 'in stock';
    _condition = p?.condition ?? 'new';
    _currency = p?.currency ?? 'YER';
    _status = p?.status ?? 'approved';
    _categoryId = p?.categoryId;
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl, _descCtrl, _priceCtrl, _brandCtrl, _linkCtrl,
      _colorCtrl, _sizeCtrl, _gCategoryCtrl, _fbCategoryCtrl, _quantityCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: Text(
          widget.editProduct == null ? '➕ منتج جديد' : '✏️ تعديل المنتج',
          style: const TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _saveProduct,
            icon: const Icon(Icons.check_rounded, color: Colors.green),
            label: const Text(
              'حفظ',
              style: TextStyle(
                color: Colors.green,
                fontFamily: 'IBMPlexSansArabic',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── الصور ──
            _SectionTitle(title: '📷 صور المنتج'),
            const SizedBox(height: 12),
            _buildImagesSection(),
            const SizedBox(height: 20),

            // ── الفيديو ──
            _SectionTitle(title: '🎥 فيديو المنتج (اختياري)'),
            const SizedBox(height: 12),
            _buildVideoSection(),
            const SizedBox(height: 20),

            // ── AI ──
            _buildAiSection(),
            const SizedBox(height: 20),

            // ── Admin Approval ──
            if (Get.find<AuthController>().isAdmin) ...[
              _SectionTitle(title: '🛡️ اعتماد المنتج (للمشرفين)'),
              const SizedBox(height: 12),
              _buildDropdown(
                label: 'حالة المنتج',
                value: _status,
                items: ['pending', 'approved', 'rejected'],
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 20),
            ],

            // ── فئة المنتج ──
            _SectionTitle(title: '🗂️ فئة المنتج'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categoryId ?? 'other',
              dropdownColor: const Color(0xFF1A1A2E),
              style: const TextStyle(
                  color: Colors.white, fontFamily: 'IBMPlexSansArabic', fontSize: 13),
              decoration: InputDecoration(
                labelText: 'الفئة الرئيسية *',
                labelStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 12,
                ),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: predefinedCategories
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _categoryId = val;
                  final catInfo = predefinedCategories.firstWhere((e) => e.id == val);
                  // تحديث تصنيف جوجل وفيسبوك تلقائياً بالتصنيف القياسي للمجموعة
                  _gCategoryCtrl.text = catInfo.googleCategory;
                  _fbCategoryCtrl.text = catInfo.fbCategory;
                });
              },
            ),
            const SizedBox(height: 20),

            // ── العنوان ──
            _SectionTitle(title: '📌 معلومات المنتج'),
            const SizedBox(height: 12),
            _buildField(
              ctrl: _titleCtrl,
              label: 'عنوان المنتج *',
              hint: 'مثال: قميص قطني أزرق للرجال',
              validator: (v) => v == null || v.isEmpty ? 'العنوان مطلوب' : null,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionTitle(title: '📝 وصف المنتج *'),
                _isOptimizingDesc
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      )
                    : TextButton.icon(
                        onPressed: _optimizeDescriptionWithAi,
                        icon: const Icon(Icons.auto_awesome_rounded, size: 14, color: AppTheme.primary),
                        label: const Text(
                          'تحسين وتسعير ذكي 🪄',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 8),
            _buildField(
              ctrl: _descCtrl,
              label: 'وصف المنتج *',
              hint: 'ادخل تفاصيل المنتج والسعر هنا ثم اضغط تحسين ذكي...',
              maxLines: 5,
              validator: (v) => v == null || v.isEmpty ? 'الوصف مطلوب' : null,
            ),
            const SizedBox(height: 12),
            _buildField(
              ctrl: _brandCtrl,
              label: 'العلامة التجارية',
              hint: 'مثال: Samsung، Apple...',
            ),
            const SizedBox(height: 20),

            // ── السعر ──
            _SectionTitle(title: '💰 السعر والتوفر'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildField(
                    ctrl: _priceCtrl,
                    label: 'السعر *',
                    hint: '0.00',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'السعر مطلوب';
                      if (double.tryParse(v) == null) return 'رقم غير صحيح';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    label: 'العملة',
                    value: _currency,
                    items: _currencies,
                    onChanged: (v) => setState(() => _currency = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: 'التوفر',
                    value: _availability,
                    items: _availabilityOptions,
                    onChanged: (v) => setState(() => _availability = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    label: 'الحالة',
                    value: _condition,
                    items: _conditionOptions,
                    onChanged: (v) => setState(() => _condition = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildField(
              ctrl: _quantityCtrl,
              label: 'الكمية المتاحة',
              hint: '1',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),

            // ── تفاصيل إضافية ──
            _SectionTitle(title: '📂 تفاصيل إضافية'),
            const SizedBox(height: 12),
            _buildField(
              ctrl: _gCategoryCtrl,
              label: 'فئة جوجل (اختياري)',
              hint: 'مثال: Apparel & Accessories > Clothing',
            ),
            const SizedBox(height: 12),
            _buildField(
              ctrl: _fbCategoryCtrl,
              label: 'فئة فيسبوك (اختياري)',
              hint: 'مثال: Clothing & Accessories > Clothing',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    ctrl: _colorCtrl,
                    label: 'اللون',
                    hint: 'مثال: أزرق ملكي',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildField(
                    ctrl: _sizeCtrl,
                    label: 'المقاس',
                    hint: 'مثال: L، XL، 42',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildField(
              ctrl: _linkCtrl,
              label: 'رابط صفحة المنتج (اختياري)',
              hint: 'https://...',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 20),

            // ── مشاركة المنتج ──
            if (widget.editProduct != null) ...[
              _SectionTitle(title: '📤 مشاركة المنتج'),
              const SizedBox(height: 12),
              _buildShareSection(),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ── قسم المشاركة ──
  Widget _buildShareSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1A2E),
            const Color(0xFF16213E),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'شارك المنتج عبر:',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // ── واتساب ──
              Expanded(
                child: _ShareButton(
                  icon: Icons.chat_rounded,
                  label: 'واتساب',
                  color: const Color(0xFF25D366),
                  onTap: () => _shareToWhatsApp(),
                ),
              ),
              const SizedBox(width: 10),
              // ── فيسبوك ──
              Expanded(
                child: _ShareButton(
                  icon: Icons.facebook_rounded,
                  label: 'فيسبوك',
                  color: const Color(0xFF1877F2),
                  onTap: () {
                    if (widget.editProduct != null) {
                      final tempProduct = CatalogProduct(
                        id: widget.editProduct!.id,
                        title: _titleCtrl.text.trim(),
                        description: _descCtrl.text.trim(),
                        price: double.tryParse(_priceCtrl.text.trim()) ?? widget.editProduct!.price,
                        currency: _currency,
                        link: _linkCtrl.text.trim(),
                        imageLink: widget.editProduct!.imageLink,
                      );
                      _shareProductFromForm(tempProduct, platform: 'facebook');
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              // ── انستقرام ──
              Expanded(
                child: _ShareButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'انستقرام',
                  color: const Color(0xFFE1306C),
                  onTap: () => _shareToInstagram(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _shareToWhatsApp() async {
    final product = widget.editProduct;
    if (product == null) return;
    try {
      final secure = Get.find<SecureStorageService>();
      final sig = await secure.getStoreSignature();
      final phone = sig['phone'] ?? '';
      String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (!cleanPhone.startsWith('967') && cleanPhone.length == 9) {
        cleanPhone = '967$cleanPhone';
      }
      final title = _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : product.title;
      final price = _priceCtrl.text.trim().isNotEmpty ? '${ _priceCtrl.text.trim()} $_currency' : product.formattedPrice;
      final desc = _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : product.description;
      final text = Uri.encodeComponent(
        '🛍️ *$title*\n\n$desc\n\n💰 السعر: $price\n\nللطلب والاستفسار تواصل معنا 👇',
      );
      final waUrl = cleanPhone.isNotEmpty
          ? 'https://wa.me/$cleanPhone?text=$text'
          : 'https://wa.me/?text=$text';
      await launchUrl(Uri.parse(waUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      Get.snackbar('❌ خطأ', 'تعذر فتح واتساب: $e',
          backgroundColor: const Color(0xFF3A1A1A),
          colorText: const Color(0xFFE57373));
    }
  }

  Future<void> _shareToInstagram() async {
    try {
      final title = _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : (widget.editProduct?.title ?? '');
      final price = _priceCtrl.text.trim().isNotEmpty ? '${_priceCtrl.text.trim()} $_currency' : (widget.editProduct?.formattedPrice ?? '');
      final desc = _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : (widget.editProduct?.description ?? '');
      // مشاركة عبر نظام المشاركة المدمج
      await sp.SharePlus.instance.share(
        sp.ShareParams(
          text: '🛍️ $title\n\n$desc\n\n💰 السعر: $price\n\n#متجر #تسوق #عروض',
        ),
      );
    } catch (e) {
      Get.snackbar('❌ خطأ', 'تعذر المشاركة: $e',
          backgroundColor: const Color(0xFF3A1A1A),
          colorText: const Color(0xFFE57373));
    }
  }

  Future<void> _shareProductFromForm(CatalogProduct product, {String platform = 'general'}) async {
    String shareUrl = _linkCtrl.text.trim();
    if (shareUrl.isEmpty) {
      try {
        final secure = Get.find<SecureStorageService>();
        final sig = await secure.getStoreSignature();
        final phone = sig['phone'] ?? '';
        if (phone.isNotEmpty) {
          String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
          if (!cleanPhone.startsWith('967') && cleanPhone.length == 9) {
            cleanPhone = '967$cleanPhone';
          }
          final text = Uri.encodeComponent('السلام عليكم، أريد الاستفسار عن: ${product.title}');
          shareUrl = 'https://wa.me/$cleanPhone?text=$text';
        }
      } catch (_) {}
    }

    if (platform == 'facebook') {
      await ProductCatalogScreen.shareProductWithImages(
        title: product.title,
        description: product.description,
        formattedPrice: product.formattedPrice,
        shareUrl: shareUrl,
        images: List.from(ctrl.pickedImages),
      );
    }
  }

  // ── الصور ──
  Widget _buildImagesSection() {
    return Obx(() => Column(
          children: [
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // زر الإضافة
                  GestureDetector(
                    onTap: ctrl.pickImages,
                    child: Obx(() => ctrl.isUploadingMedia.value
                        ? const SizedBox(
                            width: 90,
                            height: 90,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF1877F2),
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : _AddMediaButton(icon: Icons.add_a_photo_rounded)),
                  ),
                  const SizedBox(width: 10),
                  // الصور المختارة
                  ...List.generate(ctrl.pickedImages.length, (i) {
                    final path = ctrl.pickedImages[i];
                    final isNetwork = path.startsWith('http');
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          margin: const EdgeInsets.only(left: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: i == 0
                                  ? const Color(0xFF1877F2)
                                  : Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: isNetwork
                                ? Image.network(path, fit: BoxFit.cover)
                                : Image.file(File(path), fit: BoxFit.cover),
                          ),
                        ),
                        if (i == 0)
                          Positioned(
                            bottom: -4,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1877F2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'رئيسية',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontFamily: 'IBMPlexSansArabic'),
                              ),
                            ),
                          ),
                        Positioned(
                          top: -6,
                          left: 4,
                          child: GestureDetector(
                            onTap: () => ctrl.removeImage(i),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 12),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            if (ctrl.pickedImages.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'أضف صورة رئيسية للمنتج على الأقل',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ));
  }

  // ── الفيديو ──
  Widget _buildVideoSection() {
    return Obx(() {
      final hasVideo = ctrl.pickedVideoPath.value.isNotEmpty;
      return Row(
        children: [
          GestureDetector(
            onTap: ctrl.pickVideo,
            child: _AddMediaButton(
              icon: hasVideo ? Icons.videocam_rounded : Icons.video_call_rounded,
              color: hasVideo ? Colors.green : null,
            ),
          ),
          const SizedBox(width: 12),
          if (hasVideo)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ctrl.pickedVideoPath.value.split('/').last.split('\\').last,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: ctrl.removeVideo,
                    child: Text(
                      'إزالة',
                      style: TextStyle(
                        color: Colors.red.withValues(alpha: 0.8),
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'اختر فيديو للمنتج (اختياري)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 12,
              ),
            ),
        ],
      );
    });
  }

  // ── AI ──
  Widget _buildAiSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.15),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              const Text(
                'توليد وصف بالذكاء الاصطناعي',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontFamily: 'IBMPlexSansArabic',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'صوّر المنتج أو اختر صورته لتوليد العنوان والوصف والفئة تلقائياً',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AiButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'كاميرا',
                  onTap: () => _analyzeWithAi(ImageSource.camera),
                  isLoading: _isAnalyzing,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AiButton(
                  icon: Icons.photo_library_rounded,
                  label: 'معرض الصور',
                  onTap: () => _analyzeWithAi(ImageSource.gallery),
                  isLoading: _isAnalyzing,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _analyzeWithAi(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;

      setState(() => _isAnalyzing = true);

      // رفع الصورة أولاً
      ctrl.pickedImages.insert(0, picked.path);
      final uid = ctrl.editingProduct.value?.id ?? Get.find<AuthController>().firebaseUid;
      if (uid != null) {
        final url = await Get.find<FirebaseStorageService>().uploadProductMedia(
          uid: uid,
          file: File(picked.path),
          mediaType: 'image',
        );
        if (url != null) ctrl.uploadedImageUrls.insert(0, url);
      }

      // ── تحليل الصورة بـ Prompt متخصص للكتالوج ──
      if (Get.isRegistered<UnifiedAIService>()) {
        final ai = Get.find<UnifiedAIService>();

        const catalogPrompt = """
أنت خبير تحليل منتجات للكتالوج التجاري.
انظر إلى هذه الصورة وأعطني المعلومات التالية بدقة شديدة.

قواعد إلزامية:
- جميع النصوص في الرد بالعربية فقط (ما عدا فئات Google وFacebook تبقى إنجليزية).
- لا تخترع معلومات غير موجودة في الصورة.
- إذا لم تجد معلومة اكتب: فارغ

أعد الرد بهذا الشكل الحرفي فقط:
===TITLE===
[اسم المنتج بالعربية - مختصر واحترافي]
===DESCRIPTION===
[اكتب وصفاً تسويقياً إعلانياً جذاباً واحترافياً للمنتج بالعربية بأسلوب منشور فيسبوك/تيك توك يجمع بين الخطاف القوي والفوائد والميزات الرائعة بشكل منسق مع الإيموجي المناسب وفواصل السطور، بدون أرقام هواتف أو معلومات تواصل أو روابط]
===BRAND===
[العلامة التجارية أو: فارغ]
===COLOR===
[اللون الرئيسي أو: فارغ]
===SIZE===
[المقاس أو الحجم أو: فارغ]
===PRICE===
[السعر بالريال اليمني كعدد رقمي فقط في حال كان مكتوباً أو معروفاً، أو: فارغ]
===SAR===
[السعر بالريال السعودي كعدد رقمي فقط في حال كان مكتوباً أو معروفاً، أو: فارغ]
===CATEGORY===
[اختر الفئة الرئيسية للمنتج من هذه القائمة فقط: المطبخ، التنظيم والتخزين، الجمال والعناية، الصحة والمساج، العدد والأدوات، السيارات، الرياضة واللياقة، الرحلات والخارجية، الأطفال والألعاب، الإلكترونيات، المنزل والديكور، الإضاءة والطاقة، الحيوانات الأليفة، متنوعات]
===G_CAT===
[فئة Google المناسبة بالإنجليزية مثل: Apparel & Accessories > Clothing أو: فارغ]
===FB_CAT===
[فئة Facebook المناسبة بالإنجليزية مثل: Clothing & Accessories > Clothing أو: فارغ]
===CONDITION===
[new أو used]
""";

        final imageFile = File(picked.path);
        final res = await ai.analyzeImage(imageFile, catalogPrompt);
        final rawResponse = res.description.trim();
        debugPrint('DEBUG: rawResponse from AI = "$rawResponse"');

        // تحليل الرد المهيكل باستخدام Regex لتفادي مشاكل تقسيم الفواصل
        final Map<String, String> parsed = {};
        final regExp = RegExp(r'===(TITLE|DESCRIPTION|BRAND|COLOR|SIZE|G_CAT|FB_CAT|CONDITION|HOOK|BODY|FEATURES|PRICE|SAR|CATEGORY)===\s*([\s\S]*?)(?=\s*===(?:TITLE|DESCRIPTION|BRAND|COLOR|SIZE|G_CAT|FB_CAT|CONDITION|HOOK|BODY|FEATURES|PRICE|SAR|CATEGORY)===|$)');
        for (final match in regExp.allMatches(rawResponse)) {
          final key = match.group(1)!.toUpperCase();
          final val = match.group(2)!.trim();
          if (val.isNotEmpty && val != 'فارغ') {
            parsed[key] = val;
          }
        }
        debugPrint('DEBUG: parsed map = $parsed');

        if (mounted) {
          setState(() {
            // ── العنوان ──
            final title = parsed['TITLE'] ?? '';
            if (title.isNotEmpty) _titleCtrl.text = title;

            // ── الوصف ──
            final desc = parsed['DESCRIPTION'] ?? '';
            if (desc.isNotEmpty) _descCtrl.text = desc;

            // ── العلامة التجارية ──
            final brand = parsed['BRAND'] ?? '';
            if (brand.isNotEmpty && _brandCtrl.text.isEmpty) _brandCtrl.text = brand;

            // ── اللون ──
            final color = parsed['COLOR'] ?? '';
            if (color.isNotEmpty && _colorCtrl.text.isEmpty) _colorCtrl.text = color;

            // ── المقاس ──
            final size = parsed['SIZE'] ?? '';
            if (size.isNotEmpty && _sizeCtrl.text.isEmpty) _sizeCtrl.text = size;

            // ── السعر ──
            final price = parsed['PRICE'] ?? '';
            if (price.isNotEmpty && _priceCtrl.text.isEmpty) _priceCtrl.text = price;

            // ── فئة المنتج الرئيسية ──
            final aiCat = parsed['CATEGORY'] ?? '';
            if (aiCat.isNotEmpty) {
              final matched = predefinedCategories.firstWhereOrNull(
                (c) => c.name.trim() == aiCat.trim() || c.id == aiCat.trim()
              );
              if (matched != null) {
                _categoryId = matched.id;
              }
            }

            // ── فئة Google ──
            final gCat = parsed['G_CAT'] ?? '';
            if (gCat.isNotEmpty) {
              _gCategoryCtrl.text = gCat;
            } else if (_categoryId != null) {
              final matched = predefinedCategories.firstWhereOrNull((c) => c.id == _categoryId);
              if (matched != null && _gCategoryCtrl.text.isEmpty) {
                _gCategoryCtrl.text = matched.googleCategory;
              }
            }

            // ── فئة Facebook ──
            final fbCat = parsed['FB_CAT'] ?? '';
            if (fbCat.isNotEmpty) {
              _fbCategoryCtrl.text = fbCat;
            } else if (_categoryId != null) {
              final matched = predefinedCategories.firstWhereOrNull((c) => c.id == _categoryId);
              if (matched != null && _fbCategoryCtrl.text.isEmpty) {
                _fbCategoryCtrl.text = matched.fbCategory;
              }
            }

            // ── الحالة ──
            final cond = parsed['CONDITION'] ?? '';
            if (cond == 'used') _condition = 'used';
          });

          Get.snackbar(
            '✅ تم التحليل',
            'تم ملء الحقول واستخراج البيانات والسعر تلقائياً!',
            backgroundColor: const Color(0xFF1A3A1A),
            colorText: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 4),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ AI analyze error: $e');
      if (mounted) {
        Get.snackbar(
          '❌ خطأ في التحليل',
          'تعذّر تحليل الصورة، حاول مرة أخرى.',
          backgroundColor: const Color(0xFF3A1A1A),
          colorText: const Color(0xFFE57373),
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _optimizeDescriptionWithAi() async {
    final rawText = _descCtrl.text.trim();
    if (rawText.isEmpty) {
      Get.snackbar(
        '⚠️ الوصف فارغ',
        'الرجاء كتابة أو لصق نص الوصف أولاً ليتم تنظيمه وتحديد السعر تلقائياً.',
        backgroundColor: const Color(0xFF3A251A),
        colorText: const Color(0xFFFFB74D),
        duration: const Duration(seconds: 4),
      );
      return;
    }

    setState(() => _isOptimizingDesc = true);

    try {
      // ── حماية آلية: فحص الأجهزة الطبية مسبقاً ──
      final medicalKeywords = [
        'جهاز طبي', 'medical device', 'ضغط الدم', 'blood pressure',
        'جلوكوز', 'glucose', 'ecg', 'نبض القلب',
        'oximeter', 'أكسجين الدم', 'oxygen', 'مستشفى', 'hospital',
        'تشخيص طبي', 'diagnosis', 'علاج طبي', 'دواء طبي', 'medicine',
        'أشعة x', 'x-ray', 'موجات فوق صوتية', 'ultrasound', 'منظار طبي', 'endoscope',
        'عملية جراحية', 'surgery', 'عيادة طبية', 'مريض طبي',
        'مختبر طبي', 'laboratory test', 'فحص طبي', 'ترمومتر طبي',
        'stethoscope', 'سماعة طبية', 'حقنة طبية', 'syringe', 'medical needle',
        'إبرة طبية', 'insulin', 'أنسولين', 'كولسترول', 'cholesterol',
      ];
      final lowerRawText = rawText.toLowerCase();
      final isMedicalDevice = medicalKeywords.any(
        (kw) => lowerRawText.contains(kw.toLowerCase()),
      );

      if (isMedicalDevice) {
        if (mounted) {
          Get.dialog(
            AlertDialog(
              backgroundColor: const Color(0xFF1A0A0A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.red, width: 1.5),
              ),
              title: const Row(
                children: [
                  Icon(Icons.medical_services_rounded, color: Colors.red, size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🚫 تحذير: جهاز طبي محظور!',
                      style: TextStyle(
                        color: Colors.red,
                        fontFamily: 'IBMPlexSansArabic',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              content: const Text(
                'تم اكتشاف أن هذا المنتج قد يكون جهازاً طبياً أو منتجاً صحياً.\n\n'
                '❌ منصة Meta ترفض هذه المنتجات وتحذف الكتالوج بأكمله عند إضافتها.\n\n'
                '⚠️ لا يمكن إكمال عملية حفظ هذا المنتج.\n\n'
                'إذا كان المنتج غير طبي، يرجى مراجعة الوصف وحذف أي كلمات طبية منه.',
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Get.back(),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'حسناً، سأعدّل الوصف',
                    style: TextStyle(
                      color: Colors.red,
                      fontFamily: 'IBMPlexSansArabic',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return;
      }

      // ── تنظيف تلقائي: حذف أرقام التواصل ومعلومات المتجر قبل الإرسال للـ AI ──
      String cleanedText = rawText;
      // حذف أرقام الهواتف اليمنية والدولية
      cleanedText = cleanedText.replaceAll(
        RegExp(r'(\+?967|00967)?[\s\-]?(7\d{8}|\d{3}[\s\-]?\d{3}[\s\-]?\d{4})'),
        '',
      );
      // حذف أسماء المتاجر الشائعة
      cleanedText = cleanedText.replaceAll(
        RegExp(r'اندكس\s*ستور|index\s*store|متجر\s*اندكس|للتواصل|للاستفسار|واتساب|whatsapp', caseSensitive: false),
        '',
      );
      // حذف فقرات الاتصال
      cleanedText = cleanedText.replaceAll(
        RegExp(r'(للطلب|للتواصل|للاستفسار|تواصل معنا|اتصل بنا|راسلنا)[^\n]*\n?', caseSensitive: false),
        '',
      );
      // تنظيف المسافات الزائدة
      cleanedText = cleanedText.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

      final prompt = """
تصرّف كخبير تسويق وتنظيم أوصاف منتجات.

سأرسل لك وصف منتج جاهز يحتوي على كلام غير مرتب + مميزات + سعر أو أكثر.
مهمتك تنفيذ الخطوات التالية بدقة شديدة دون إضافة أو اختراع أي معلومة جديدة.

⚠️ شروط إلزامية عامة:
- جميع الكلمات في الناتج النهائي تكون بدون أي علامات تشكيل (بدون حركات نهائيًا)
- استخرج السعر وطبق معادلة السعر المحددة بالأسفل.
- حدد فئة المنتج المناسبة لـ Google Product Category و Facebook Product Category.
- استخرج السمات الأخرى (الشركة المصنعة/العلامة التجارية، اللون، المقاس) إن وجدت.
- احذف تلقائياً أي أرقام هواتف أو معلومات تواصل أو أسماء متاجر من الوصف النهائي.
- احذف أي عبارات مثل "للتواصل"، "للطلب"، "واتساب"، "أرقام تليفون" من الوصف نهائياً.

المهمة الأولى: العنوان والهوك
1. أنشئ عنوانًا احترافيًا مختصرًا (Hook):
   - جذاب ومناسب للبيع
   - مستخرج من نفس الوصف فقط
2. تحت العنوان مباشرة:
   - ضع أهم وأقوى ميزة واحدة فقط تشد الانتباه.

المهمة الثانية: اعادة الصياغة والتنظيم للوصف
1. اعد صياغة الوصف ليكون مرتب، واضح، ومخترص.
2. يمنع منعًا باتًا اضافة اي معلومة جديدة او اختراع مميزات غير موجودة.
3. احذف اي كلام مكرر، غير مهم، او انشائي بلا فائدة.
4. استخرج مميزات المنتج فقط كقائمة نقاط واضحة.

المهمة الثالثة: معالجة السعر
1. اذا وجد سعر خاص بـ "الجنوب" → احذفه نهائيًا وتجاهله.
2. اذا وجد اكثر من سعر: اختر اقل سعر فقط.
3. طبق الزيادة على السعر المستخرج بالريال اليمني (YER) حسب الشرائح التالية:
   - من 500 الى 2500 ريال يمني ➜ اضف 1900
   - اكثر من 3000 الى 10000 ريال يمني ➜ اضف 2900
   - 10000 ريال يمني او اكثر ➜ اضف 3900
4. بعد الحساب والزيادة: حول السعر الناتج إلى رقم نفسي ينتهي بـ 900 (مثال: 6000 يصبح 5900، 7200 يصبح 6900، 10000 يصبح 9900، 12000 يصبح 11900 وهكذا).

المهمة الرابعة: التحويل للعملات
1. احسب السعر بالريال السعودي (SAR) بناءً على السعر النهائي بالريال اليمني بعد الزيادة والتقريب النفسي:
   - التحويل يكون على الأساس: 1 ريال سعودي = 140 ريال يمني (أي اقسم السعر اليمني على 140).
   - احذف الكسور تمامًا واكتب الرقم الصحيح فقط للسعودي.

أرجع النتيجة بالصيغة النصية التالية بدقة بالغة وبنفس الترتيب دائماً. يجب كتابة كل قسم، وإذا لم تجد قيمته اكتب: فارغ

===TITLE===
[العنوان المستخرج بدون حركات، أو: فارغ]
===HOOK===
[الهوك/الميزة القوية بدون حركات، أو: فارغ]
===BODY===
[اكتب وصفاً تسويقياً إعلانياً جذاباً واحترافياً ومفصلاً للمنتج بالعربية بأسلوب منشور فيسبوك/تيك توك يجمع بين الفوائد والميزات الرائعة بشكل منسق مع الإيموجي المناسب وفواصل السطور، بدون حركات وبدون أرقام هواتف، أو: فارغ]
===FEATURES===
[ميزة 1 بدون حركات، ميزة 2 بدون حركات، أو: فارغ]
===PRICE===
[السعر اليمني النهائي كعدد رقمي فقط، أو: فارغ]
===SAR===
[السعر السعودي النهائي كعدد رقمي فقط، أو: فارغ]
===G_CAT===
[فئة جوجل المناسبة للمنتج بالإنجليزية، مثل: Apparel & Accessories > Clothing، أو: فارغ]
===FB_CAT===
[فئة فيسبوك المناسبة للمنتج بالإنجليزية، مثل: Apparel & Accessories > Clothing، أو: فارغ]
===BRAND===
[الماركة، أو: فارغ]
===COLOR===
[اللون، أو: فارغ]
===SIZE===
[المقاس، أو: فارغ]

النص المراد تحليله:
\"\"\"
$cleanedText
\"\"\"
""";

      if (Get.isRegistered<UnifiedAIService>()) {
        final ai = Get.find<UnifiedAIService>();
        final response = await ai.generateText(prompt);
        final rawResponse = response.trim();
        debugPrint('DEBUG OPTIMIZE: rawResponse = "$rawResponse"');
        
        // تحليل الرد النصي المعتمد على الفواصل === باستخدام Regex لتفادي مشاكل تقسيم الفواصل
        final Map<String, String> parsed = {};
        final regExp = RegExp(r'===(TITLE|DESCRIPTION|BRAND|COLOR|SIZE|G_CAT|FB_CAT|CONDITION|HOOK|BODY|FEATURES|PRICE|SAR)===\s*([\s\S]*?)(?=\s*===(?:TITLE|DESCRIPTION|BRAND|COLOR|SIZE|G_CAT|FB_CAT|CONDITION|HOOK|BODY|FEATURES|PRICE|SAR)===|$)');
        for (final match in regExp.allMatches(rawResponse)) {
          final key = match.group(1)!.toUpperCase();
          final val = match.group(2)!.trim();
          if (val.isNotEmpty && val != 'فارغ' && val != 'empty') {
            parsed[key] = val;
          }
        }
        debugPrint('DEBUG OPTIMIZE: parsed map = $parsed');

        if (mounted) {
          final titleStr = parsed['TITLE'] ?? '';
          final hookStr = parsed['HOOK'] ?? '';
          final rephrasedBody = parsed['BODY'] ?? '';
          final featuresText = parsed['FEATURES'] ?? '';
          final priceYer = parsed['PRICE'] ?? '';
          final priceSar = parsed['SAR'] ?? '';
          final gCatRaw = parsed['G_CAT'] ?? '';
          final fbCatRaw = parsed['FB_CAT'] ?? '';
          final brand = parsed['BRAND'] ?? '';
          final color = parsed['COLOR'] ?? '';
          final size = parsed['SIZE'] ?? '';

          // بناء نص الوصف المنسق برمجياً
          String formattedDesc = '';
          if (titleStr.isNotEmpty) formattedDesc += '$titleStr\n';
          if (hookStr.isNotEmpty) formattedDesc += '$hookStr\n';
          if (formattedDesc.isNotEmpty) formattedDesc += '\n';
          if (rephrasedBody.isNotEmpty) formattedDesc += '$rephrasedBody\n\n';
          
          if (featuresText.isNotEmpty) {
            final fLines = featuresText.split('\n');
            for (final fl in fLines) {
              final line = fl.trim();
              if (line.isNotEmpty) {
                formattedDesc += '✅ ${line.replaceAll('✅', '').trim()}\n';
              }
            }
            formattedDesc += '\n';
          }
          
          if (priceYer.isNotEmpty) {
            formattedDesc += 'السعر: $priceYer ريال يمني\n';
          }
          if (priceSar.isNotEmpty) {
            formattedDesc += 'ما يعادل: $priceSar ريال سعودي';
          }

          setState(() {
            _titleCtrl.text = titleStr.isNotEmpty 
                ? (hookStr.isNotEmpty ? '$titleStr - $hookStr' : titleStr) 
                : _titleCtrl.text;
            _descCtrl.text = formattedDesc;
            
            if (priceYer.isNotEmpty) {
              _priceCtrl.text = priceYer;
            }
            
            final gCat = gCatRaw;
            if (gCat.isNotEmpty) _gCategoryCtrl.text = gCat;
            
            final fbCat = fbCatRaw;
            if (fbCat.isNotEmpty) _fbCategoryCtrl.text = fbCat;
            
            if (brand.isNotEmpty && _brandCtrl.text.isEmpty) _brandCtrl.text = brand;
            if (color.isNotEmpty && _colorCtrl.text.isEmpty) _colorCtrl.text = color;
            if (size.isNotEmpty && _sizeCtrl.text.isEmpty) _sizeCtrl.text = size;
          });

          Get.snackbar(
            '✨ اكتمل التحسين والتسعير',
            'تمت إعادة الصياغة وتحديث حقول السعر والفئة والخصائص تلقائياً!',
            backgroundColor: const Color(0xFF1A3A1A),
            colorText: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 4),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Description optimization error: $e');
      Get.snackbar(
        '❌ خطأ في معالجة الوصف',
        'حدث خطأ أثناء الاتصال بالذكاء الاصطناعي: $e',
        backgroundColor: const Color(0xFF3A1A1A),
        colorText: const Color(0xFFE57373),
        duration: const Duration(seconds: 4),
      );
    } finally {
      if (mounted) {
        setState(() => _isOptimizingDesc = false);
      }
    }
  }

  // دالة تنظيف الفئات من الرموز الزائدة في البداية مثل >
  String _cleanCategory(String s) {
    String res = s.trim();
    while (res.startsWith('>') || res.startsWith('<') || res.startsWith('-') || res.startsWith('/') || res.startsWith('.')) {
      res = res.substring(1).trim();
    }
    return res;
  }

  // ── حفظ المنتج ──
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (ctrl.pickedImages.isEmpty) {
      Get.snackbar(
        '⚠️ الصورة مطلوبة',
        'يجب إضافة صورة واحدة على الأقل للمنتج ليتم قبوله ومزامنته في Meta Commerce.',
        backgroundColor: const Color(0xFF3A251A),
        colorText: const Color(0xFFFFB74D),
        duration: const Duration(seconds: 3),
      );
      return;
    }

    final product = CatalogProduct(
      id: widget.editProduct?.id,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      availability: _availability,
      condition: _condition,
      price: double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
      currency: _currency,
      link: _linkCtrl.text.trim(),
      brand: _brandCtrl.text.trim().isNotEmpty ? _brandCtrl.text.trim() : null,
      googleProductCategory: _gCategoryCtrl.text.trim().isNotEmpty
          ? _cleanCategory(_gCategoryCtrl.text.trim())
          : null,
      fbProductCategory: _fbCategoryCtrl.text.trim().isNotEmpty
          ? _cleanCategory(_fbCategoryCtrl.text.trim())
          : null,
      categoryId: _categoryId,
      categoryName: predefinedCategories.firstWhereOrNull((e) => e.id == _categoryId)?.name,
      metaProductType: predefinedCategories.firstWhereOrNull((e) => e.id == _categoryId)?.fbCategory,
      quantity: int.tryParse(_quantityCtrl.text.trim()) ?? 1,
      color: _colorCtrl.text.trim().isNotEmpty ? _colorCtrl.text.trim() : null,
      size: _sizeCtrl.text.trim().isNotEmpty ? _sizeCtrl.text.trim() : null,
      creatorUid: widget.editProduct?.creatorUid,
      status: Get.find<AuthController>().isAdmin ? _status : 'approved',
    );

    await ctrl.saveProduct(product);

    if (widget.editProduct != null) {
      Get.back();
    } else {
      // تصفير كافة الحقول لإدخال منتج آخر مباشرة
      _formKey.currentState?.reset();
      _titleCtrl.clear();
      _descCtrl.clear();
      _priceCtrl.clear();
      _brandCtrl.clear();
      _linkCtrl.clear();
      _colorCtrl.clear();
      _sizeCtrl.clear();
      _gCategoryCtrl.clear();
      _fbCategoryCtrl.clear();
      _quantityCtrl.text = '1';
      
      setState(() {
        _availability = 'in stock';
        _condition = 'new';
        _currency = 'YER';
        _categoryId = null;
      });

      // تصفير الصور والفيديو المرفوعة
      ctrl.pickedImages.clear();
      ctrl.uploadedImageUrls.clear();
      ctrl.pickedVideoPath.value = '';
      ctrl.uploadedVideoUrl.value = '';
    }
  }

  Widget _buildField({
    required TextEditingController ctrl,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textDirection: TextDirection.rtl,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontFamily: 'IBMPlexSansArabic'),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontFamily: 'IBMPlexSansArabic',
        ),
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.25),
          fontFamily: 'IBMPlexSansArabic',
        ),
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1877F2), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      dropdownColor: const Color(0xFF1A1A2E),
      style: const TextStyle(
          color: Colors.white, fontFamily: 'IBMPlexSansArabic', fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 12,
        ),
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: items
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
    );
  }
}

// =============================================================================
// 🔧 Widgets مساعدة
// =============================================================================
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'IBMPlexSansArabic',
        fontWeight: FontWeight.bold,
        fontSize: 15,
      ),
    );
  }
}

class _AddMediaButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  const _AddMediaButton({required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: (color ?? Colors.white).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (color ?? Colors.white).withValues(alpha: 0.2),
          style: BorderStyle.solid,
        ),
      ),
      child: Icon(icon, color: color ?? Colors.white.withValues(alpha: 0.4), size: 32),
    );
  }
}

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

class _AiButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  const _AiButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        color: AppTheme.primary, strokeWidth: 2),
                  )
                : Icon(icon, color: AppTheme.primary, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.primary,
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 📤 زر المشاركة
// =============================================================================
class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontFamily: 'IBMPlexSansArabic',
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
