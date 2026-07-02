/// 用户基础信息。对齐 openapi schema User。
class User {
  const User({
    required this.id,
    required this.email,
    required this.nickname,
    required this.status,
    this.createdAt,
  });

  final int id;
  final String email;
  final String nickname;

  /// 1 正常 / 0 禁用。
  final int status;
  final DateTime? createdAt;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: json['email'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      status: (json['status'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

/// 个人信息 = User + phone/avatar。对齐 openapi schema UserProfile（allOf User）。
class UserProfile extends User {
  const UserProfile({
    required super.id,
    required super.email,
    required super.nickname,
    required super.status,
    super.createdAt,
    this.phone,
    this.avatar,
  });

  final String? phone;
  final String? avatar;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final base = User.fromJson(json);
    return UserProfile(
      id: base.id,
      email: base.email,
      nickname: base.nickname,
      status: base.status,
      createdAt: base.createdAt,
      phone: json['phone'] as String?,
      avatar: json['avatar'] as String?,
    );
  }
}
