import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/base_response.dart';
import '../../data/models/player_models.dart';
import '../../data/models/movie_detail_models.dart';
import '../../data/network/dio_client.dart';
import '../../providers/providers.dart';

class PlayerService {
  final DioClient _dioClient;
  final Ref _ref;

  PlayerService(this._dioClient, this._ref);

  // Get play info for a media item
  Future<PlayInfoResponse> getPlayInfo(String guid, {String? mediaGuid}) async {
    final response = await _dioClient.dio.post(
      '/v/api/v1/play/info',
      data: {
        'item_guid': guid,
        if (mediaGuid != null) 'media_guid': mediaGuid,
      },
    );
    final baseResponse = FnBaseResponse<PlayInfoResponse>.fromJson(
      response.data,
      (json) => PlayInfoResponse.fromJson(json as Map<String, dynamic>),
    );
    if (baseResponse.code != 0) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data!;
  }

  // Get stream info for a media guid
  Future<StreamResponse> getStreamInfo(
    String mediaGuid, {
    String? ip,
    int level = 1,
  }) async {
    final request = StreamRequest(
      mediaGuid: mediaGuid,
      ip: ip,
      level: level,
      header: Header(
        userAgent: [
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36'
        ],
      ),
    );
    final response = await _dioClient.dio.post(
      '/v/api/v1/stream',
      data: request.toJson(),
    );
    final baseResponse = FnBaseResponse<StreamResponse>.fromJson(
      response.data,
      (json) => StreamResponse.fromJson(json as Map<String, dynamic>),
    );
    if (baseResponse.code != 0) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data!;
  }

  // Play video with specified parameters
  Future<PlayPlayResponse> playVideo({
    required String guid,
    String? mediaGuid,
    String? audioGuid,
    String? subtitleGuid,
  }) async {
    final request = PlayPlayRequest(
      guid: guid,
      mediaGuid: mediaGuid,
      audioGuid: audioGuid,
      subtitleGuid: subtitleGuid,
    );
    final response = await _dioClient.dio.post(
      '/v/api/v1/play/play',
      data: request.toJson(),
    );
    final baseResponse = FnBaseResponse<PlayPlayResponse>.fromJson(
      response.data,
      (json) => PlayPlayResponse.fromJson(json as Map<String, dynamic>),
    );
    if (baseResponse.code != 0) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data!;
  }

  // Quit media playback
  Future<void> quitMedia(String playLink) async {
    final request = MediaPRequest(playLink: playLink);
    await _dioClient.dio.post(
      '/v/api/v1/mediap/quit',
      data: request.toJson(),
    );
  }

  // Reset quality for current playback
  Future<MediaResetQualityResponse> resetQuality(String playLink) async {
    final request = MediaPRequest(playLink: playLink);
    final response = await _dioClient.dio.post(
      '/v/api/v1/mediap/reset-quality',
      data: request.toJson(),
    );
    final baseResponse = FnBaseResponse<MediaResetQualityResponse>.fromJson(
      response.data,
      (json) =>
          MediaResetQualityResponse.fromJson(json as Map<String, dynamic>),
    );
    if (baseResponse.code != 0) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data!;
  }

  // Get available qualities
  Future<List<QualityResponse>> getQualities(String playLink) async {
    final request = MediaPRequest(playLink: playLink);
    final response = await _dioClient.dio.post(
      '/v/api/v1/mediap/quality',
      data: request.toJson(),
    );
    final baseResponse = FnBaseResponse<List<QualityResponse>>.fromJson(
      response.data,
      (json) => (json as List)
          .map((e) => QualityResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (baseResponse.code != 0) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data ?? [];
  }

  // Set quality for playback
  Future<String> setQuality({
    required String playLink,
    required String resolution,
    required int bitrate,
  }) async {
    final response = await _dioClient.dio.post(
      '/v/api/v1/mediap/set-quality',
      data: {
        'play_link': playLink,
        'resolution': resolution,
        'bitrate': bitrate,
      },
    );
    final baseResponse = FnBaseResponse<String>.fromJson(
      response.data,
      (json) => json as String,
    );
    if (baseResponse.code != 0) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data!;
  }

  // Update play record (progress)
  Future<void> updatePlayRecord({
    required String guid,
    required int ts,
    int? duration,
  }) async {
    await _dioClient.dio.post(
      '/v/api/v1/play/record',
      data: {
        'guid': guid,
        'ts': ts,
        if (duration != null) 'duration': duration,
      },
    );
  }

  // Set skip config for intro/outro
  Future<void> setSkipConfig({
    required String guid,
    required int skipOpening,
    required int skipEnding,
  }) async {
    final request = SetConfigByItemRequest(
      guid: guid,
      skipOpening: skipOpening,
      skipEnding: skipEnding,
    );
    await _dioClient.dio.post(
      '/v/api/v1/config/set-by-item',
      data: request.toJson(),
    );
  }

  // Build play URL for direct link
  String buildDirectPlayUrl({
    required String baseUrl,
    required String mediaGuid,
    String? audioGuid,
    String? subtitleGuid,
  }) {
    final url = StringBuffer('$baseUrl/v/api/v1/play/video?media_guid=$mediaGuid');
    if (audioGuid != null && audioGuid.isNotEmpty) {
      url.write('&audio_guid=$audioGuid');
    }
    if (subtitleGuid != null && subtitleGuid.isNotEmpty) {
      url.write('&subtitle_guid=$subtitleGuid');
    }
    return url.toString();
  }

  // Build HLS play URL
  String buildHlsPlayUrl(String playLink) {
    return playLink;
  }

  // Get IP hash from source name
  String getIpHash(String sourceName) {
    return md5.convert(utf8.encode(sourceName)).toString();
  }
}

final playerServiceProvider = Provider<PlayerService>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return PlayerService(dioClient, ref);
});