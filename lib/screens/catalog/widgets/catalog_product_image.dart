import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// 🖼️ CatalogProductImage
/// ويدجت ذكي لعرض صور المنتجات مع:
/// 1. معالجة سريعة لروابط CDN المنتهية (403) بدون تكرار الطلبات
/// 2. كاش داخلي لعناوين URL الفاشلة لمنع الـ Frame Drops و CPU Jank
/// 3. تسجيل الخطأ التشخيصي [CATALOG_MEDIA_ERROR] مرة واحدة فقط
/// 4. تحديد حجم فك تشفير الصورة في الذاكرة (memCacheWidth/Height)
class CatalogProductImage extends StatelessWidget {
  final String imageUrl;
  final String? productId;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final BorderRadius? borderRadius;
  final Widget? placeholderWidget;
  final Widget? errorWidget;

  // 🛡️ كاش الذاكرة الثابت لعناوين URL الفاشلة لمنع إعادة طلبها وتجنب البطء
  static final Set<String> _failedUrls = <String>{};
  static final Set<String> _loggedErrorKeys = <String>{};

  const CatalogProductImage({
    super.key,
    required this.imageUrl,
    this.productId,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.memCacheWidth = 300,
    this.memCacheHeight,
    this.borderRadius,
    this.placeholderWidget,
    this.errorWidget,
  });

  /// إعادة تعيين كاش الروابط الفاشلة (اختياري عند تحديث الكتالوج)
  static void clearFailedCache() {
    _failedUrls.clear();
    _loggedErrorKeys.clear();
  }

  /// هل الرابط معروف بأنه غير صالح
  static bool isKnownFailedUrl(String url) {
    if (url.trim().isEmpty) return true;
    return _failedUrls.contains(url);
  }

  /// تسجيل الخطأ مرة واحدة
  static void logMediaError(String url, String? productId) {
    _failedUrls.add(url);
    try {
      final uri = Uri.tryParse(url);
      final host = uri?.host ?? 'unknown_host';
      final key = '${productId ?? ''}_$host';
      if (!_loggedErrorKeys.contains(key)) {
        _loggedErrorKeys.add(key);
        debugPrint('[CATALOG_MEDIA_ERROR] productId=$productId host=$host status=403');
      }
    } catch (_) {}
  }

  Widget _defaultPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF141424),
      alignment: Alignment.center,
      child: const Icon(
        Icons.inventory_2_outlined,
        color: Colors.white24,
        size: 28,
      ),
    );
  }

  Widget _shimmerLoading() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A2E),
      highlightColor: const Color(0xFF2E2E4A),
      child: Container(
        width: width,
        height: height,
        color: const Color(0xFF1A1A2E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();
    if (cleanUrl.isEmpty) {
      return _wrapBorder(placeholderWidget ?? _defaultPlaceholder());
    }

    // 1. فحص الكاش الداخلي للروابط الفاشلة (تجاوز فوري بدون استهلاك للشبكة والـ UI Thread)
    if (_failedUrls.contains(cleanUrl)) {
      return _wrapBorder(errorWidget ?? _defaultPlaceholder());
    }

    final isNetwork = cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://');

    Widget imageWidget;
    if (isNetwork) {
      imageWidget = CachedNetworkImage(
        imageUrl: cleanUrl,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        placeholder: (context, url) => placeholderWidget ?? _shimmerLoading(),
        errorWidget: (context, url, error) {
          logMediaError(url, productId);
          return errorWidget ?? _defaultPlaceholder();
        },
      );
    } else if (kIsWeb) {
      imageWidget = Image.network(
        cleanUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) {
          logMediaError(cleanUrl, productId);
          return errorWidget ?? _defaultPlaceholder();
        },
      );
    } else {
      imageWidget = Image.file(
        File(cleanUrl),
        width: width,
        height: height,
        fit: fit,
        cacheWidth: memCacheWidth,
        cacheHeight: memCacheHeight,
        errorBuilder: (_, __, ___) {
          logMediaError(cleanUrl, productId);
          return errorWidget ?? _defaultPlaceholder();
        },
      );
    }

    return _wrapBorder(imageWidget);
  }

  Widget _wrapBorder(Widget child) {
    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: child,
      );
    }
    return child;
  }
}
