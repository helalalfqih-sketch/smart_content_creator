import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import '../models/user_activity.dart';
// import 'db_service.dart';

class ActivityLogService extends GetxService {
  // final DBService _db = Get.find<DBService>();

  /// Log a user activity
  Future<void> logActivity({
    required int userId,
    required String type,
    Map<String, dynamic> details = const {},
  }) async {
    try {
      // final activity = UserActivity(
      //   userId: userId,
      //   type: type,
      //   details: details,
      //   timestamp: DateTime.now(),
      // );

      // In a real app, you'd save to SQLite/Firestore here
      // await _db.insertActivity(activity);

      if (kDebugMode) {
        debugPrint('📝 User Activity: [User $userId] $type - $details');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to log activity: $e');
    }
  }

  /// Get recent activities for a user (Placeholder)
  Future<List<UserActivity>> getRecentActivity(int userId,
      {int limit = 10}) async {
    // Placeholder: Return empty list until DB integration
    return [];
  }
}
