import 'dart:io';
import '../../models/product_memory_model.dart';

/// 🌐 AppContext: تمثيل شامل لحالة التطبيق وسياق المستخدم
/// يساعد العقل المدبر (AI Orchestrator) على اتخاذ قرارات واعية بالمكان والزمان.
class AppContext {
  final ProductMemoryModel? lastProduct;
  final File? currentScreenImage; // صورة معروضة حالياً في الشاشة
  final String? activeScreen; // اسم الشاشة الحالية
  final String?
      explicitProductName; // اسم منتج تم تحديده يدوياً أو برمجياً في الجلسة الحالية
  final Map<String, dynamic> extraData;
  final List<String> availableTools;
  final List<Map<String, dynamic>> recentMessages; // 🆕 آخر الرسائل للسياق

  const AppContext({
    this.lastProduct,
    this.currentScreenImage,
    this.activeScreen,
    this.explicitProductName,
    this.extraData = const {},
    this.availableTools = const [
      'generate_image',
      'generate_video',
      'search_tiktok',
      'edit_product_photo',
      'analyze_product',
      'instagram_trends'
    ],
    this.recentMessages = const [], // 🆕
  });

  bool get hasProduct => explicitProductName != null || lastProduct != null;
  String? get productName => explicitProductName ?? lastProduct?.productName;
  String? get productSearchQuery =>
      explicitProductName ?? lastProduct?.searchQuery;

  /// 🧠 بناء نص السياق لحقنه في البرومبت
  String toContextPrompt() {
    final buffer = StringBuffer();

    // 1. سياق المنتج
    if (hasProduct) {
      buffer.writeln('📦 المنتج الحالي: $productName');
      if (lastProduct?.category != null) {
        buffer.writeln('   الفئة: ${lastProduct!.category}');
      }
      if (lastProduct?.brandName != null) {
        buffer.writeln('   العلامة التجارية: ${lastProduct!.brandName}');
      }
    }

    // 2. آخر الرسائل
    if (recentMessages.isNotEmpty) {
      buffer.writeln('\n💬 آخر المحادثة:');
      for (var msg in recentMessages) {
        final userMsg = (msg['user_message'] ?? '').toString();
        final aiMsg = (msg['ai_response'] ?? '').toString();
        if (userMsg.isNotEmpty) buffer.writeln('👤 المستخدم: $userMsg');
        if (aiMsg.isNotEmpty) {
          final truncated =
              aiMsg.length > 200 ? '${aiMsg.substring(0, 200)}...' : aiMsg;
          buffer.writeln('🤖 المساعد: $truncated');
        }
      }
    }

    return buffer.toString();
  }

  @override
  String toString() =>
      'AppContext(product: ${lastProduct?.productName}, screen: $activeScreen, msgs: ${recentMessages.length})';
}
