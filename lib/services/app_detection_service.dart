// 📱 AppDetectionService
// يكشف التطبيقات المثبتة على الجهاز ويوجّه المستخدم تلقائياً
// للمتجر الصحيح (Google Play / Huawei AppGallery / APK)

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// ✅ بيانات منصة: deep link + Package ID + روابط المتاجر
class PlatformAppInfo {
  final String name;
  final String packageId;        // com.zhiliaoapp.musically
  final List<String> deepLinks;  // URI schemes للتحقق منها
  final String playStoreUrl;     // Google Play
  final String appGalleryUrl;    // Huawei AppGallery
  final String apkUrl;           // رابط APK رسمي كاحتياطي أخير
  final String webFallback;      // رابط ويب إذا لم يوجد أي شيء

  const PlatformAppInfo({
    required this.name,
    required this.packageId,
    required this.deepLinks,
    required this.playStoreUrl,
    required this.appGalleryUrl,
    required this.apkUrl,
    required this.webFallback,
  });
}

class AppDetectionService {
  AppDetectionService._();
  static final AppDetectionService instance = AppDetectionService._();

  // ═══════════════════════════════════════
  // 📚 قاموس المنصات الصينية + الاجتماعية
  // ═══════════════════════════════════════
  static const Map<String, PlatformAppInfo> _platforms = {

    'douyin': PlatformAppInfo(
      name: 'Douyin / TikTok CN',
      packageId: 'com.ss.android.ugc.aweme',
      deepLinks: ['douyin://', 'snssdk1128://'],
      playStoreUrl: 'https://play.google.com/store/apps/details?id=com.ss.android.ugc.aweme',
      appGalleryUrl: 'https://appgallery.huawei.com/app/C101184875',
      apkUrl: 'https://www.douyin.com/download',
      webFallback: 'https://www.douyin.com',
    ),

    'kuaishou': PlatformAppInfo(
      name: 'Kuaishou',
      packageId: 'com.smile.gifmaker',
      deepLinks: ['kwai://'],
      playStoreUrl: 'https://play.google.com/store/apps/details?id=com.smile.gifmaker',
      appGalleryUrl: 'https://appgallery.huawei.com/app/C101184871',
      apkUrl: 'https://www.kuaishou.com/download',
      webFallback: 'https://www.kuaishou.com',
    ),

    'rednote': PlatformAppInfo(
      name: 'Rednote / 小红书',
      packageId: 'com.xingin.xhs',
      deepLinks: ['xhsdiscover://'],
      playStoreUrl: 'https://play.google.com/store/apps/details?id=com.xingin.xhs',
      appGalleryUrl: 'https://appgallery.huawei.com/app/C101184877',
      apkUrl: 'https://www.xiaohongshu.com/download',
      webFallback: 'https://www.xiaohongshu.com',
    ),

    'bilibili': PlatformAppInfo(
      name: 'Bilibili',
      packageId: 'tv.danmaku.bili',
      deepLinks: ['bilibili://'],
      playStoreUrl: 'https://play.google.com/store/apps/details?id=tv.danmaku.bili',
      appGalleryUrl: 'https://appgallery.huawei.com/app/C100232981',
      apkUrl: 'https://www.bilibili.com/download',
      webFallback: 'https://www.bilibili.com',
    ),

    'tiktok': PlatformAppInfo(
      name: 'TikTok',
      packageId: 'com.zhiliaoapp.musically',
      deepLinks: ['tiktok://', 'snssdk1233://'],
      playStoreUrl: 'https://play.google.com/store/apps/details?id=com.zhiliaoapp.musically',
      appGalleryUrl: 'https://appgallery.huawei.com/app/C101297461',
      apkUrl: 'https://www.tiktok.com/download',
      webFallback: 'https://www.tiktok.com',
    ),

    'taobao': PlatformAppInfo(
      name: 'Taobao',
      packageId: 'com.taobao.taobao',
      deepLinks: ['taobao://'],
      playStoreUrl: 'https://play.google.com/store/apps/details?id=com.taobao.taobao',
      appGalleryUrl: 'https://appgallery.huawei.com/app/C100832543',
      apkUrl: 'https://www.taobao.com/download',
      webFallback: 'https://www.taobao.com',
    ),

    'jd': PlatformAppInfo(
      name: 'JD.com',
      packageId: 'com.jingdong.app.mall',
      deepLinks: ['openapp.jdmobile://'],
      playStoreUrl: 'https://play.google.com/store/apps/details?id=com.jingdong.app.mall',
      appGalleryUrl: 'https://appgallery.huawei.com/app/C101184951',
      apkUrl: 'https://app.jd.com/android.html',
      webFallback: 'https://www.jd.com',
    ),
  };

  // ═══════════════════════════════════════════════
  // 🚀 الدالة الرئيسية: فتح منصة مع كشف ذكي
  // ═══════════════════════════════════════════════

  /// يفتح المنصة مع كشف ذكي:
  /// 1️⃣ يحاول deep link → يفتح التطبيق المثبت مباشرة
  /// 2️⃣ يفتح رابط ويب المنصة (fallback سريع للجهاز بدون تطبيق)
  ///
  /// إذا أردت توجيه للمتجر بدلاً من الويب: استخدم [openStoreForPlatform]
  static Future<bool> openPlatform(
    String platformKey,
    String encodedQuery,
  ) async {
    final info = _platforms[platformKey];
    if (info == null) {
      debugPrint('⚠️ AppDetection: Unknown platform: $platformKey');
      return false;
    }

    // 1️⃣ جرّب كل deep link
    for (final scheme in info.deepLinks) {
      final uri = Uri.parse('${scheme}search?keyword=$encodedQuery');
      if (await _tryLaunch(uri, nonBrowser: true)) {
        debugPrint('✅ [${info.name}] Opened via deep link: $uri');
        return true;
      }
    }

    // 2️⃣ رابط الويب الاحتياطي
    final webUri = Uri.parse('${info.webFallback}/search?keyword=$encodedQuery');
    if (await _tryLaunch(webUri, nonBrowser: false)) {
      debugPrint('✅ [${info.name}] Opened via web: $webUri');
      return true;
    }

    debugPrint('❌ [${info.name}] All attempts failed for query: $encodedQuery');
    return false;
  }

  /// يفتح متجر التطبيق المناسب للمنصة المطلوبة
  /// 1️⃣ يحاول Google Play → 2️⃣ Huawei AppGallery → 3️⃣ APK رسمي
  static Future<bool> openStoreForPlatform(String platformKey) async {
    final info = _platforms[platformKey];
    if (info == null) return false;

    // 1️⃣ Google Play
    if (await _tryLaunch(Uri.parse(info.playStoreUrl), nonBrowser: false)) {
      debugPrint('✅ [${info.name}] Opened Google Play');
      return true;
    }

    // 2️⃣ Huawei AppGallery
    if (await _tryLaunch(Uri.parse(info.appGalleryUrl), nonBrowser: false)) {
      debugPrint('✅ [${info.name}] Opened Huawei AppGallery');
      return true;
    }

    // 3️⃣ APK رسمي
    if (await _tryLaunch(Uri.parse(info.apkUrl), nonBrowser: false)) {
      debugPrint('✅ [${info.name}] Opened APK site');
      return true;
    }

    return false;
  }

  /// 🔍 هل التطبيق مثبت؟ (عبر canLaunchUrl)
  static Future<bool> isAppInstalled(String platformKey) async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    final info = _platforms[platformKey];
    if (info == null) return false;

    for (final scheme in info.deepLinks) {
      try {
        // نستخدم scheme:// بدون path للتحقق فقط
        final testUri = Uri.parse('${scheme}test');
        if (await canLaunchUrl(testUri)) return true;
      } catch (_) {}
    }
    return false;
  }

  /// 📋 قائمة التطبيقات المثبتة من قائمة المنصات
  static Future<Map<String, bool>> checkAllPlatforms() async {
    final results = <String, bool>{};
    for (final key in _platforms.keys) {
      results[key] = await isAppInstalled(key);
    }
    debugPrint('📱 App Detection Results: $results');
    return results;
  }

  /// ℹ️ معلومات منصة محددة
  static PlatformAppInfo? getInfo(String platformKey) => _platforms[platformKey];

  // ═══════════════════
  // 🔧 مساعد داخلي
  // ═══════════════════
  static Future<bool> _tryLaunch(Uri uri, {required bool nonBrowser}) async {
    try {
      final mode = nonBrowser
          ? LaunchMode.externalNonBrowserApplication
          : LaunchMode.externalApplication;
      return await launchUrl(uri, mode: mode);
    } catch (e) {
      debugPrint('❌ $uri: $e');
      return false;
    }
  }
}
