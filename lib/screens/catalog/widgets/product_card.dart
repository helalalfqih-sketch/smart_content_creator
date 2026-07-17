import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../models/catalog_product_model.dart';
import '../../../controllers/auth_controller.dart';

/// 📇 كارت عرض المنتج في شبكة الكتالوج مع تحسينات الأداء والذاكرة
class ProductCard extends StatelessWidget {
  final CatalogProduct product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onShareFacebook;

  const ProductCard({
    super.key,
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
                      height: double.infinity,
                      child: hasImage
                          ? (isNetwork
                              ? CachedNetworkImage(
                                  imageUrl: product.imageLink,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Shimmer.fromColors(
                                    baseColor: const Color(0xFF1A1A2E),
                                    highlightColor: const Color(0xFF2E2E4A),
                                    child: Container(color: const Color(0xFF1A1A2E)),
                                  ),
                                  errorWidget: (context, url, error) => _placeholder(),
                                )
                              : kIsWeb
                                  ? Image.network(
                                      product.imageLink,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _placeholder(),
                                    )
                                  : Image.file(
                                      File(product.imageLink),
                                      fit: BoxFit.cover,
                                      cacheWidth: 350, // 📷 تحديد حجم العرض المحلي لتخفيف استهلاك RAM
                                      errorBuilder: (_, __, ___) => _placeholder(),
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
                  // قائمة الإجراءات السريعة
                  Positioned(
                    top: 4,
                    right: 4,
                    child: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          color: Colors.white.withValues(alpha: 0.7), size: 18),
                      color: const Color(0xFF1A1A2E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  if (product.brand != null && product.brand!.isNotEmpty) ...[
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
