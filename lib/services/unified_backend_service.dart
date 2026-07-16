import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

/// 🛡️ UnifiedBackendService (The Guard Layer)
/// الغرض: توفير نقطة وصول موحدة وآمنة للـ Backend الجديد دون كسر الخدمات القديمة.
class UnifiedBackendService extends GetxService {
  // رابط الـ Cloud Function (يجب تحديثه بعد النشر)
  final String _baseUrl = 'https://smartAI-your-region.cloudfunctions.net/smartAI';

  /// 🚀 استدعاء الذكاء الاصطناعي عبر السيرفر الآمن
  /// يُستخدم هذا التابع لكل الميزات الجديدة في التطبيق.
  Future<String> callSmartAI(String prompt) async {
    try {
      // 1. جلب التوكن الأمني (ID Token)
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");
      
      final String? idToken = await user.getIdToken();

      // 2. إرسال الطلب للسيرفر
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'prompt': prompt,
          'userId': user.uid, // نرسله كإضافة، لكن السيرفر سيتحقق من التوكن
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] ?? "No response content";
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? "Server error: ${response.statusCode}");
      }
    } catch (e) {
      Get.log("❌ Guard Layer Error: $e");
      rethrow;
    }
  }

  /**
   * 💡 ملاحظة للمستقبل: 
   * أي خدمة قديمة تريد ترحيلها للـ SaaS، يتم استدعاؤها من هنا تدريجياً.
   */
}
