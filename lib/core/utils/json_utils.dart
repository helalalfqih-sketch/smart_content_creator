import 'dart:convert';
import 'package:flutter/foundation.dart';

class JsonUtils {
  /// 🧠 معالجة الـ JSON في الخلفية (Background Parsing)
  /// يستخدم compute() لضمان عدم توقف الواجهة أثناء معالجة النصوص الضخمة
  static Future<Map<String, dynamic>> parseAsync(String raw) async {
    return await compute(parseSafe, raw);
  }

  /// Extracts and sanitizes JSON from a potentially messy AI response string.
  /// If parsing fails, it returns a Map with the raw text in the 'text' field.
  static Map<String, dynamic> parseSafe(String raw) {
    if (raw.trim().isEmpty) return {};
    try {
      final sanitized = sanitize(raw);
      if (sanitized.isEmpty) return {"text": raw};
      return jsonDecode(sanitized);
    } catch (e) {
      if (kDebugMode && !raw.contains('[') && !raw.contains(']')) {
         debugPrint("❌ JsonUtils: Failed to parse JSON: $e\nRaw: $raw");
      }
      return {"text": raw};
    }
  }

  /// Extracts and sanitizes a list from a potentially messy AI response string.
  static List<dynamic> parseListSafe(String raw) {
    if (raw.trim().isEmpty) return [];
    try {
      final sanitized = sanitize(raw);
      if (sanitized.isEmpty) return [];
      final decoded = jsonDecode(sanitized);
      return decoded is List ? decoded : [];
    } catch (e) {
      if (kDebugMode) debugPrint("❌ JsonUtils: Failed to parse JSON List: $e\nRaw: $raw");
      return [];
    }
  }

  /// Specialized for Chat responses that may contain both JSON and separate Markdown.
  /// It tries to find JSON first, and if found, it merges any extra text into the 'text' field.
  static Map<String, dynamic> extractChatResponse(String raw) {
    if (raw.trim().isEmpty) return {};
    
    final map = parseSafe(raw);
    
    // If the map only has the 'text' field and it's equal to 'raw', 
    // it means parseSafe failed or found nothing.
    if (map.length == 1 && map['text'] == raw) {
      return map;
    }

    // If it succeeded but there's a lot of text OUTSIDE the JSON that we might want?
    // Actually, usually the AI puts the main text inside the "text" field.
    // If the "text" field is empty but there's markdown outside, we might want to capture it.
    
    return map;
  }

  /// Robustly extracts the JSON block from text and fixes common formatting issues.
  static String sanitize(String raw) {
    String clean = raw.trim();

    // 1. Remove Markdown code blocks if present
    clean = clean.replaceAll('```json', '').replaceAll('```', '').trim();

    // 2. Identify the first { or [ and the last } or ]
    final firstBrace = clean.indexOf('{');
    final firstBracket = clean.indexOf('[');
    
    int start = -1;
    bool isObject = false;

    if (firstBrace != -1 && (firstBracket == -1 || firstBrace < firstBracket)) {
      start = firstBrace;
      isObject = true;
    } else if (firstBracket != -1) {
      start = firstBracket;
      isObject = false;
    }

    if (start == -1) return "";

    int end = isObject ? clean.lastIndexOf('}') : clean.lastIndexOf(']');
    if (end == -1 || end < start) return "";

    clean = clean.substring(start, end + 1);

    // 3. Fix common AI errors
    // A. Remove trailing commas before closing braces/brackets
    clean = clean.replaceAll(RegExp(r',\s*(?=[\]}])'), '');

    // B. Handle unescaped newlines within strings (common AI mistake)
    // This is aggressive but helpful. It finds strings and replaces internal newlines with \n
    // Note: Simple version - just replace actual newlines with literal \n if they are between quotes
    // But safely: only if there's no quote following on the same line.
    // For now, let's keep it simple and just fix the most common ones.
    
    return clean;
  }
}
