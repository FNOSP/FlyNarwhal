/// User entity
class UserEntity {
  final String guid;
  final String username;
  final bool isAdmin;

  const UserEntity({
    required this.guid,
    required this.username,
    this.isAdmin = false,
  });

  bool get isAuthenticated => guid.isNotEmpty;

  UserEntity copyWith({
    String? guid,
    String? username,
    bool? isAdmin,
  }) {
    return UserEntity(
      guid: guid ?? this.guid,
      username: username ?? this.username,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}