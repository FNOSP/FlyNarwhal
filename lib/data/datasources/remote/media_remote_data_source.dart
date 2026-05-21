import 'package:dio/dio.dart';

import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../models/base_response.dart';
import '../../models/episode_list_response.dart';
import '../../models/home_models.dart';
import '../../models/media_request_models.dart';
import '../../models/movie_detail_models.dart';
import '../../models/player_models.dart';
import '../../models/season_list_response.dart';

/// Remote data source for media-related API calls
class MediaRemoteDataSource {
  final DioClient _dioClient;

  MediaRemoteDataSource(this._dioClient);

  /// Get list of media databases
  Future<ApiResult<List<MediaDbListResponse>>> getMediaDbList() async {
    final result = await _dioClient.get<List<MediaDbListResponse>>(
      ApiEndpoints.mediaDbList,
      converter: (data) => _parseMediaDbListResponse(data),
    );
    return result;
  }

  /// Get media statistics summary
  Future<ApiResult<Map<String, int>>> getMediaSum() async {
    final result = await _dioClient.get<Map<String, int>>(
      ApiEndpoints.mediaDbSum,
      converter: (data) => _parseMediaSumResponse(data),
    );
    return result;
  }

  /// Get play list (recently watched)
  Future<ApiResult<List<PlayDetailResponse>>> getPlayList() async {
    final result = await _dioClient.get<List<PlayDetailResponse>>(
      ApiEndpoints.playList,
      converter: (data) => _parsePlayListResponse(data),
    );
    return result;
  }

  /// Get item list by query
  Future<ApiResult<ItemListQueryResponse>> getItemList(
    ItemListQueryRequest request,
  ) async {
    final result = await _dioClient.post<ItemListQueryResponse>(
      ApiEndpoints.itemList,
      data: request.toJson(),
      converter: (data) => _parseItemListResponse(data),
    );
    return result;
  }

  /// Get favorite item list by query
  Future<ApiResult<ItemListQueryResponse>> getFavoriteList(
    ItemListQueryRequest request,
  ) async {
    final result = await _dioClient.post<ItemListQueryResponse>(
      ApiEndpoints.favoriteList,
      data: request.toJson(),
      converter: (data) => _parseItemListResponse(data),
    );
    return result;
  }

  /// Get item detail by guid
  Future<ApiResult<ItemResponse>> getItemDetail(String guid) async {
    final result = await _dioClient.get<ItemResponse>(
      ApiEndpoints.itemByGuid(guid),
      converter: (data) => _parseItemDetailResponse(data),
    );
    return result;
  }

  /// Get stream list by guid
  Future<ApiResult<StreamListResponse?>> getStreamList(String guid) async {
    final result = await _dioClient.get<StreamListResponse?>(
      ApiEndpoints.streamListByGuid(guid),
      converter: (data) => _parseOptionalStreamListResponse(data),
    );
    return result;
  }

  /// Get play info by item guid
  Future<ApiResult<PlayInfoResponse?>> getPlayInfo(
      ItemGuidRequest request) async {
    final result = await _dioClient.post<PlayInfoResponse?>(
      ApiEndpoints.playInfo,
      data: request.toJson(),
      converter: (data) => _parseOptionalPlayInfoResponse(data),
    );
    return result;
  }

  /// Get play info with an optional media override for player startup.
  Future<ApiResult<PlayInfoResponse?>> getPlayerPlayInfo(
    PlayInfoRequest request,
  ) async {
    final result = await _dioClient.post<PlayInfoResponse?>(
      ApiEndpoints.playInfo,
      data: request.toJson(),
      converter: (data) => _parseOptionalPlayInfoResponse(data),
    );
    return result;
  }

  /// Get stream info for the selected media source.
  Future<ApiResult<StreamResponse>> getStreamInfo(StreamRequest request) async {
    final result = await _dioClient.post<StreamResponse>(
      ApiEndpoints.stream,
      data: request.toJson(),
      converter: (data) => _parseStreamResponse(data),
    );
    return result;
  }

  /// Resolve the playable link for current stream parameters.
  Future<ApiResult<PlayPlayResponse>> playVideo(PlayPlayRequest request) async {
    final result = await _dioClient.post<PlayPlayResponse>(
      ApiEndpoints.playPlay,
      data: request.toJson(),
      converter: (data) => _parsePlayPlayResponse(data),
    );
    return result;
  }

  /// Download external subtitle content for media_kit rendering.
  Future<ApiResult<String>> downloadExternalSubtitle(String guid) async {
    try {
      final response = await _dioClient.dio.get<String>(
        ApiEndpoints.subtitleDownloadByGuid(guid),
        options: Options(responseType: ResponseType.plain),
      );
      return Success(response.data ?? '');
    } on DioException catch (e) {
      if (e.error is FailureInfo) {
        return ResultFailure(e.error as FailureInfo);
      }
      final message = e.message ?? 'Failed to download subtitle';
      return ResultFailure(FailureInfo.fromMessage(message));
    } catch (e) {
      return ResultFailure(FailureInfo.fromMessage(e.toString()));
    }
  }

  /// Get person list by guid
  Future<ApiResult<List<PersonList>>> getPersonList(String guid) async {
    final result = await _dioClient.post<List<PersonList>>(
      ApiEndpoints.personListByGuid(guid),
      data: const {},
      converter: (data) => _parsePersonListResponse(data),
    );
    return result;
  }

  /// Get season list by guid
  Future<ApiResult<List<SeasonListResponse>>> getSeasonList(String guid) async {
    final result = await _dioClient.get<List<SeasonListResponse>>(
      ApiEndpoints.seasonListByGuid(guid),
      converter: (data) => _parseSeasonListResponse(data),
    );
    return result;
  }

  /// Get episode list by guid
  Future<ApiResult<List<EpisodeListResponse>>> getEpisodeList(
      String guid) async {
    final result = await _dioClient.get<List<EpisodeListResponse>>(
      ApiEndpoints.episodeListByGuid(guid),
      converter: (data) => _parseEpisodeListResponse(data),
    );
    return result;
  }

  /// Fetch media transcode status from unified media/p endpoint.
  Future<ApiResult<MediaTranscodeResponse>> fetchTranscodeStatus(
    MediaPRequest request,
  ) async {
    final result = await _dioClient.post<MediaTranscodeResponse>(
      ApiEndpoints.mediaP,
      data: request.toJson(),
      converter: (data) => _parseMediaTranscodeResponse(data),
    );
    return result;
  }

  /// Reset media quality from unified media/p endpoint.
  Future<ApiResult<MediaResetQualityResponse>> resetQuality(
    MediaPRequest request,
  ) async {
    final result = await _dioClient.post<MediaResetQualityResponse>(
      ApiEndpoints.mediaP,
      data: request.toJson(),
      converter: (data) => _parseMediaResetQualityResponse(data),
    );
    return result;
  }

  /// Reset media audio from unified media/p endpoint.
  Future<ApiResult<MediaResetQualityResponse>> resetAudio(
    MediaPRequest request,
  ) async {
    final result = await _dioClient.post<MediaResetQualityResponse>(
      ApiEndpoints.mediaP,
      data: request.toJson(),
      converter: (data) => _parseMediaResetQualityResponse(data),
    );
    return result;
  }

  /// Reset media subtitle from unified media/p endpoint.
  Future<ApiResult<MediaResetQualityResponse>> resetSubtitle(
    MediaPRequest request,
  ) async {
    final result = await _dioClient.post<MediaResetQualityResponse>(
      ApiEndpoints.mediaP,
      data: request.toJson(),
      converter: (data) => _parseMediaResetQualityResponse(data),
    );
    return result;
  }

  /// Quit media session from unified media/p endpoint.
  Future<ApiResult<MediaResetQualityResponse>> quit(
      MediaPRequest request) async {
    final result = await _dioClient.post<MediaResetQualityResponse>(
      ApiEndpoints.mediaP,
      data: request.toJson(),
      converter: (data) => _parseMediaResetQualityResponse(data),
    );
    return result;
  }

  /// Persist the current playback progress.
  Future<ApiResult<bool>> updatePlayRecord(PlayRecordRequest request) async {
    final result = await _dioClient.post<bool>(
      ApiEndpoints.playRecord,
      data: request.toJson(),
      converter: (data) => _parseSuccessResponse(data),
    );
    return result;
  }

  /// Save intro and outro skip settings for an item.
  Future<ApiResult<bool>> setSkipConfig(SetConfigByItemRequest request) async {
    final result = await _dioClient.post<bool>(
      ApiEndpoints.configSetByItem,
      data: request.toJson(),
      converter: (data) => _parseSuccessResponse(data),
    );
    return result;
  }

  /// Toggle favorite status (add)
  Future<ApiResult<bool>> addFavorite(String guid) async {
    final result = await _dioClient.put<bool>(
      ApiEndpoints.favorite,
      data: ItemGuidRequest(itemGuid: guid).toJson(),
      converter: (data) => _parseSuccessResponse(data),
    );
    return result;
  }

  /// Toggle favorite status (remove)
  Future<ApiResult<bool>> removeFavorite(String guid) async {
    final result = await _dioClient.delete<bool>(
      ApiEndpoints.favorite,
      data: ItemGuidRequest(itemGuid: guid).toJson(),
      converter: (data) => _parseSuccessResponse(data),
    );
    return result;
  }

  /// Toggle watched status (mark as watched)
  Future<ApiResult<bool>> markWatched(String guid) async {
    final result = await _dioClient.post<bool>(
      ApiEndpoints.watched,
      data: ItemGuidRequest(itemGuid: guid).toJson(),
      converter: (data) => _parseSuccessResponse(data),
    );
    return result;
  }

  /// Toggle watched status (mark as unwatched)
  Future<ApiResult<bool>> markUnwatched(String guid) async {
    final result = await _dioClient.delete<bool>(
      ApiEndpoints.watched,
      data: ItemGuidRequest(itemGuid: guid).toJson(),
      converter: (data) => _parseSuccessResponse(data),
    );
    return result;
  }

  /// Toggle favorite state
  Future<ApiResult<bool>> toggleFavorite(
    ItemGuidRequest request, {
    required bool isFavorite,
  }) {
    if (isFavorite) {
      return _dioClient.delete<bool>(
        ApiEndpoints.favorite,
        data: request.toJson(),
        converter: (data) => _parseSuccessResponse(data),
      );
    }
    return _dioClient.put<bool>(
      ApiEndpoints.favorite,
      data: request.toJson(),
      converter: (data) => _parseSuccessResponse(data),
    );
  }

  /// Toggle watched state
  Future<ApiResult<bool>> toggleWatched(
    ItemGuidRequest request, {
    required bool isWatched,
  }) {
    if (isWatched) {
      return _dioClient.delete<bool>(
        ApiEndpoints.watched,
        data: request.toJson(),
        converter: (data) => _parseSuccessResponse(data),
      );
    }
    return _dioClient.post<bool>(
      ApiEndpoints.watched,
      data: request.toJson(),
      converter: (data) => _parseSuccessResponse(data),
    );
  }

  // Private parsing methods
  List<MediaDbListResponse> _parseMediaDbListResponse(dynamic data) {
    final baseResponse = FnBaseResponse<List<MediaDbListResponse>>.fromJson(
      data,
      (json) => (json as List)
          .map((e) => MediaDbListResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (baseResponse.code != ResponseCodes.success) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data ?? [];
  }

  Map<String, int> _parseMediaSumResponse(dynamic data) {
    final baseResponse = FnBaseResponse<Map<String, int>>.fromJson(
      data,
      (json) => (json as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, value as int)),
    );
    if (baseResponse.code != ResponseCodes.success) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data ?? {};
  }

  List<PlayDetailResponse> _parsePlayListResponse(dynamic data) {
    final baseResponse = FnBaseResponse<List<PlayDetailResponse>>.fromJson(
      data,
      (json) => (json as List)
          .map((e) => PlayDetailResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (baseResponse.code != ResponseCodes.success) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data ?? [];
  }

  ItemListQueryResponse _parseItemListResponse(dynamic data) {
    final baseResponse = FnBaseResponse<ItemListQueryResponse>.fromJson(
      data,
      (json) => ItemListQueryResponse.fromJson(json as Map<String, dynamic>),
    );
    if (baseResponse.code != ResponseCodes.success) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data ?? ItemListQueryResponse();
  }

  ItemResponse _parseItemDetailResponse(dynamic data) {
    final baseResponse = FnBaseResponse<ItemResponse>.fromJson(
      data,
      (json) => ItemResponse.fromJson(json as Map<String, dynamic>),
    );
    if (baseResponse.code != ResponseCodes.success ||
        baseResponse.data == null) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data!;
  }

  StreamListResponse? _parseOptionalStreamListResponse(dynamic data) {
    final baseResponse = FnBaseResponse<StreamListResponse>.fromJson(
      data,
      (json) => StreamListResponse.fromJson(json as Map<String, dynamic>),
    );
    return baseResponse.data;
  }

  PlayInfoResponse? _parseOptionalPlayInfoResponse(dynamic data) {
    final baseResponse = FnBaseResponse<PlayInfoResponse>.fromJson(
      data,
      (json) => PlayInfoResponse.fromJson(json as Map<String, dynamic>),
    );
    return baseResponse.data;
  }

  StreamResponse _parseStreamResponse(dynamic data) {
    final baseResponse = FnBaseResponse<StreamResponse>.fromJson(
      data,
      (json) => StreamResponse.fromJson(json as Map<String, dynamic>),
    );
    if (baseResponse.code != ResponseCodes.success ||
        baseResponse.data == null) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data!;
  }

  PlayPlayResponse _parsePlayPlayResponse(dynamic data) {
    final baseResponse = FnBaseResponse<PlayPlayResponse>.fromJson(
      data,
      (json) => PlayPlayResponse.fromJson(json as Map<String, dynamic>),
    );
    if (baseResponse.code != ResponseCodes.success ||
        baseResponse.data == null) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data!;
  }

  List<PersonList> _parsePersonListResponse(dynamic data) {
    final baseResponse = FnBaseResponse<PersonListResponse>.fromJson(
      data,
      (json) => PersonListResponse.fromJson(json as Map<String, dynamic>),
    );
    if (baseResponse.code != ResponseCodes.success) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data?.list ?? [];
  }

  List<SeasonListResponse> _parseSeasonListResponse(dynamic data) {
    final baseResponse = FnBaseResponse<List<SeasonListResponse>>.fromJson(
      data,
      (json) => ((json as List<dynamic>?) ?? const <dynamic>[])
          .map((e) => SeasonListResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (baseResponse.code != ResponseCodes.success) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data ?? const <SeasonListResponse>[];
  }

  List<EpisodeListResponse> _parseEpisodeListResponse(dynamic data) {
    if (data is List) {
      return data
          .map((e) => EpisodeListResponse.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final baseResponse = FnBaseResponse<List<EpisodeListResponse>>.fromJson(
      data,
      (json) => ((json as List<dynamic>?) ?? const <dynamic>[])
          .map((e) => EpisodeListResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (baseResponse.code != ResponseCodes.success) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data ?? const <EpisodeListResponse>[];
  }

  MediaTranscodeResponse _parseMediaTranscodeResponse(dynamic data) {
    final baseResponse = FnBaseResponse<MediaTranscodeResponse>.fromJson(
      data,
      (json) => MediaTranscodeResponse.fromJson(json as Map<String, dynamic>),
    );
    if (baseResponse.code != ResponseCodes.success ||
        baseResponse.data == null) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data!;
  }

  MediaResetQualityResponse _parseMediaResetQualityResponse(dynamic data) {
    final baseResponse = FnBaseResponse<MediaResetQualityResponse>.fromJson(
      data,
      (json) =>
          MediaResetQualityResponse.fromJson(json as Map<String, dynamic>),
    );
    if (baseResponse.code != ResponseCodes.success ||
        baseResponse.data == null) {
      throw Exception(baseResponse.msg);
    }
    final response = baseResponse.data!;
    if (!response.isSuccess) {
      throw Exception(response.describeFailure('media/p'));
    }
    return response;
  }

  bool _parseSuccessResponse(dynamic data) {
    if (data is bool) return data;
    if (data is Map) {
      if (data['code'] == ResponseCodes.success) return true;
      if (data['success'] == true) return true;
    }
    return false;
  }
}
