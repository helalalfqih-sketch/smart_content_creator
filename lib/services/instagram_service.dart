import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'secure_storage_service.dart';

/// 📸 خدمة ربط حساب انستقرام (Instagram API with Instagram Login)
///
/// تستخدم الـ API الجديد (2025) بدلاً من Basic Display API المتوقف.
/// تقوم بربط حساب انستقرام Business/Creator عبر Instagram Login OAuth
/// وتتيح الوصول إلى:
/// - بيانات الملف الشخصي (الاسم، الصورة، عدد المتابعين)
/// - إحصائيات المحتوى (Insights)
class InstagramService extends GetxService {
  // ────────────────────────── الثوابت ──────────────────────────
  static const String _metaAppId = '25680058028363991';
  static const String _metaAppSecret = 'b7e09887e6b2ed7b5dec3a8169119300';

  static const String _redirectUri =
      'https://smartcontentcreator.page.link/instagram-callback';

  // Instagram API with Instagram Login - Endpoints (الأحدث 2025)
  static const String _authBaseUrl =
      'https://www.instagram.com/oauth/authorize';
  static const String _tokenUrl =
      'https://api.instagram.com/oauth/access_token';
  static const String _graphUrl = 'https://graph.instagram.com';

  // الصلاحيات الجديدة (2025 - بدلاً من القديمة)
  static const List<String> _scopes = [
    'instagram_business_basic',
    'instagram_business_manage_insights',
  ];

  // ────────────────────────── الحالة المتفاعلة ──────────────────────────
  final RxBool isConnected = false.obs;
  final RxBool isLoading = false.obs;
  final Rxn<Map<String, dynamic>> instagramProfile =
      Rxn<Map<String, dynamic>>();

  // ────────────────────────── التهيئة ──────────────────────────
  @override
  void onInit() {
    super.onInit();
    _checkConnectionStatus();
  }

  /// 🔍 التحقق من حالة الربط عند بدء التشغيل
  Future<void> _checkConnectionStatus() async {
    try {
      final storage = Get.find<SecureStorageService>();
      final token = await storage.getInstagramToken();

      if (token.isNotEmpty) {
        // التحقق من صلاحية التوكن
        final isValid = await _validateToken(token);
        if (isValid) {
          isConnected.value = true;
          await _fetchInstagramProfile(token);
        } else {
          // التوكن منتهي الصلاحية
          await storage.deleteInstagramToken();
          isConnected.value = false;
        }
      } else {
        // تحقق من Firestore لاحتمال وجود توكن محفوظ سابقاً
        await _loadTokenFromFirestore();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Instagram connection check failed: $e');
      }
    }
  }

  /// 🔐 بدء عملية ربط حساب انستقرام (OAuth Flow)
  Future<void> connectInstagram() async {
    isLoading.value = true;
    try {
      // بناء رابط المصادقة باستخدام Instagram Login (الطريقة الجديدة)
      final scopeString = _scopes.join(',');
      final state = _generateState();

      final authUrl = '$_authBaseUrl'
          '?client_id=$_metaAppId'
          '&redirect_uri=${Uri.encodeComponent(_redirectUri)}'
          '&scope=$scopeString'
          '&response_type=code'
          '&state=$state';

      // حفظ الـ state للتحقق لاحقاً
      final storage = Get.find<SecureStorageService>();
      await storage.saveInstagramState(state);

      // فتح صفحة المصادقة في المتصفح الخارجي
      final uri = Uri.parse(authUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Get.snackbar('خطأ', 'لا يمكن فتح صفحة المصادقة');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Instagram OAuth Error: $e');
      }
      Get.snackbar('خطأ', 'فشل بدء عملية الربط');
    } finally {
      isLoading.value = false;
    }
  }

  /// 🔄 معالجة رابط الرجوع بعد مصادقة المستخدم (Callback)
  Future<bool> handleAuthCallback(Uri uri) async {
    try {
      final code = uri.queryParameters['code'];
      final state = uri.queryParameters['state'];

      if (code == null || code.isEmpty) {
        if (kDebugMode) {
          debugPrint('❌ Instagram: No auth code in callback');
        }
        return false;
      }

      // التحقق من الـ state لمنع هجمات CSRF
      final storage = Get.find<SecureStorageService>();
      final savedState = await storage.getInstagramState();
      if (state != savedState) {
        if (kDebugMode) {
          debugPrint('❌ Instagram: State mismatch');
        }
        return false;
      }

      isLoading.value = true;

      // 1. استبدال الـ code بتوكن وصول قصير المدة
      final shortLivedToken = await _exchangeCodeForToken(code);
      if (shortLivedToken == null) return false;

      // 2. تبديل التوكن القصير بتوكن طويل المدة (60 يوم)
      final longLivedToken = await _getLongLivedToken(shortLivedToken);
      final finalToken = longLivedToken ?? shortLivedToken;

      // حفظ التوكن بشكل آمن
      await storage.saveInstagramToken(finalToken);

      // حفظ في Firestore للمزامنة بين الأجهزة
      await _saveTokenToFirestore(finalToken);

      // جلب بيانات الملف الشخصي
      await _fetchInstagramProfile(finalToken);

      isConnected.value = true;

      Get.snackbar('تم بنجاح 🎉', 'تم ربط حساب انستقرام بنجاح!');
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Instagram Callback Error: $e');
      }
      Get.snackbar('خطأ', 'فشل إتمام عملية الربط');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// 🔓 فصل حساب انستقرام
  Future<void> disconnectInstagram() async {
    isLoading.value = true;
    try {
      final storage = Get.find<SecureStorageService>();
      await storage.deleteInstagramToken();

      // حذف من Firestore
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'instagram_token': FieldValue.delete(),
          'instagram_profile': FieldValue.delete(),
          'instagram_connected': false,
        });
      }

      isConnected.value = false;
      instagramProfile.value = null;

      Get.snackbar('تم', 'تم فصل حساب انستقرام بنجاح');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Instagram Disconnect Error: $e');
      }
    } finally {
      isLoading.value = false;
    }
  }

  // ════════════════════════════════════════════════════════════
  //                    🔧 الدوال المساعدة
  // ════════════════════════════════════════════════════════════

  /// 🔄 استبدال Authorization Code بتوكن وصول قصير المدة
  Future<String?> _exchangeCodeForToken(String code) async {
    try {
      // Instagram API with Instagram Login يستخدم POST request
      final response = await http.post(
        Uri.parse(_tokenUrl),
        body: {
          'client_id': _metaAppId,
          'client_secret': _metaAppSecret,
          'grant_type': 'authorization_code',
          'redirect_uri': _redirectUri,
          'code': code,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['access_token'] as String?;
      } else {
        if (kDebugMode) {
          debugPrint('❌ Token exchange failed: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Token exchange error: $e');
      }
    }
    return null;
  }

  /// 🔄 تبديل التوكن القصير بتوكن طويل المدة (صالح 60 يوم)
  Future<String?> _getLongLivedToken(String shortLivedToken) async {
    try {
      final response = await http.get(Uri.parse(
        '$_graphUrl/access_token'
        '?grant_type=ig_exchange_token'
        '&client_secret=$_metaAppSecret'
        '&access_token=$shortLivedToken',
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (kDebugMode) {
          debugPrint(
              '✅ Long-lived token obtained, expires in: ${data['expires_in']} seconds');
        }
        return data['access_token'] as String?;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Long-lived token exchange failed: $e');
      }
    }
    return null;
  }

  /// 📊 جلب بيانات الملف الشخصي من Instagram Graph API
  Future<void> _fetchInstagramProfile(String token) async {
    try {
      // الـ API الجديد يسمح بجلب البيانات مباشرة بدون صفحة فيسبوك
      final response = await http.get(Uri.parse(
        '$_graphUrl/me'
        '?fields=user_id,username,name,profile_picture_url,followers_count,follows_count,media_count,account_type'
        '&access_token=$token',
      ));

      if (response.statusCode == 200) {
        final profileData = json.decode(response.body);
        instagramProfile.value = profileData;

        // حفظ في Firestore
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'instagram_profile': profileData,
            'instagram_connected': true,
            'instagram_username': profileData['username'],
          });
        }

        if (kDebugMode) {
          debugPrint('✅ Instagram Profile Loaded: ${profileData['username']}');
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ Profile fetch failed: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Instagram Profile Fetch Error: $e');
      }
    }
  }

  /// ✅ التحقق من صلاحية التوكن
  Future<bool> _validateToken(String token) async {
    try {
      final response = await http.get(Uri.parse(
        '$_graphUrl/me?fields=user_id&access_token=$token',
      ));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 💾 حفظ التوكن في Firestore للمزامنة
  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'instagram_token': token,
          'instagram_connected': true,
          'instagram_linked_at': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to save Instagram token to Firestore: $e');
      }
    }
  }

  /// 📥 تحميل التوكن من Firestore (للأجهزة الجديدة)
  Future<void> _loadTokenFromFirestore() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (doc.exists) {
        final token = doc.data()?['instagram_token'] as String?;
        if (token != null && token.isNotEmpty) {
          final isValid = await _validateToken(token);
          if (isValid) {
            await Get.find<SecureStorageService>().saveInstagramToken(token);
            isConnected.value = true;
            await _fetchInstagramProfile(token);
          }
        }

        // تحميل البروفايل المحفوظ (للعرض الفوري)
        final savedProfile = doc.data()?['instagram_profile'];
        if (savedProfile != null && instagramProfile.value == null) {
          instagramProfile.value = Map<String, dynamic>.from(savedProfile);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to load Instagram token from Firestore: $e');
      }
    }
  }

  /// 🎲 توليد state عشوائي لمنع هجمات CSRF
  String _generateState() {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    return base64Url.encode(utf8.encode(random)).substring(0, 16);
  }

  // ════════════════════════════════════════════════════════════
  //              🔍 دوال البحث والتحليلات
  // ════════════════════════════════════════════════════════════

  /// 📸 البحث في انستقرام
  Future<void> searchInstagram(String query) async {
    // Instagram API لا يوفر بحث مباشر، نستخدم Deep Link
    _fallbackDeepLink(query);
  }

  /// 🔗 البحث عبر Deep Link
  void _fallbackDeepLink(String query) async {
    final cleanQuery = query.replaceAll('#', '').trim();
    final encoded = Uri.encodeComponent(cleanQuery).replaceAll('%20', '+');

    final urls = [
      'https://www.instagram.com/explore/search/keyword/?q=$encoded',
      'instagram://explore/search/keyword/?q=$encoded',
    ];

    for (var url in urls) {
      try {
        if (await launchUrl(Uri.parse(url),
            mode: LaunchMode.externalApplication)) {
          return;
        }
      } catch (_) {}
    }
  }

  /// 📊 جلب إحصائيات المحتوى (Insights)
  Future<Map<String, dynamic>?> getContentInsights() async {
    if (!isConnected.value) return null;

    try {
      final storage = Get.find<SecureStorageService>();
      final token = await storage.getInstagramToken();
      final accountId = instagramProfile.value?['user_id'];

      if (token.isEmpty || accountId == null) return null;

      final response = await http.get(Uri.parse(
        '$_graphUrl/$accountId/insights'
        '?metric=impressions,reach,profile_views'
        '&period=day'
        '&access_token=$token',
      ));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Insights fetch error: $e');
      }
    }
    return null;
  }
}
