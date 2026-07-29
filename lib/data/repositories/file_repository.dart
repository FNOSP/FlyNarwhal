import 'package:dio/dio.dart';

import '../../core/network/dio_client.dart';
import '../models/base_response.dart';
import '../models/file_models.dart';
import '../models/movie_detail_models.dart';
import '../models/subtitle_models.dart';

class FileRepository {
  final DioClient _dioClient;

  FileRepository(this._dioClient);

  Future<List<AuthDir>> getAuthorizedDirs() async {
    final response = await _dioClient.dio.get('/v/api/v1/app/authorized/dir');
    final baseResponse = FnBaseResponse<Map<String, dynamic>>.fromJson(
      response.data,
      (json) => json as Map<String, dynamic>,
    );

    if (baseResponse.code != 0) {
      throw Exception(baseResponse.msg);
    }

    final authDirList = (baseResponse.data?['authDirList'] as List?)
            ?.map((e) => AuthDir.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return authDirList;
  }

  Future<List<ServerPathResponse>> getFilesByServerPath(String path) async {
    final response = await _dioClient.dio.post(
      '/v/api/v1/server/path',
      data: {'path': path},
    );
    final baseResponse = FnBaseResponse<List<dynamic>>.fromJson(
      response.data,
      (json) => json as List<dynamic>,
    );

    if (baseResponse.code != 0) {
      throw Exception(baseResponse.msg);
    }

    return (baseResponse.data ?? [])
        .map((e) => ServerPathResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markSubtitle(String mediaGuid, List<String> filePaths) async {
    final request = SubtitleMarkRequest(
      mediaGuid: mediaGuid,
      filePaths: filePaths,
    );
    final response = await _dioClient.dio.put(
      '/v/api/v1/subtitle/mark',
      data: request.toJson(),
    );
    final baseResponse = FnBaseResponse<void>.fromJson(
      response.data,
      (_) {},
    );

    if (baseResponse.code != 0) {
      throw Exception(baseResponse.msg);
    }
  }

  Future<SubtitleSearchResponse> searchSubtitles({
    required String mediaGuid,
    String language = 'zh-CN',
  }) async {
    final response = await _dioClient.dio.post(
      '/v/api/v1/subtitle/search',
      data: SubtitleSearchRequest(
        lan: language,
        mediaGuid: mediaGuid,
      ).toJson(),
    );
    final baseResponse = FnBaseResponse<Map<String, dynamic>>.fromJson(
      response.data,
      (json) => json as Map<String, dynamic>,
    );

    if (baseResponse.code != 0 || baseResponse.data == null) {
      throw Exception(baseResponse.msg);
    }
    return SubtitleSearchResponse.fromJson(baseResponse.data!);
  }

  Future<SubtitleStream> downloadSubtitle({
    required String mediaGuid,
    required String trimId,
    int syncDownload = 1,
  }) async {
    final response = await _dioClient.dio.post(
      '/v/api/v1/subtitle/download',
      data: SubtitleDownloadRequest(
        mediaGuid: mediaGuid,
        trimId: trimId,
        syncDownload: syncDownload,
      ).toJson(),
    );
    final baseResponse = FnBaseResponse<Map<String, dynamic>>.fromJson(
      response.data,
      (json) => json as Map<String, dynamic>,
    );

    if (baseResponse.code != 0 || baseResponse.data == null) {
      throw Exception(baseResponse.msg);
    }
    return SubtitleStream.fromJson(baseResponse.data!);
  }

  Future<SubtitleStream> uploadSubtitle({
    required String guid,
    required List<int> bytes,
    required String fileName,
  }) async {
    final response = await _dioClient.dio.post(
      '/v/api/v1/subtitle/upload',
      data: FormData.fromMap({
        'guid': guid,
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
        ),
      }),
    );
    final baseResponse = FnBaseResponse<Map<String, dynamic>>.fromJson(
      response.data,
      (json) => json as Map<String, dynamic>,
    );

    if (baseResponse.code != 0 || baseResponse.data == null) {
      throw Exception(baseResponse.msg);
    }
    return SubtitleStream.fromJson(baseResponse.data!);
  }
}
