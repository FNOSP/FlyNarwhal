import '../../core/network/api_result.dart';
import '../entities/index.dart';

/// User repository interface
abstract class IUserRepository {
  /// Get current user info
  Future<ApiResult<UserEntity>> getUserInfo();
}