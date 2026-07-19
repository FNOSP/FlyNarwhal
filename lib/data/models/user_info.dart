class UserInfo {
  final String guid;
  final String username;
  final int isAdmin;

  UserInfo({
    required this.guid,
    required this.username,
    required this.isAdmin,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      guid: json['guid']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      isAdmin: json['is_admin'] is int ? json['is_admin'] as int : int.tryParse(json['is_admin']?.toString() ?? '') ?? 0,
    );
  }
}
