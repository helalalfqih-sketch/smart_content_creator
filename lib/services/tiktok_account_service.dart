import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/secure_storage_service.dart';
import '../controllers/settings_controller.dart';

/// 🎵 خدمة ربط حساب تيك توك (TikTok Login Kit / OAuth 2.0)
///
/// تقوم بربط حساب تيك توك عبر OAuth 2.0
/// وتتيح الوصول إلى:
/// - بيانات الملف الشخصي (الاسم، الصورة، عدد المتابعين)
/// - إحصائيات المحتوى
class TikTokAccountService extends GetxService {
  // ────────────────────────── الثوابت ──────────────────────────
  // ⚠️ يجب تحديث هذه القيم من TikTok Developer Portal
  static const String _clientKey = ''; // سيتم تعبئته
  static const String _clientSecret = ''; // سيتم تعبئته

  static const String _redirectUri =
      'https://smartcontentcreator2.web.app/auth/tiktok/callback';

  // TikTok OAuth Endpoints
  static const String _authBaseUrl = 'https://www.tiktok.com/v2/auth/authorize';
  static const String _tokenUrl = 'https://open.tiktokapis.com/v2/oauth/token/';
  static const String _userInfoUrl =
      'https://open.tiktokapis.com/v2/user/info/';
  static const String _videoListUrl =
      'https://open.tiktokapis.com/v2/video/list/';

  // الصلاحيات المطلوبة
  static const List<String> _scopes = [
    'user.info.profile',
    'user.info.stats',
    'video.list',
  ];

  // ────────────────────────── الحالة المتفاعلة ──────────────────────────
  final RxBool isConnected = false.obs;
  final RxBool isLoading = false.obs;
  final Rxn<Map<String, dynamic>> tiktokProfile = Rxn<Map<String, dynamic>>();

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
      final token = await storage.getTikTokToken();

      if (token.isNotEmpty) {
        final isValid = await _validateToken(token);
        if (isValid) {
          isConnected.value = true;
          await _fetchTikTokProfile(token);
        } else {
          // محاولة تجديد التوكن
          await _tryRefreshToken();
        }
      } else {
        await _loadTokenFromFirestore();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ TikTok connection check failed: $e');
      }
    }
  }

  /// 🔐 بدء عملية ربط حساب تيك توك (OAuth Flo w)
  Future<void> connectTikTok() async {
    isLoading.value = true;
    try {
      final clientKey = await _getClientKey();
      if (clientKey.isEmpty) {
        if (kDebugMode) {
          debugPrint('❌ TikTok Client Key not configured');
        }
        Get.snackbar('تنبيه', 'لم يتم إعداد ربط تيك توك بعد. تواصل مع الدعم.');
        return;
      }

      final scopeString = _scopes.join(' ');
      final state = _generateState();

      final authUrl = '$_authBaseUrl'
          '?client_key=$clientKey'
          '&redirect_uri=${Uri.encodeComponent(_redirectUri)}'
          '&scope=${Uri.encodeComponent(scopeString)}'
          '&response_type=code'
          '&state=$state';

      debugPrint('🚀 [TIKTOK DEBUG] Using Official TikTok v2 Format...');
      debugPrint('🔗 URL: $authUrl');
      debugPrint('🔑 Client Key: $clientKey');
      debugPrint('🌐 Redirect: $_redirectUri');
      debugPrint('📜 Scopes: $scopeString');

      // حفظ الـ state
      final storage = Get.find<SecureStorageService>();
      await storage.saveTikTokState(state);

      final uri = Uri.parse(authUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Get.snackbar('خطأ', 'لا يمكن فتح صفحة المصادقة');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ TikTok OAuth Error: $e');
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
          debugPrint('❌ TikTok: No auth code in callback');
        }
        return false;
      }

      // التحقق من الـ state
      final storage = Get.find<SecureStorageService>();
      final savedState = await storage.getTikTokState();
      if (state != savedState) {
        if (kDebugMode) {
          debugPrint('❌ TikTok: State mismatch');
        }
        return false;
      }

      isLoading.value = true;

      // استبدال الـ code بتوكن وصول
      final tokenData = await _exchangeCodeForToken(code);
      if (tokenData == null) return false;

      final accessToken = tokenData['access_token'] as String;
      final refreshToken = tokenData['refresh_token'] as String?;

      // حفظ التوكنات
      await storage.saveTikTokToken(accessToken);
      if (refreshToken != null) {
        await storage.saveTikTokRefreshToken(refreshToken);
      }

      // حفظ في Firestore
      await _saveTokenToFirestore(accessToken, refreshToken);

      // جلب بيانات الملف الشخصي
      await _fetchTikTokProfile(accessToken);

      isConnected.value = true;

      Get.snackbar('تم بنجاح 🎉', 'تم ربط حساب تيك توك بنجاح!');
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ TikTok Callback Error: $e');
      }
      Get.snackbar('خطأ', 'فشل إتمام عملية الربط');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// 🔓 فصل حساب تيك توك
  Future<void> disconnectTikTok() async {
    isLoading.value = true;
    try {
      final storage = Get.find<SecureStorageService>();
      await storage.deleteTikTokToken();
      await storage.deleteTikTokRefreshToken();

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'tiktok_token': FieldValue.delete(),
          'tiktok_refresh_token': FieldValue.delete(),
          'tiktok_profile': FieldValue.delete(),
          'tiktok_connected': false,
        });
      }

      isConnected.value = false;
      tiktokProfile.value = null;

      Get.snackbar('تم', 'تم فصل حساب تيك توك بنجاح');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ TikTok Disconnect Error: $e');
      }
    } finally {
      isLoading.value = false;
    }
  }

  // ════════════════════════════════════════════════════════════
  //                    🔧 الدوال المساعدة
  // ════════════════════════════════════════════════════════════

  /// 🔑 جلب Client Key (من الإعدادات أولاً، ثم Firestore)
  Future<String> _getClientKey() async {
    // 1. من SettingsController (الأولوية)
    try {
      final settings = Get.find<SettingsController>();
      final key = settings.tiktokClientKey.value.trim();
      if (key.isNotEmpty && !key.startsWith('apify_api_')) return key;
    } catch (_) {}

    // 2. من Firestore
    try {
      final doc = await FirebaseFirestore.instance
          .collection('global_config')
          .doc('tiktok_settings')
          .get();
      if (doc.exists) {
        return doc.data()?['client_key'] ?? '';
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to get TikTok Client Key: $e');
      }
    }
    return _clientKey;
  }

  /// 🔐 جلب Client Secret (من الإعدادات أولاً، ثم Firestore)
  Future<String> _getClientSecret() async {
    // 1. من SettingsController (الأولوية)
    try {
      final settings = Get.find<SettingsController>();
      final secret = settings.tiktokClientSecret.value.trim();
      if (secret.isNotEmpty) return secret;
    } catch (_) {}

    // 2. من Firestore
    try {
      final doc = await FirebaseFirestore.instance
          .collection('global_config')
          .doc('tiktok_settings')
          .get();
      return doc.data()?['client_secret'] ?? '';
    } catch (e) {
      return _clientSecret;
    }
  }

  /// 🔄 استبدال Authorization Code بتوكن
  Future<Map<String, dynamic>?> _exchangeCodeForToken(String code) async {
    try {
      final clientKey = await _getClientKey();
      final clientSecret = await _getClientSecret();
      final storage = Get.find<SecureStorageService>();
      final codeVerifier = await storage.getTikTokCodeVerifier();

      final response = await http.post(
        Uri.parse(_tokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_key': clientKey,
          'client_secret': clientSecret,
          'code': code,
          'grant_type': 'authorization_code',
          'redirect_uri': _redirectUri,
          'code_verifier': codeVerifier,
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        if (kDebugMode) {
          debugPrint('❌ TikTok token exchange failed: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ TikTok token exchange error: $e');
      }
    }
    return null;
  }

  /// 📊 جلب بيانات الملف الشخصي
  Future<void> _fetchTikTokProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_userInfoUrl?fields=open_id,union_id,avatar_url,display_name,username,follower_count,following_count,likes_count,video_count',
        ),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final userData = data['data']?['user'];
        if (userData != null) {
          tiktokProfile.value = userData;

          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .update({
              'tiktok_profile': userData,
              'tiktok_connected': true,
              'tiktok_username':
                  userData['display_name'] ?? userData['username'],
            });
          }

          if (kDebugMode) {
            debugPrint('✅ TikTok Profile Loaded: ${userData['display_name']}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ TikTok profile fetch failed: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ TikTok Profile Fetch Error: $e');
      }
    }
  }

  /// 📺 جلب قائمة فيديوهات المستخدم (Official API)
  /// كما ورد في مستندات تيك توك: يتطلب POST وصلاحية video.list
  Future<List<Map<String, dynamic>>> fetchUserVideos(String token,
      {int maxCount = 20}) async {
    try {
      final response = await http.post(
        Uri.parse(
            '$_videoListUrl?fields=id,title,video_description,duration,cover_image_url,share_url,embed_link'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'max_count': maxCount,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final videos = data['data']?['videos'] as List?;
        if (videos != null) {
          if (kDebugMode) {
            debugPrint('✅ TikTok Videos Loaded: ${videos.length} videos');
          }
          return videos.cast<Map<String, dynamic>>();
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ TikTok video list fetch failed: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ TikTok Video Fetch Error: $e');
      }
    }
    return [];
  }

  /// ✅ التحقق من صلاحية التوكن
  Future<bool> _validateToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_userInfoUrl?fields=open_id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 🔄 تجديد التوكن
  Future<void> _tryRefreshToken() async {
    try {
      final storage = Get.find<SecureStorageService>();
      final refreshToken = await storage.getTikTokRefreshToken();
      if (refreshToken.isEmpty) {
        await storage.deleteTikTokToken();
        isConnected.value = false;
        return;
      }

      final clientKey = await _getClientKey();
      final clientSecret = await _getClientSecret();

      final response = await http.post(
        Uri.parse(_tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_key': clientKey,
          'client_secret': clientSecret,
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newToken = data['access_token'] as String?;
        final newRefresh = data['refresh_token'] as String?;

        if (newToken != null && newToken.isNotEmpty) {
          await storage.saveTikTokToken(newToken);
          if (newRefresh != null) {
            await storage.saveTikTokRefreshToken(newRefresh);
          }
          await _saveTokenToFirestore(newToken, newRefresh);
          isConnected.value = true;
          await _fetchTikTokProfile(newToken);
          if (kDebugMode) {
            debugPrint('✅ TikTok token refreshed');
          }
        }
      } else {
        await storage.deleteTikTokToken();
        await storage.deleteTikTokRefreshToken();
        isConnected.value = false;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ TikTok token refresh failed: $e');
      }
    }
  }

  /// 💾 حفظ التوكن في Firestore
  Future<void> _saveTokenToFirestore(String token, String? refreshToken) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final data = <String, dynamic>{
          'tiktok_token': token,
          'tiktok_connected': true,
          'tiktok_linked_at': FieldValue.serverTimestamp(),
        };
        if (refreshToken != null) {
          data['tiktok_refresh_token'] = refreshToken;
        }
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update(data);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to save TikTok token to Firestore: $e');
      }
    }
  }

  /// 📥 تحميل التوكن من Firestore
  Future<void> _loadTokenFromFirestore() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (doc.exists) {
        final token = doc.data()?['tiktok_token'] as String?;
        if (token != null && token.isNotEmpty) {
          final isValid = await _validateToken(token);
          if (isValid) {
            final storage = Get.find<SecureStorageService>();
            await storage.saveTikTokToken(token);

            final refreshToken = doc.data()?['tiktok_refresh_token'] as String?;
            if (refreshToken != null) {
              await storage.saveTikTokRefreshToken(refreshToken);
            }

            isConnected.value = true;
            await _fetchTikTokProfile(token);
          }
        }

        final savedProfile = doc.data()?['tiktok_profile'];
        if (savedProfile != null && tiktokProfile.value == null) {
          tiktokProfile.value = Map<String, dynamic>.from(savedProfile);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to load TikTok token from Firestore: $e');
      }
    }
  }

  /// 🎲 توليد state عشوائي
  String _generateState() {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    return base64Url.encode(utf8.encode(random)).substring(0, 16);
  }
}
