/// Shared by the UI orchestrator and legacy agent entry points.
class ImageGenerationRequest {
  static String normalize(String text) => text.toLowerCase().trim()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا').replaceAll('ة', 'ه').replaceAll('ى', 'ي');

  static bool matches(String prompt) {
    final text = normalize(prompt);
    if (text.isEmpty) return false;
    // Describing an image or discussing generation must not start a paid render.
    if (RegExp(r'^(كيف|كيفيه|ما هو|ما هي|اشرح|how\b|what\b|explain\b)').hasMatch(text) ||
        RegExp(r'(?:^|\s)(?:لا|لات|لم|لن|بلاش|توقف عن)\s*(?:ت)?(?:نش|نشي|صمم|صنع|ولد|رسم|عمل)').hasMatch(text) ||
        RegExp(r"\b(?:do not|don't|never|stop)\s+(?:generate|create|draw|design|make|render)\b").hasMatch(text) ||
        RegExp(r'(?:اكتب|اعطني|جهز|write|give).*(?:برومبت|وصف نصي|وصفا|فكره|فكرة|prompt|description|idea)').hasMatch(text)) {
      return false;
    }
    final noun = RegExp(r'صور[هة]?|صور|تصميم|رسمه|\b(?:image|photo|picture|illustration|poster|logo)s?\b').hasMatch(text);
    final action = RegExp(r'(?:^|\s)(?:و)?(?:انشئ|انشي|تنشئ|اصنع|تصنع|صمم|تصمم|تصميم|ارسم|ترسم|رسم|اعمل|توليد|ولد|سوي|تخيل|اريد|ابغي|ابغى|اعطني|create|generate|draw|design|make|render)(?:\s|$)').hasMatch(text);
    return noun && action;
  }

  static bool usesPreviousImage(String prompt) {
    final text = normalize(prompt);
    return RegExp(r'(?:^|\s)(?:له|لها|لهذا|لهذه|هذا|هذه|المنتج|للمنتج|الصوره|للصوره|نفس|السابق|السابقه)(?:\s|$|[؟?،,.])').hasMatch(text) ||
        RegExp(r'\b(?:this|that|product|previous|same)\b').hasMatch(text) ||
        RegExp(r'^(?:هل |ممكن |يمكنك |تستطيع |تقدر |ان |لي |تصميم |صمم |انشئ |صوره|صور|[؟?\s])+$').hasMatch(text);
  }
}
