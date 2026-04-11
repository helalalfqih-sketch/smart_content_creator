class UserActivity {
  final int? id;
  final int userId;
  final String type; // e.g., 'message', 'video_gen', 'login'
  final Map<String, dynamic> details;
  final DateTime timestamp;

  UserActivity({
    this.id,
    required this.userId,
    required this.type,
    required this.details,
    required this.timestamp,
  });

  factory UserActivity.fromMap(Map<String, dynamic> map) {
    return UserActivity(
      id: map['id'] as int?,
      userId: map['userId'] as int,
      type: map['type'] as String,
      details: map['details'] is String
          ? _parseDetails(map['details'] as String)
          : (map['details'] as Map<String, dynamic>? ?? {}),
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  static Map<String, dynamic> _parseDetails(String jsonStr) {
    // Simple helper if details are stored as JSON string in DB
    // In a real app, you might use dart:convert
    return {};
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'details': details, // DB Service should handle JSON encoding if needed
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
