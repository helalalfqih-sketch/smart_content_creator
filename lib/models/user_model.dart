class UserModel {
  final int? id;
  final String name;
  final String email;
  final String role; // 'admin', 'pro', 'user'
  final bool isPremium;
  final String? subscriptionStatus; // 'active', 'expired', 'trial'
  final DateTime? subscriptionExpiry;
  final DateTime createdAt;

  UserModel({
    this.id,
    required this.name,
    required this.email,
    this.role = 'user',
    this.isPremium = false,
    this.subscriptionStatus,
    this.subscriptionExpiry,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? 'user',
      isPremium: (map['isPremium'] == 1 || map['isPremium'] == true),
      subscriptionStatus: map['subscriptionStatus'] as String?,
      subscriptionExpiry: map['subscriptionExpiry'] != null
          ? DateTime.tryParse(map['subscriptionExpiry'].toString())
          : null,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'isPremium': isPremium ? 1 : 0, // Store as int for SQLite compatibility
      'subscriptionStatus': subscriptionStatus,
      'subscriptionExpiry': subscriptionExpiry?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? role,
    bool? isPremium,
    String? subscriptionStatus,
    DateTime? subscriptionExpiry,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isPremium: isPremium ?? this.isPremium,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'UserModel(id: $id, name: $name, email: $email, role: $role, isPremium: $isPremium, createdAt: $createdAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          email == other.email &&
          role == other.role &&
          isPremium == other.isPremium &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      email.hashCode ^
      role.hashCode ^
      isPremium.hashCode ^
      createdAt.hashCode;
}
