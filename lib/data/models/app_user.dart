class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatarPath,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String email;
  final String? avatarPath;
  final DateTime createdAt;

  AppUser copyWith({
    String? name,
    String? avatarPath,
    bool clearAvatar = false,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email,
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
      createdAt: createdAt,
    );
  }

  /// Chỉ đọc các cột công khai; cố ý bỏ qua password_hash/password_salt.
  factory AppUser.fromMap(Map<String, Object?> map) {
    return AppUser(
      id: (map['id'] as num).toInt(),
      name: map['name'] as String,
      email: map['email'] as String,
      avatarPath: map['avatar_path'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}