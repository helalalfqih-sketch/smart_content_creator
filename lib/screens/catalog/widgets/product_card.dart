import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'catalog_product_image.dart';
import '../../../models/catalog_product_model.dart';
import '../../../controllers/auth_controller.dart';
import '../../../services/whatsapp_sync_service.dart';

/// 📇 كارت عرض المنتج في شبكة الكتالوج
class ProductCard extends StatelessWidget {
  final CatalogProduct product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onShareFacebook;
  final int columns;

  const ProductCard({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
    required this.onShareFacebook,
    this.columns = 2,
  });

  @override
  Widget build(BuildContext context) {
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
                  CatalogProductImage(
                    imageUrl: product.effectiveImageUrl,
                    productId: product.id,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    memCacheWidth: 350,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    placeholderWidget: _placeholder(),
                    errorWidget: _placeholder(),
                  ),
                  // شارة المزامنة والحالة
                  Positioned(
                    top: columns >= 4 ? 6 : 8,
                    left: columns >= 4 ? 6 : 8,
                    child: columns >= 4
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // نقطة الحالة
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: product.status == 'approved'
                                        ? Colors.green
                                        : product.status == 'rejected'
                                            ? Colors.red
                                            : Colors.amber,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                // نقطة المزامنة
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: product.isSynced ? Colors.blue : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // شارة الحالة (pending, approved, rejected)
                              Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: product.isSynced
                                      ? Colors.blue.withValues(alpha: 0.85)
                                      : Colors.grey.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  product.isSynced
                                      ? (columns == 3 ? '✓ متزامن' : '✓ متزامن Meta')
                                      : (columns == 3 ? '⏳ معلق' : '⏳ غير متزامن'),
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
                  // قائمة الإجراءات السريعة
                  Positioned(
                    top: columns >= 4 ? 2 : 4,
                    right: columns >= 4 ? 2 : 4,
                    child: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          color: Colors.white.withValues(alpha: 0.7), size: columns >= 4 ? 14 : 18),
                      padding: columns >= 4 ? EdgeInsets.zero : const EdgeInsets.all(8),
                      constraints: columns >= 4 ? const BoxConstraints(minWidth: 80) : null,
                      color: const Color(0xFF1A1A2E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (_) {
                        final auth = Get.find<AuthController>();
                        final currentUid = auth.firebaseUid;
                        final isAdmin = auth.isAdmin;
                        final isOwner = product.creatorUid == currentUid;

                        return [
                          PopupMenuItem(
                            value: 'whatsapp',
                            child: Row(children: [
                              const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 16),
                              const SizedBox(width: 8),
                              const Text('إرسال عبر واتساب',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'IBMPlexSansArabic')),
                            ]),
                          ),
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
                                const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 16),
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
                        if (v == 'whatsapp') {
                          _showSendWhatsAppDialog(context);
                        } else if (v == 'edit') {
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
              padding: EdgeInsets.all(columns >= 4 ? 6 : 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: columns >= 4 ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'IBMPlexSansArabic',
                      fontWeight: FontWeight.bold,
                      fontSize: columns >= 4 ? 10 : 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.formattedPrice,
                    style: TextStyle(
                      color: const Color(0xFF1877F2),
                      fontFamily: 'IBMPlexSansArabic',
                      fontWeight: FontWeight.bold,
                      fontSize: columns >= 4 ? 11 : 13,
                    ),
                  ),
                  if (columns < 4 && product.brand != null && product.brand!.isNotEmpty) ...[
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

  void _showSendWhatsAppDialog(BuildContext context) {
    final phoneCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF141426),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366), size: 22),
            const SizedBox(width: 8),
            Text('إرسال "${product.title}" عبر واتساب',
                style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('أدخل رقم هاتف المستلم (مع مفتاح الدولة):',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              autofocus: true,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: '+9677XXXXXXXX',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF0A0A16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              final phone = phoneCtrl.text.trim();
              if (phone.isEmpty) return;
              Get.back();
              Get.snackbar('⏳ جاري الإرسال', 'جاري إرسال المنتج عبر WhatsApp Cloud API...',
                  backgroundColor: const Color(0xFF1A1A2E), colorText: Colors.white);
              final service = Get.isRegistered<WhatsAppSyncService>()
                  ? Get.find<WhatsAppSyncService>()
                  : Get.put(WhatsAppSyncService());
              final ok = await service.sendProductToWhatsApp(
                productId: product.productId.isNotEmpty ? product.productId : (product.id ?? ''),
                destinationPhone: phone,
              );
              if (ok) {
                Get.snackbar('✅ تم الإرسال', 'تم إرسال بطاقة المنتج بنجاح إلى $phone ✨',
                    backgroundColor: const Color(0xFF1A3A1A), colorText: const Color(0xFF4CAF50));
              } else {
                Get.snackbar('❌ خطأ', 'فشل إرسال المنتج عبر الواتساب',
                    backgroundColor: const Color(0xFF3A1A1A), colorText: const Color(0xFFE57373));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('إرسال الآن', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
