import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../core/models/api_provider.dart';
import '../controllers/auth_controller.dart';
import 'gatekeeper_service.dart';

/// Managed AI Service (v3.0)
/// 🛡️ Responsible for:
/// 1. Fetching System Managed Keys from Firestore.
/// 2. Validating User Credits before API calls.
/// 3. Deducting Credits after successful AI interactions.
class ManagedAiService extends GetxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _usersCollection = 'users';
  static const String _configCollection = 'global_config';
  static const String _aiSettingsDoc = 'ai_settings';

  final managedKeys = <String, String>{}.obs;
  final isManagedActive = false.obs;
  final freeDailyLimit = 50.obs;

  @override
  void onInit() {
    super.onInit();
    _setupGlobalConfigListener();
  }

  void _setupGlobalConfigListener() {
    _firestore
        .collection(_configCollection)
        .doc(_aiSettingsDoc)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;

        // Support both old single key and new map format
        final keys = <String, String>{};
        if (data['managed_gemini_key'] != null) {
          keys['gemini'] = data['managed_gemini_key'] as String;
        }
        if (data['managed_keys'] != null) {
          final map = data['managed_keys'] as Map<String, dynamic>;
          map.forEach((k, v) => keys[k] = v.toString());
        }
        managedKeys.value = keys;

        isManagedActive.value = data['is_managed_active'] ?? false;
        freeDailyLimit.value = data['free_daily_limit'] ?? 50;
        if (kDebugMode) {
          debugPrint('🛰️ ManagedAiService: Global Config Updated');
        }
      }
    }, onError: (e) {
      if (kDebugMode) {
        debugPrint('⚠️ ManagedAiService: Global Config Listener Error: $e');
        debugPrint('ℹ️ ManagedAiService: Using local defaults for credits.');
      }
      isManagedActive.value = false; // Fallback
    });
  }

  /// Fetch the system's managed key for a specific provider
  Future<String?> getManagedKey(String? uid,
      {ProviderType provider = ProviderType.gemini}) async {
    if (uid == null) return null;

    try {
      // 0. 🛡️ Permission Check (Granular Admin Control)
      final auth = Get.find<AuthController>();
      final bool isAdmin = auth.isAdmin;
      
      final gatekeeper = Get.find<GatekeeperService>();
      final bool hasGlobalAccess = gatekeeper.checkPermission('use_managed_keys');
      final bool hasSpecificAccess =
          gatekeeper.checkPermission('managed_key_${provider.name}');

      if (!isAdmin && !hasGlobalAccess && !hasSpecificAccess) {
        if (kDebugMode) {
          debugPrint(
              '🚫 ManagedAiService: User $uid does NOT have permission to use managed keys for ${provider.name}.');
        }
        return null;
      }
      // 1. Check Global Settings
      final settingsSnap = await _firestore
          .collection(_configCollection)
          .doc(_aiSettingsDoc)
          .get();

      if (!settingsSnap.exists) {
        if (kDebugMode) {
          debugPrint(
              '⚠️ ManagedAiService: global_config/ai_settings not found!');
        }
        return null;
      }

      final settings = settingsSnap.data()!;
      if (!(settings['is_managed_active'] ?? false)) {
        if (kDebugMode) {
          debugPrint('⚠️ ManagedAiService: Managed Mode is GLOBALLY DISABLED.');
        }
        return null;
      }

      // 2. Check User Credits & Pro Status
      final userSnap =
          await _firestore.collection(_usersCollection).doc(uid).get();
      if (!userSnap.exists) return null;

      // 🛑 AI Kill Switch Check (v4.0)
      if (userSnap.data()?['is_ai_blocked'] == true) {
        if (kDebugMode) debugPrint('🛑 ManagedAi: Access BLOCKED for user $uid');
        return null;
      }

      final userData = userSnap.data()!;
      final bool isPremium = userData['isPremium'] == true ||
          userData['isPremium'] == 1 ||
          userData['role'] == 'admin';

      if (!isPremium) {
        final int credits = userData['credits'] ?? 0;
        if (credits <= 0) {
          if (kDebugMode) {
            debugPrint('⚠️ ManagedAiService: User $uid has NO CREDITS.');
          }
          return null; // Quota Exceeded
        }
      }

      // 3. Return provider specific key
      String? key;
      if (settings['managed_keys'] != null) {
        final map = settings['managed_keys'] as Map<String, dynamic>;
        
        // 🗝️ Special: GitHub Hexa-Key Support
        if (provider == ProviderType.github && map['github_hexa'] != null) {
          try {
            final List<dynamic> gKeys = jsonDecode(map['github_hexa'].toString());
            if (gKeys.isNotEmpty) {
              // For now, return the first one (Rotation handled at provider level if possible)
              key = gKeys.first.toString();
            }
          } catch (_) {
            key = map[provider.name] as String?;
          }
        } else {
          key = map[provider.name] as String?;
        }
      }

      // 🛑 AI Kill Switch Check (v4.0)
      if (userData['is_ai_blocked'] == true) {
        if (kDebugMode) debugPrint('🛑 ManagedAi: Access BLOCKED for user $uid');
        return null;
      }

      // Fallback to old field for gemini
      if (key == null && provider == ProviderType.gemini) {
        key = settings['managed_gemini_key'] as String?;
      }

      return key;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ManagedAiService Error (getManagedKey): $e');
      }
      // 🚨 EMERGENECY FALLBACK: If Firestore fails (Permission Denied), use hardcoded key
      // This ensures the app works for the first run or without setup.
      if (provider == ProviderType.gemini) {
        return "AIzaSyCX_EXAMPLE_FALLBACK_KEY_HERE";
      }
      return null;
    }
  }

  /// Deduct 1 credit from the user's account safely using a transaction
  Future<bool> deductCredit(String? uid) async {
    if (uid == null) return false;

    try {
      final userRef = _firestore.collection(_usersCollection).doc(uid);

      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) return false;

        final userData = snapshot.data()!;

        // 🛡️ Pro/Admin Users bypass credit deduction
        final bool isPremium = userData['isPremium'] == true ||
            userData['isPremium'] == 1 ||
            userData['role'] == 'admin';

        if (isPremium) return true;

        final int currentCredits = userData['credits'] ?? 0;

        if (currentCredits > 0) {
          transaction.update(userRef, {
            'credits': currentCredits - 1,
            'last_usage': FieldValue.serverTimestamp(),
          });
          return true;
        }
        return false;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('❌ ManagedAiService Error (deductCredit): $e');
      return false;
    }
  }

  /// Check if a user is eligible for a credit reset (Daily Renewal)
  Future<void> checkAndResetCredits(String uid) async {
    try {
      final userRef = _firestore.collection(_usersCollection).doc(uid);
      final snapshot = await userRef.get();
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final Timestamp? lastReset = data['last_credit_reset'] as Timestamp?;

      final now = DateTime.now();
      bool shouldReset = false;

      if (lastReset == null) {
        shouldReset = true;
      } else {
        final lastResetDate = lastReset.toDate();
        // Reset if it's a new day
        if (now.day != lastResetDate.day ||
            now.month != lastResetDate.month ||
            now.year != lastResetDate.year) {
          shouldReset = true;
        }
      }

      if (shouldReset) {
        int dailyLimit = 50; // Default local fallback

        // Fetch default limit from global config safely
        try {
          final settingsSnap = await _firestore
              .collection(_configCollection)
              .doc(_aiSettingsDoc)
              .get();
          dailyLimit = settingsSnap.data()?['free_daily_limit'] ?? 50;
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
                '⚠️ ManagedAiService: Could not fetch daily limit from Firestore, using default: $dailyLimit');
          }
        }

        await userRef.update({
          'credits': dailyLimit,
          'last_credit_reset': FieldValue.serverTimestamp(),
          'is_trial_active': true,
        });

        if (kDebugMode) {
          debugPrint(
              '🔄 ManagedAiService: Credits RESET to $dailyLimit for $uid');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ ManagedAiService: Failed to reset credits: $e');
      }
    }
  }

  /// 🛑 Check if user is blocked from AI access
  Future<bool> isUserBlocked(String uid) async {
    try {
      final snap = await _firestore.collection(_usersCollection).doc(uid).get();
      if (!snap.exists) return false;
      return snap.data()?['is_ai_blocked'] == true;
    } catch (_) {
      return false;
    }
  }
}
