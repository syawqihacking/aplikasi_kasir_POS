class AppUser {
  final int? id;
  final String username;
  final String? passwordHash;
  final String role;
  final String fullName;
  final int isActiveFlag;
  final String? createdAt;

  const AppUser({
    this.id,
    required this.username,
    this.passwordHash,
    required this.role,
    required this.fullName,
    this.isActiveFlag = 1,
    this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as int?,
      username: (map['username'] as String?) ?? '',
      passwordHash: map['password_hash'] as String?,
      role: (map['role'] as String?) ?? '',
      fullName: (map['full_name'] as String?) ?? '',
      isActiveFlag: (map['is_active'] as int?) ?? 1,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'username': username,
      'role': role,
      'full_name': fullName,
      'is_active': isActiveFlag,
    };
    if (id != null) map['id'] = id;
    if (passwordHash != null) map['password_hash'] = passwordHash;
    if (createdAt != null) map['created_at'] = createdAt;
    return map;
  }

  bool get isActive => isActiveFlag == 1;
}
