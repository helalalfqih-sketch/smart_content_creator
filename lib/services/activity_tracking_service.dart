import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// 📊 خدمة تتبع نشاط المستخدمين وقياس استهلاك رصيد الذكاء الاصطناعي
class ActivityTrackingService extends GetxService {
  final _db = FirebaseFirestore.instance;

  // ✨ خريطة الإجراءات: actionId → {label, credits}
  static const Map<String, Map<String, dynamic>> _actionConfig = {
    // 🧠 إجراءات AI تستهلك رصيداً
    'send_message':       {'label': 'رسالة ذكاء اصطناعي',      'credits': 1},
    'generate_ad':        {'label': 'إنشاء وصف إعلاني',        'credits': 2},
    'generate_creative_image': {'label': 'توليد صورة إبداعية', 'credits': 5},
    'image_generation':   {'label': 'توليد صورة',               'credits': 5},
    'generate_video':     {'label': 'توليد فيديو',              'credits': 10},
    'generate_kling_video': {'label': 'توليد فيديو Kling',      'credits': 10},
    'visual_search':      {'label': 'تحليل بصري',               'credits': 3},
    'remove_background':  {'label': 'إزالة الخلفية',            'credits': 3},
    'google_images':      {'label': 'إلهام بصري',               'credits': 1},
    'bing_copilot':       {'label': 'بحث الخبير',               'credits': 2},
    'trend_search':       {'label': 'بحث الترندات',             'credits': 1},
    'google_news':        {'label': 'أخبار جوجل',               'credits': 1},
    'similar_videos':     {'label': 'بحث فيديوهات مشابهة',     'credits': 2},
    'alibaba_sourcing':   {'label': 'البحث عن مصادر',           'credits': 1},
    'amazon_search':      {'label': 'بحث أمازون',               'credits': 1},
    // 🔗 إجراءات مجانية
    'tiktok_link':        {'label': 'فتح تيك توك',              'credits': 0},
    'tiktok_hashtag':     {'label': 'هاشتاق تيك توك',           'credits': 0},
    'douyin_link':        {'label': 'فتح Douyin',                'credits': 0},
    'rednote_link':       {'label': 'فتح Rednote',               'credits': 0},
    'bilibili_link':      {'label': 'فتح Bilibili',              'credits': 0},
    'kuaishou_link':      {'label': 'فتح Kuaishou',              'credits': 0},
    'taobao_live_link':   {'label': 'Taobao Live',               'credits': 0},
    'jd_link':            {'label': 'بحث JD.com',                'credits': 0},
    'instagram_link':     {'label': 'فتح إنستقرام',             'credits': 0},
    'youtube_link':       {'label': 'فتح يوتيوب',               'credits': 0},
    'youtube_shorts_link': {'label': 'فتح يوتيوب شورتس',       'credits': 0},
    'google_search':      {'label': 'بحث جوجل',                 'credits': 0},
    'copy_text':          {'label': 'نسخ النص',                  'credits': 0},
    'telegram_publish':   {'label': 'نشر تيليجرام',             'credits': 0},
    'save_video_to_gallery': {'label': 'حفظ فيديو',             'credits': 0},
  };

  /// 🏷️ الحصول على تسمية الإجراء (static helper)
  static String getActionLabel(String action) {
    return (_actionConfig[action]?['label'] as String?) ?? action;
  }

  /// 📝 تسجيل إجراء قام به المستخدم
  Future<void> logAction({
    required String userId,
    required String action,
    Map<String, dynamic> details = const {},
  }) async {
    if (userId.isEmpty) return;

    try {
      final config = _actionConfig[action];
      final label = config?['label'] as String? ?? action;
      final credits = config?['credits'] as int? ?? 0;

      final log = {
        'userId': userId,
        'action': action,
        'actionLabel': label,
        'creditsUsed': credits,
        'timestamp': FieldValue.serverTimestamp(),
        'details': details,
      };

      // 🔥 حفظ في Firestore
      await _db.collection('user_activity_logs').add(log);

      // 📈 تحديث إجمالي الرصيد المستهلك على حساب المستخدم
      if (credits > 0) {
        await _db.collection('users').doc(userId).set({
          'ai_usage': {
            'total_credits': FieldValue.increment(credits),
            'last_action': action,
            'last_action_at': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));
      }

      if (kDebugMode) {
        debugPrint('📊 Activity logged: [$action] for user [$userId] - Credits: $credits');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ ActivityTrackingService: Failed to log action: $e');
    }
  }

  /// 📋 جلب سجل نشاط مستخدم معين (آخر 50 حدث)
  Future<List<Map<String, dynamic>>> getUserActivityLogs(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final snap = await _db
          .collection('user_activity_logs')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ ActivityTrackingService: getUserActivityLogs error: $e');
      return [];
    }
  }

  /// 🌐 جلب آخر الأحداث من كل المستخدمين (للأدمن)
  Future<List<Map<String, dynamic>>> getAllRecentLogs({int limit = 100}) async {
    try {
      final snap = await _db
          .collection('user_activity_logs')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ ActivityTrackingService: getAllRecentLogs error: $e');
      return [];
    }
  }

  /// 💰 جلب إجمالي الرصيد المستهلك لمستخدم معين
  Future<int> getUserTotalCredits(String userId) async {
    try {
      final snap = await _db
          .collection('user_activity_logs')
          .where('userId', isEqualTo: userId)
          .get();

      int total = 0;
      for (final doc in snap.docs) {
        total += (doc.data()['creditsUsed'] as num?)?.toInt() ?? 0;
      }
      return total;
    } catch (e) {
      return 0;
    }
  }

  /// ✅ مساعد: جلب رصيد الإجراء
  static int getActionCredits(String action) {
    return _actionConfig[action]?['credits'] as int? ?? 0;
  }
}
