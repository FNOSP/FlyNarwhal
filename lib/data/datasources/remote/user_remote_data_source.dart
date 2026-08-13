import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../models/base_response.dart';
import '../../models/user_data_models.dart';
import '../../models/user_info.dart';

/// Remote data source for user-related API calls
class UserRemoteDataSource {
  final DioClient _dioClient;

  UserRemoteDataSource(this._dioClient);

  /// Get current user info
  Future<ApiResult<UserInfo>> getUserInfo() async {
    final result = await _dioClient.get<UserInfo>(
      ApiEndpoints.userInfo,
      converter: (data) => _parseUserInfoResponse(data),
    );
    return result;
  }

  /// Logout current user (best-effort server-side logout)
  Future<ApiResult<bool>> logout() async {
    final result = await _dioClient.post<bool>(
      ApiEndpoints.userLogout,
      converter: (data) => _parseLogoutResponse(data),
    );
    return result;
  }

  /// Read a per-user persisted preference blob (e.g. library list settings).
  Future<ApiResult<UserDataResponse>> getUserData(
      UserDataGetRequest request) async {
    return _dioClient.post<UserDataResponse>(
      ApiEndpoints.userGetData,
      data: request.toJson(),
      converter: (data) => _parseUserDataResponse(data),
    );
  }

  /// Write a per-user persisted preference blob.
  Future<ApiResult<bool>> setUserData(UserDataSetRequest request) async {
    return _dioClient.post<bool>(
      ApiEndpoints.userSetData,
      data: request.toJson(),
      converter: (data) => _parseSetDataResponse(data),
    );
  }

  // Private parsing methods
  UserInfo _parseUserInfoResponse(dynamic data) {
    final baseResponse = FnBaseResponse<UserInfo>.fromJson(
      data,
      (json) {
        if (json is Map<String, dynamic>) {
          return UserInfo.fromJson(json);
        }
        return UserInfo.fromJson(Map<String, dynamic>.from(json as Map));
      },
    );
    if (baseResponse.code != ResponseCodes.success) {
      throw FailureInfo(
        message: baseResponse.msg,
        code: baseResponse.code,
        displayMessage: baseResponse.msg,
      );
    }
    return baseResponse.data ?? UserInfo(guid: '', username: '', isAdmin: 0);
  }

  // Parse logout response, returns true on success
  bool _parseLogoutResponse(dynamic data) {
    final baseResponse = FnBaseResponse<bool>.fromJson(
      data,
      (json) => json is bool ? json : true,
    );
    if (baseResponse.code != ResponseCodes.success) {
      throw FailureInfo(
        message: baseResponse.msg,
        code: baseResponse.code,
        displayMessage: baseResponse.msg,
      );
    }
    return baseResponse.data ?? true;
  }

  // Parse user/getData response; a missing record (code -6) yields an empty
  // value so callers fall back to defaults.
  UserDataResponse _parseUserDataResponse(dynamic data) {
    final baseResponse = FnBaseResponse<UserDataResponse>.fromJson(
      data,
      (json) => json == null
          ? const UserDataResponse()
          : UserDataResponse.fromJson(
              json is Map<String, dynamic>
                  ? json
                  : Map<String, dynamic>.from(json as Map),
            ),
    );
    if (baseResponse.code == -6) {
      return const UserDataResponse();
    }
    if (baseResponse.code != ResponseCodes.success) {
      throw FailureInfo(
        message: baseResponse.msg,
        code: baseResponse.code,
        displayMessage: baseResponse.msg,
      );
    }
    return baseResponse.data ?? const UserDataResponse();
  }

  // Parse user/setData response, returns true on success
  bool _parseSetDataResponse(dynamic data) {
    final baseResponse = FnBaseResponse<bool>.fromJson(
      data,
      (json) => json is bool ? json : true,
    );
    if (baseResponse.code != ResponseCodes.success) {
      throw FailureInfo(
        message: baseResponse.msg,
        code: baseResponse.code,
        displayMessage: baseResponse.msg,
      );
    }
    return baseResponse.data ?? true;
  }
}
