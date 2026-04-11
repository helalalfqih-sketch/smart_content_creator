import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// ⛏️ JinaService - يستخدم r.jina.ai لتحويل أي رابط إلى نص Markdown نظيف
class JinaService {
  final Dio _dio = Dio();

  /// جلب المحتوى الصافي من الرابط مع حماية Timeout صارمة
  Future<String?> fetchCleanContent(String url) async {
    try {
      debugPrint("🚀 JinaService: Extracting data from: $url");
      
      // الرابط السحري
      final response = await _dio.get(
        "https://r.jina.ai/$url",
        options: Options(
          headers: {
            'Accept': 'text/event-stream', 
          },
        ),
      ).timeout(
        const Duration(seconds: 15), // الـ Timeout الصارم (15 ثانية)
        onTimeout: () {
          throw TimeoutException("انتهى وقت الاتصال. Jina AI استغرق أكثر من 15 ثانية.");
        },
      );

      if (response.statusCode == 200) {
        String content = response.data.toString();
        
        // ✂️ "مقص البيانات"
        const int maxLimit = 4000;
        if (content.length > maxLimit) {
          debugPrint("✂️ JinaService: Truncating content to $maxLimit chars");
          content = "${content.substring(0, maxLimit)}\n\n...[تم قص باقي النص]...";
        }
        debugPrint("✅ JinaService: Success");
        return content;
      } else {
        throw Exception("فشل برمز حالة: ${response.statusCode}");
      }
    } catch (e) {
      // إرجاع رسالة الخطأ كنص لكي يفهم الـ LLM أو الـ Orchestrator سبب الفشل
      debugPrint("❌ JinaService Error: $e");
      if (e is TimeoutException) {
         return "[ERROR: TIMEOUT] عذراً، هذا الرابط محمي جداً أو خوادم الموقع لا تستجيب. يرجى إعطائي وصفاً للمنتج بدلاً من الرابط.";
      }
      return "[ERROR] عذراً، لم أتمكن من قراءة الرابط بسبب حماية الموقع.";
    }
  }

  /// دالة تجريبية للطباعة في الكونسول (للتوافق مع طلب المستخدم الأولي)
  Future<void> testJinaReader(String productUrl) async {
    final content = await fetchCleanContent(productUrl);
    if (content != null) {
      debugPrint("--- محتوى المنتج الصافي (Jina) ---");
      debugPrint(content);
      debugPrint("---------------------------");
    }
  }
}
