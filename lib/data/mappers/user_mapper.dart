import '../../domain/entities/index.dart';
import '../models/user_info.dart';

/// Mapper for converting user models to entities
class UserMapper {
  const UserMapper._();

  /// Convert UserInfo model to UserEntity
  static UserEntity toEntity(UserInfo model) {
    return UserEntity(
      guid: model.guid,
      username: model.username,
      isAdmin: model.isAdmin == 1,
    );
  }
}