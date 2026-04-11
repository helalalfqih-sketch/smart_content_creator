import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'db_service.dart';
import '../controllers/auth_controller.dart';

class ReferralService extends GetxService {
  final _appLinks = AppLinks();
  final DBService _db = Get.find<DBService>();

  @override
  void onInit() {
    super.onInit();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    // Check initial link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('⚠️ Referral: Failed to get initial link: $e');
    }

    // Listen for new links
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint('⚠️ Referral: Link stream error: $err');
    });
  }

  void _handleDeepLink(Uri uri) async {
    debugPrint('🔗 Deep Link Detected: $uri');
    
    // Check for 'ref' parameter
    final refCode = uri.queryParameters['ref'];
    if (refCode != null && refCode.isNotEmpty) {
      debugPrint('🎁 Referral Code Found: $refCode');
      await _saveReferral(refCode);
    }
  }

  Future<void> _saveReferral(String referrerCode) async {
    // Prevent self-referral
    final currentUser = Get.find<AuthController>().user;
    if (currentUser != null && currentUser['id'] == referrerCode) {
       debugPrint('⚠️ Referral: Self-referral ignored.');
       return;
    }

    // Check if already referred
    // In a real app, you'd check if this user already has a 'referred_by' field set in DB/Remote
    await _db.insertRecord('referrals', {
      'referrer_id': referrerCode,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    Get.snackbar(
      'مرحباً بك! 👋', 
      'تم تفعيل كود الدعوة بنجاح: $referrerCode',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM
    );
  }

  void shareApp() async {
    final user = Get.find<AuthController>().user;
    final myCode = user?['id'] ?? 'GUEST'; // Use User ID as ref code
    
    // Simulate a store link or custom scheme
    // For testing: smartcreator://open?ref=MY_CODE
    // For Prod: https://play.google.com/store/apps/details?id=com.smart.creator&referrer=ref=$myCode
    final String inviteLink = "https://smartcontentcreator.com/invite?ref=$myCode";
    
    await SharePlus.instance.share(
      ShareParams(
        text: "جرب تطبيق 'صانع المحتوى الذكي'! 🚀\nأنشئ فيديوهات وإعلانات بالذكاء الاصطناعي في ثوانٍ.\n\nاستخدم الرابط للتسجيل: \n$inviteLink",
        subject: "انضم إلي في Smart Content Creator! 🚀",
      ),
    );
  }
}
