import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';

/// 🌍 GlobalConfigService: Manages Admin-level configurations and fallback API keys.
class GlobalConfigService extends GetxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache to avoid frequent Firestore reads
  final Map<String, String> _adminKeysCache = {};
  DateTime? _lastFetch;

  /// 🗝️ Get Admin API Key for a specific provider (serpapi, gemini, etc.)
  Future<String?> getAdminApiKey(String provider) async {
    // 🧠 Return from cache if less than 1 hour old
    if (_adminKeysCache.containsKey(provider) && 
        _lastFetch != null && 
        DateTime.now().difference(_lastFetch!).inHours < 1) {
      return _adminKeysCache[provider];
    }

    try {
      if (kDebugMode) debugPrint('🔄 Fetching Admin Keys from Firestore...');
      
      final doc = await _firestore.collection('global_configs').doc('api_keys').get();
      
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        data.forEach((key, value) {
          _adminKeysCache[key] = value.toString();
        });
        _lastFetch = DateTime.now();
        return _adminKeysCache[provider];
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error fetching admin keys: $e');
      return null;
    }
  }
}
