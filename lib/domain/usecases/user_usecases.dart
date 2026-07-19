import '../../core/network/api_result.dart';
import '../entities/index.dart';
import '../repositories/i_user_repository.dart';

/// Use case for getting user info
class GetUserInfoUseCase {
  final IUserRepository _repository;

  GetUserInfoUseCase(this._repository);

  Future<ApiResult<UserEntity>> call() {
    return _repository.getUserInfo();
  }
}