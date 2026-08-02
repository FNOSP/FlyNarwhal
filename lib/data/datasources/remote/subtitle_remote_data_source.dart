import 'dart:convert';
import 'dart:math';

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

  /// Upload a local subtitle file and attach it to the media item identified
  /// by [mediaGuid] (the `media_guid` returned by /v/api/v1/play/info).
  ///
  /// The media guid is carried in the URL path
  /// (`.../subtitle/upload/{mediaGuid}`); the multipart body contains only the
  /// binary `file` part. The body is sent as a [Stream] so the main isolate
  /// never blocks on a single large memcpy — dio writes each chunk (headers,
  /// file bytes, trailer) to the socket incrementally via `addStream()`.
  Future<ApiResult<SubtitleStream>> uploadSubtitle({
    required String mediaGuid,
    required List<int> bytes,
    required String fileName,
  }) async {
    final boundary = _generateMultipartBoundary();
    final body = _buildUploadMultipartStream(
      boundary: boundary,
      fileBytes: bytes,
      fileName: fileName,
    );
    return _dioClient.post<SubtitleStream>(
      ApiEndpoints.subtitleUploadByMediaGuid(mediaGuid),
      data: body.stream,
      options: Options(
        headers: {
          Headers.contentTypeHeader: 'multipart/form-data; boundary=$boundary',
          'Content-Length': '${body.contentLength}',
        },
      ),
      converter: _parseSubtitleStreamResponse,
    );
  }

  /// Builds the multipart body as a [Stream] of three chunks (headers, file
  /// bytes, trailer) so the main isolate performs zero memcpy. Dio's
  /// `HttpClientRequest.addStream()` writes each chunk to the socket
  /// incrementally.
  ({Stream<List<int>> stream, int contentLength})
      _buildUploadMultipartStream({
    required String boundary,
    required List<int> fileBytes,
    required String fileName,
  }) {
    final headersChunk = utf8.encode(
      '--$boundary\r\n'
      'Content-Disposition: form-data; name=file; filename="$fileName"\r\n'
      'Content-Type: application/octet-stream\r\n'
      'Content-Length: ${fileBytes.length}\r\n'
      '\r\n',
    );
    final trailerChunk = utf8.encode('\r\n--$boundary--\r\n');
    final contentLength =
        headersChunk.length + fileBytes.length + trailerChunk.length;
    final stream = Stream<List<int>>.fromIterable([
      headersChunk,
      fileBytes,
      trailerChunk,
    ]);
    return (stream: stream, contentLength: contentLength);
  }

  /// Same shape as ktor's generateBoundary(): a random hex string (≤70 chars).
  String _generateMultipartBoundary() {
    final random = Random.secure();
    final buffer = StringBuffer();
    while (buffer.length < 64) {
      buffer.write(random.nextInt(0x7FFFFFFF).toRadixString(16));
    }
    return buffer.toString().substring(0, 64);
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
