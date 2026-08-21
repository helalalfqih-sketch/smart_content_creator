import 'product_search_context.dart';

/// 🧭 PlatformQueryBuilder
/// يولّد استعلامات بحث متخصصة لكل منصة بناءً على هوية المنتج الكاملة.
/// كل منصة لها استراتيجية مختلفة في البحث والاستهداف.
class PlatformQueryBuilder {
  PlatformQueryBuilder._(); // Prevent instantiation

  // ─────────────────────────────────────────────────────────────
  // 🚀 Entry Point الرئيسي
  // ─────────────────────────────────────────────────────────────

  /// يُعيد قائمة استعلامات مرتبة بالأولوية لمنصة معينة.
  /// العنصر الأول هو الأفضل — إذا فشل، جرّب الثاني.
  static List<String> build(String platform, ProductSearchContext ctx) {
    if (ctx.isEmpty) return [];

    switch (platform) {
      case 'tiktok':
        return _buildTikTok(ctx);
      case 'tiktok_hashtag':
        return _buildTikTokHashtags(ctx);
      case 'douyin':
        return _buildDouyin(ctx);
      case 'rednote':
        return _buildRednote(ctx);
      case 'twitter':
        return _buildTwitter(ctx);
      case 'kuaishou':
        return _buildKuaishou(ctx);
      case 'instagram':
        return _buildInstagram(ctx);
      case 'youtube_shorts':
        return _buildYouTubeShorts(ctx);
      case 'jd':
        return _buildJD(ctx);
      case 'google_images':
        return _buildGoogleImages(ctx);
      case 'similar_videos':
        return _buildSimilarVideos(ctx);
      default:
        // Fallback: استخدام الاستعلام القصير
        return [ctx.shortQuery, ctx.displayName];
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 📱 TikTok — إنجليزي + discovery keywords
  // ─────────────────────────────────────────────────────────────
  static List<String> _buildTikTok(ProductSearchContext ctx) {
    final name = ctx.displayName;
    final short = ctx.shortQuery;

    return [
      '$name review',
      '$name demo',
      '$name unboxing',
      '$name viral',
      '$short test',
      name,
    ].where((q) => q.trim().isNotEmpty).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // 🔖 TikTok Hashtags — بناء هاشتاقات من الفئة والمميزات
  // ─────────────────────────────────────────────────────────────
  static List<String> _buildTikTokHashtags(ProductSearchContext ctx) {
    final tags = <String>{};

    // من الفئة
    if (ctx.category.isNotEmpty) {
      final cat = ctx.category.toLowerCase().replaceAll(' ', '');
      tags.add('#$cat');
    }

    // من المميزات
    for (final feature in ctx.features.take(3)) {
      final tag = feature.toLowerCase().replaceAll(' ', '');
      if (tag.length > 2) tags.add('#$tag');
    }

    // هاشتاقات عامة حسب نوع المنتج
    tags.addAll(_getGenericHashtags(ctx));

    // من الاسم نفسه
    if (ctx.brand.isNotEmpty) {
      tags.add('#${ctx.brand.toLowerCase()}');
    }
    tags.add('#productreview');
    tags.add('#musthave');

    return tags.take(8).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // 🎵 Douyin — صيني + كلمات التجارة الإلكترونية
  // ─────────────────────────────────────────────────────────────
  static List<String> _buildDouyin(ProductSearchContext ctx) {
    final zh = ctx.bestChineseQuery;

    return [
      zh,
      '$zh 带货',     // Livestream selling
      '$zh 种草',     // Product recommendation
      '$zh 测评',     // Review
      '$zh 实拍',     // Real shot/demo
      '$zh 好物推荐', // Good product recommendation
    ].where((q) => q.trim().isNotEmpty).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // 📕 Rednote (小红书) — تجربة المنتج والمراجعات بالصيني
  // ─────────────────────────────────────────────────────────────
  static List<String> _buildRednote(ProductSearchContext ctx) {
    final zh = ctx.bestChineseQuery;

    return [
      zh,
      '$zh 使用体验',  // Usage experience
      '$zh 测评',      // Review
      '$zh 推荐',      // Recommendation
      '$zh 值得买吗',  // Worth buying?
      '$zh 好用吗',    // Is it good?
    ].where((q) => q.trim().isNotEmpty).toList();
  }


  // ─────────────────────────────────────────────────────────────
  // 🐦 Twitter/X — بحث بالإنجليزي + engagement keywords
  // ─────────────────────────────────────────────────────────────
  static List<String> _buildTwitter(ProductSearchContext ctx) {
    final name = ctx.displayName;
    final brand = ctx.brand;
    final short = ctx.shortQuery;

    return [
      if (brand.isNotEmpty) '$brand $name review',
      '$name worth it',
      '$name experience',
      '$name honest review',
      '$short review',
      name,
    ].where((q) => q.trim().isNotEmpty).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // ⚡ Kuaishou (快手) — بحث صيني + ترندات
  // ─────────────────────────────────────────────────────────────
  static List<String> _buildKuaishou(ProductSearchContext ctx) {
    final zh = ctx.bestChineseQuery;

    return [
      zh,
      '$zh 好物推荐',  // Good product recommendation
      '$zh 测评',      // Review
      '$zh 实测',      // Real test
      '$zh 直播',      // Livestream
      '$zh 开箱',      // Unboxing
    ].where((q) => q.trim().isNotEmpty).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // 📸 Instagram — visual + lifestyle keywords
  // ─────────────────────────────────────────────────────────────
  static List<String> _buildInstagram(ProductSearchContext ctx) {
    final name = ctx.displayName;
    final short = ctx.shortQuery;

    return [
      '$name reels',
      '$name review',
      '$name setup',
      '$name aesthetic',
      '$short unboxing',
      name,
    ].where((q) => q.trim().isNotEmpty).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // 🎬 YouTube Shorts — video content discovery
  // ─────────────────────────────────────────────────────────────
  static List<String> _buildYouTubeShorts(ProductSearchContext ctx) {
    final name = ctx.displayName;
    final short = ctx.shortQuery;

    return [
      '$name demo',
      '$name review',
      '$name comparison',
      'how to use $name',
      '$short tutorial',
      '$name shorts',
      name,
    ].where((q) => q.trim().isNotEmpty).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // 🔧 JD.com (京东) — تحديد المنتج والموديل بالصيني
  // ─────────────────────────────────────────────────────────────
  static List<String> _buildJD(ProductSearchContext ctx) {
    final zh = ctx.bestChineseQuery;
    final brand = ctx.brand;
    final model = ctx.model;

    return [
      if (brand.isNotEmpty && model.isNotEmpty) '$brand $model',
      if (brand.isNotEmpty && zh.isNotEmpty) '$brand $zh',
      zh,
      if (model.isNotEmpty) '$zh $model',
    ].where((q) => q.trim().isNotEmpty && !q.toLowerCase().contains('unknown')).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // 🖼️ Google Images — visual inspiration queries
  // ─────────────────────────────────────────────────────────────
  static List<String> _buildGoogleImages(ProductSearchContext ctx) {
    final name = ctx.displayName;
    final short = ctx.shortQuery;

    return [
      name,
      '$name lifestyle',
      '$name packaging',
      '$name product photo',
      '$short review image',
      '$name professional photo',
    ].where((q) => q.trim().isNotEmpty).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // 🔍 Similar Videos — exact product video search
  // ─────────────────────────────────────────────────────────────
  static List<String> _buildSimilarVideos(ProductSearchContext ctx) {
    final short = ctx.shortQuery;
    final name = ctx.displayName;

    return [
      short,
      '$short review',
      '$short video',
      name,
      if (ctx.brand.isNotEmpty && ctx.model.isNotEmpty) '${ctx.brand} ${ctx.model}',
    ].where((q) => q.trim().isNotEmpty).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // 🏷️ Helper: هاشتاقات عامة بناءً على الفئة
  // ─────────────────────────────────────────────────────────────
  static Set<String> _getGenericHashtags(ProductSearchContext ctx) {
    final cat = ctx.category.toLowerCase();

    if (cat.contains('garden') || cat.contains('tool')) {
      return {'#gardentools', '#diytools', '#gardenhacks', '#outdoorlife'};
    } else if (cat.contains('kitchen') || cat.contains('cook')) {
      return {'#kitchengadgets', '#cooking', '#foodprep', '#kitchenhacks'};
    } else if (cat.contains('health') || cat.contains('medical')) {
      return {'#healthtech', '#wellness', '#healthmonitor', '#smarthealth'};
    } else if (cat.contains('beauty') || cat.contains('skin')) {
      return {'#beauty', '#skincare', '#beautyhacks', '#glowup'};
    } else if (cat.contains('tech') || cat.contains('electronic')) {
      return {'#techgadgets', '#gadgets', '#technology', '#techtok'};
    } else if (cat.contains('sport') || cat.contains('fitness')) {
      return {'#fitness', '#workout', '#gym', '#sportsgear'};
    }

    // Generic fallback
    return {'#gadgets', '#musthave', '#viralproducts', '#productreview'};
  }

  // ─────────────────────────────────────────────────────────────
  // 🔑 Helper: استخرج أفضل استعلام واحد لمنصة معينة
  // ─────────────────────────────────────────────────────────────

  /// يُعيد الاستعلام الأول (الأفضل) أو fallback
  static String getBestQuery(String platform, ProductSearchContext ctx) {
    final queries = build(platform, ctx);
    return queries.isNotEmpty ? queries.first : ctx.displayName;
  }

  /// للـ hashtags: يُعيد أول hashtag صالح
  static String getBestHashtag(ProductSearchContext ctx) {
    final tags = _buildTikTokHashtags(ctx);
    return tags.isNotEmpty ? tags.first.replaceAll('#', '') : ctx.displayName;
  }
}
