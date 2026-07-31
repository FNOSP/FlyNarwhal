import 'package:dio/dio.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../../models/base_response.dart';
import '../../models/file_models.dart';
import '../../models/movie_detail_models.dart';
import '../../models/subtitle_models.dart';

/// Remote data source for subtitle search / download API calls.
class SubtitleRemoteDataSource {
  final DioClient _dioClient;

  SubtitleRemoteDataSource(this._dioClient);

  /// Search online subtitles for a media item.
  Future<ApiResult<SubtitleSearchResponse>> searchSubtitles(
    SubtitleSearchRequest request,
  ) async {
    return _dioClient.post<SubtitleSearchResponse>(
      ApiEndpoints.subtitleSearch,
      data: request.toJson(),
      converter: _parseSearchResponse,
    );
  }

  /// Download a single online subtitle and attach it to the media item.
  Future<ApiResult<SubtitleStream>> downloadSubtitle(
    SubtitleDownloadRequest request,
  ) async {
    return _dioClient.post<SubtitleStream>(
      ApiEndpoints.subtitleDownload,
      data: request.toJson(),
      converter: _parseSubtitleStreamResponse,
    );
  }

  /// Mark server-side files as the external subtitles of a media item.
  /// Returns the subtitle entry registered by the server.
  Future<ApiResult<SubtitleMarkResponse>> markSubtitle(
    SubtitleMarkRequest request,
  ) async {
    return _dioClient.put<SubtitleMarkResponse>(
      ApiEndpoints.subtitleMark,
      data: request.toJson(),
      converter: _parseMarkSubtitleResponse,
    );
  }

  /// Queue a server task that downloads the same subtitle for the other
  /// episodes of the current series ("为其他集下载相似字幕").
  Future<ApiResult<bool>> predownloadSimilarSubtitle(
    SubtitlePredownloadRequest request,
  ) async {
    return _dioClient.post<bool>(
      ApiEndpoints.subtitlePredownload,
      data: request.toJson(),
      converter: _parseSuccessOnlyResponse,
    );
  }

  /// Upload a local subtitle file and attach it to the media item.
  Future<ApiResult<SubtitleStream>> uploadSubtitle({
    required String guid,
    required List<int> bytes,
    required String fileName,
  }) async {
    return _dioClient.post<SubtitleStream>(
      ApiEndpoints.subtitleUploadPrefix,
      data: FormData.fromMap({
        'guid': guid,
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
      }),
      converter: _parseSubtitleStreamResponse,
    );
  }

  SubtitleSearchResponse _parseSearchResponse(dynamic data) {
    final baseResponse = FnBaseResponse<Map<String, dynamic>>.fromJson(
      data,
      (json) => json as Map<String, dynamic>,
    );
    if (baseResponse.code != ResponseCodes.success ||
        baseResponse.data == null) {
      throw FailureInfo(
        message: baseResponse.msg,
        code: baseResponse.code,
        displayMessage: baseResponse.msg,
      );
    }
    return SubtitleSearchResponse.fromJson(baseResponse.data!);
  }

  SubtitleStream _parseSubtitleStreamResponse(dynamic data) {
    final baseResponse = FnBaseResponse<Map<String, dynamic>>.fromJson(
      data,
      (json) => json as Map<String, dynamic>,
    );
    if (baseResponse.code != ResponseCodes.success ||
        baseResponse.data == null) {
      throw FailureInfo(
        message: baseResponse.msg,
        code: baseResponse.code,
        displayMessage: baseResponse.msg,
      );
    }
    return SubtitleStream.fromJson(baseResponse.data!);
  }

  SubtitleMarkResponse _parseMarkSubtitleResponse(dynamic data) {
    final baseResponse = FnBaseResponse<Map<String, dynamic>>.fromJson(
      data,
      (json) => json as Map<String, dynamic>,
    );
    if (baseResponse.code != ResponseCodes.success ||
        baseResponse.data == null) {
      throw FailureInfo(
        message: baseResponse.msg,
        code: baseResponse.code,
        displayMessage: baseResponse.msg,
      );
    }
    return SubtitleMarkResponse.fromJson(baseResponse.data!);
  }

  bool _parseSuccessOnlyResponse(dynamic data) {
    final baseResponse = FnBaseResponse<void>.fromJson(data, (_) {});
    if (baseResponse.code != ResponseCodes.success) {
      throw FailureInfo(
        message: baseResponse.msg,
        code: baseResponse.code,
        displayMessage: baseResponse.msg,
      );
    }
    return true;
  }
}
