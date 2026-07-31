import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../../models/base_response.dart';
import '../../models/file_models.dart';

/// Remote data source for server file-browsing API calls.
class FileRemoteDataSource {
  final DioClient _dioClient;

  FileRemoteDataSource(this._dioClient);

  /// Get the directories the app is authorized to browse on the server.
  Future<ApiResult<List<AuthDir>>> getAuthorizedDirs() async {
    return _dioClient.get<List<AuthDir>>(
      ApiEndpoints.authorizedDir,
      converter: _parseAuthorizedDirsResponse,
    );
  }

  /// List files under a server path.
  Future<ApiResult<List<ServerPathResponse>>> getFilesByServerPath(
    String path,
  ) async {
    return _dioClient.post<List<ServerPathResponse>>(
      ApiEndpoints.serverPath,
      data: {'path': path},
      converter: _parseServerPathResponse,
    );
  }

  List<AuthDir> _parseAuthorizedDirsResponse(dynamic data) {
    final baseResponse = FnBaseResponse<Map<String, dynamic>>.fromJson(
      data,
      (json) => json as Map<String, dynamic>,
    );
    if (baseResponse.code != ResponseCodes.success) {
      throw FailureInfo(
        message: baseResponse.msg,
        code: baseResponse.code,
        displayMessage: baseResponse.msg,
      );
    }
    return (baseResponse.data?['authDirList'] as List?)
            ?.map((e) => AuthDir.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
  }

  List<ServerPathResponse> _parseServerPathResponse(dynamic data) {
    final baseResponse = FnBaseResponse<List<dynamic>>.fromJson(
      data,
      (json) => json as List<dynamic>,
    );
    if (baseResponse.code != ResponseCodes.success) {
      throw FailureInfo(
        message: baseResponse.msg,
        code: baseResponse.code,
        displayMessage: baseResponse.msg,
      );
    }
    return (baseResponse.data ?? [])
        .map((e) => ServerPathResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
