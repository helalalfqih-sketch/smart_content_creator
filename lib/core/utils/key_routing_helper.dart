import 'package:flutter/foundation.dart';
import '../../core/models/api_provider.dart';

/// 🚀 Key Routing Helper
/// Responsible for detecting smart keys (OpenRouter, GitHub) and routing them.
class KeyRoutingHelper {
  
  /// Detect if the API key belongs to a special provider via its prefix
  static bool isSmartKey(String? apiKey) {
    if (apiKey == null || apiKey.isEmpty) return false;
    return apiKey.startsWith('sk-') || apiKey.startsWith('ghp_');
  }

  /// Get the target provider type based on the key prefix
  static ProviderType? getProviderType(String apiKey) {
    if (apiKey.startsWith('sk-')) return ProviderType.openrouter;
    if (apiKey.startsWith('ghp_')) return ProviderType.github;
    return null;
  }

  /// Get the list of models supported by the smart key
  static List<String> getModelsForKey(String apiKey) {
    if (isSmartKey(apiKey)) {
      return [
        'gemini-1.5-flash',
        'gemini-2.0-flash-001',
        'gpt-4o',
        'gpt-4o-mini',
      ];
    }
    return [];
  }

  /// Log routing for debugging
  static void logRouting(String context, String apiKey) {
    if (kDebugMode && isSmartKey(apiKey)) {
      final type = getProviderType(apiKey);
      debugPrint("🚀 [Smart Routing - $context]: Redirecting to $type");
    }
  }
}
