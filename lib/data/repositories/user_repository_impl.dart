import '../../core/network/api_result.dart';
import '../../domain/entities/index.dart';
import '../../domain/repositories/i_user_repository.dart';
import '../datasources/remote/user_remote_data_source.dart';
import '../mappers/user_mapper.dart';

/// Implementation of IUserRepository
class UserRepositoryImpl implements IUserRepository {
  final UserRemoteDataSource _remoteDataSource;

  UserRepositoryImpl(this._remoteDataSource);

  @override
  Future<ApiResult<UserEntity>> getUserInfo() async {
    final result = await _remoteDataSource.getUserInfo();
    return result.map((data) => UserMapper.toEntity(data));
  }
}