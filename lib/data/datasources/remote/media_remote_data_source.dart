import 'dart:collection';

import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../models/base_response.dart';
import '../../models/episode_list_response.dart';
import '../../models/home_models.dart';
import '../../models/media_request_models.dart';
import '../../models/movie_detail_models.dart';
import '../../models/person_models.dart';
import '../../models/player_models.dart';
import '../../models/season_list_response.dart';

/// 内存 LRU 缓存，附带 TTL 过期，用于 guid 详情类请求（getItemDetail/getStreamList 等）。
class _DetailCache {
  _DetailCache({int maxEntries = 64, Duration ttl = const Duration(minutes: 5)})
      : _maxEntries = maxEntries,
        _ttl = ttl;

  final int _maxEntries;
  final Duration _ttl;
  final LinkedHashMap<String, _CacheEntry> _map = LinkedHashMap<String, _CacheEntry>();

  dynamic get(String key) {
    final entry = _map[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expireAt)) {
      _map.remove(key);
      return null;
    }
    // 挪到最末尾实现 LRU
    _map.remove(key);
    _map[key] = entry;
    return entry.value;
  }

  void set(String key, dynamic value) {
    _map.remove(key);
    _map[key] = _CacheEntry(value: value, expireAt: DateTime.now().add(_ttl));
    while (_map.length > _maxEntries) {
      _map.remove(_map.keys.first);
    }
  }

  void invalidate(String guid) {
    final prefix = ':$guid';
    _map.removeWhere((key, value) => key.endsWith(prefix));
  }
}

class _CacheEntry {
  final dynamic value;
  final DateTime expireAt;

  _CacheEntry({required this.value, required this.expireAt});
}

/// Remote data source for media-related API calls
class MediaRemoteDataSource {
  final DioClient _dioClient;
  final _DetailCache _cache = _DetailCache();

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
    final key = 'itemDetail:$guid';
    final cached = _cache.get(key);
    if (cached is ApiResult<ItemResponse>) return cached;
    final result = await _dioClient.get<ItemResponse>(
      ApiEndpoints.itemByGuid(guid),
      converter: (data) => _parseItemDetailResponse(data),
    );
    if (result.isSuccess) _cache.set(key, result);
    return result;
  }

  /// Get stream list by guid
  Future<ApiResult<StreamListResponse?>> getStreamList(String guid) async {
    final key = 'streamList:$guid';
    final cached = _cache.get(key);
    if (cached is ApiResult<StreamListResponse?>) return cached;
    final result = await _dioClient.get<StreamListResponse?>(
      ApiEndpoints.streamListByGuid(guid),
      converter: (data) => _parseOptionalStreamListResponse(data),
    );
    if (result.isSuccess) _cache.set(key, result);
    return result;
  }

  /// Get play info by item guid
  Future<ApiResult<PlayInfoResponse?>> getPlayInfo(
      ItemGuidRequest request) async {
    final key = 'playInfo:${request.itemGuid}';
    final cached = _cache.get(key);
    if (cached is ApiResult<PlayInfoResponse?>) return cached;
    final result = await _dioClient.post<PlayInfoResponse?>(
      ApiEndpoints.playInfo,
      data: request.toJson(),
      converter: (data) => _parseOptionalPlayInfoResponse(data),
    );
    if (result.isSuccess) _cache.set(key, result);
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
    final result = await _dioClient.get<String>(
      ApiEndpoints.subtitleDownloadByGuid(guid),
    );
    return result;
  }

  /// Search media items by keyword (GET /v/api/v1/search/list?q=)
  Future<ApiResult<List<MediaItem>>> search(String query) async {
    final result = await _dioClient.get<List<MediaItem>>(
      ApiEndpoints.searchList,
      queryParameters: {'q': query},
      converter: (data) => _parseSearchResponse(data),
    );
    return result;
  }

  /// Get person detail by guid (GET /v/api/v1/person/{guid})
  Future<ApiResult<PersonResponse>> getPerson(String guid) async {
    final key = 'person:$guid';
    final cached = _cache.get(key);
    if (cached is ApiResult<PersonResponse>) return cached;
    final result = await _dioClient.get<PersonResponse>(
      ApiEndpoints.personByGuid(guid),
      converter: (data) => _parsePersonResponse(data),
    );
    if (result.isSuccess) _cache.set(key, result);
    return result;
  }

  /// Get person works grouped by job (POST /v/api/v1/person/item/list)
  Future<ApiResult<List<PersonItemList>>> getPersonItemList(
    PersonItemListRequest request,
  ) async {
    final result = await _dioClient.post<List<PersonItemList>>(
      ApiEndpoints.personItemList,
      data: request.toJson(),
      converter: (data) => _parsePersonItemListResponse(data),
    );
    return result;
  }

  /// Get person list by guid
  Future<ApiResult<List<PersonList>>> getPersonList(String guid) async {
    final key = 'personList:$guid';
    final cached = _cache.get(key);
    if (cached is ApiResult<List<PersonList>>) return cached;
    final result = await _dioClient.post<List<PersonList>>(
      ApiEndpoints.personListByGuid(guid),
      data: <String, dynamic>{},
      converter: (data) => _parsePersonListResponse(data),
    );
    if (result.isSuccess) _cache.set(key, result);
    return result;
  }

  /// Get season list by guid
  Future<ApiResult<List<SeasonListResponse>>> getSeasonList(String guid) async {
    final key = 'seasonList:$guid';
    final cached = _cache.get(key);
    if (cached is ApiResult<List<SeasonListResponse>>) return cached;
    final result = await _dioClient.get<List<SeasonListResponse>>(
      ApiEndpoints.seasonListByGuid(guid),
      converter: (data) => _parseSeasonListResponse(data),
    );
    if (result.isSuccess) _cache.set(key, result);
    return result;
  }

  /// Get episode list by guid
  Future<ApiResult<List<EpisodeListResponse>>> getEpisodeList(
      String guid) async {
    final key = 'episodeList:$guid';
    final cached = _cache.get(key);
    if (cached is ApiResult<List<EpisodeListResponse>>) return cached;
    final result = await _dioClient.get<List<EpisodeListResponse>>(
      ApiEndpoints.episodeListByGuid(guid),
      converter: (data) => _parseEpisodeListResponse(data),
    );
    if (result.isSuccess) _cache.set(key, result);
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
  }) async {
    final guid = request.itemGuid;
    final result = isFavorite
        ? await _dioClient.delete<bool>(
            ApiEndpoints.favorite,
            data: request.toJson(),
            converter: (data) => _parseSuccessResponse(data),
          )
        : await _dioClient.put<bool>(
            ApiEndpoints.favorite,
            data: request.toJson(),
            converter: (data) => _parseSuccessResponse(data),
          );
    if (result.isSuccess) _cache.invalidate(guid);
    return result;
  }

  /// Toggle watched state
  Future<ApiResult<bool>> toggleWatched(
    ItemGuidRequest request, {
    required bool isWatched,
  }) async {
    final guid = request.itemGuid;
    final result = isWatched
        ? await _dioClient.delete<bool>(
            ApiEndpoints.watched,
            data: request.toJson(),
            converter: (data) => _parseSuccessResponse(data),
          )
        : await _dioClient.post<bool>(
            ApiEndpoints.watched,
            data: request.toJson(),
            converter: (data) => _parseSuccessResponse(data),
          );
    if (result.isSuccess) _cache.invalidate(guid);
    return result;
  }

  /// 预取 item 详情，写入缓存；失败静默，不抛异常。
  Future<void> prefetchItemDetail(String guid) async {
    try {
      await getItemDetail(guid);
    } catch (_) {
      // 预取失败不报错
    }
  }

  /// 清除指定 guid 的所有详情缓存。
  void invalidateDetailCache(String guid) {
    _cache.invalidate(guid);
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
    try {
      final baseResponse = FnBaseResponse<ItemResponse>.fromJson(
        data,
        (json) => ItemResponse.fromJson(json as Map<String, dynamic>),
      );
      if (baseResponse.code != ResponseCodes.success ||
          baseResponse.data == null) {
        throw Exception(
          'Item detail response invalid: '
          'code=${baseResponse.code}, msg=${baseResponse.msg}, '
          '${_describeItemDetailData(data)}',
        );
      }
      return baseResponse.data!;
    } catch (e) {
      throw Exception(
        'Item detail parse failed: ${_describeItemDetailData(data)}; error=$e',
      );
    }
  }

  String _describeItemDetailData(dynamic data) {
    final buffer = StringBuffer('type=${data.runtimeType}');
    if (data is Map) {
      final keys = data.keys.take(10).map((key) => key.toString()).join(', ');
      buffer.write(', keys=[$keys]');
      final payload = data['data'];
      buffer.write(', dataType=${payload.runtimeType}');
      if (payload is Map) {
        final payloadKeys =
            payload.keys.take(10).map((key) => key.toString()).join(', ');
        buffer.write(', dataKeys=[$payloadKeys]');
      }
    }
    return buffer.toString();
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

  List<MediaItem> _parseSearchResponse(dynamic data) {
    final baseResponse = FnBaseResponse<List<MediaItem>>.fromJson(
      data,
      (json) => ((json as List<dynamic>?) ?? const <dynamic>[])
          .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (baseResponse.code != ResponseCodes.success) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data ?? const <MediaItem>[];
  }

  PersonResponse _parsePersonResponse(dynamic data) {
    final baseResponse = FnBaseResponse<PersonResponse>.fromJson(
      data,
      (json) => PersonResponse.fromJson(json as Map<String, dynamic>),
    );
    if (baseResponse.code != ResponseCodes.success ||
        baseResponse.data == null) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data!;
  }

  List<PersonItemList> _parsePersonItemListResponse(dynamic data) {
    final baseResponse = FnBaseResponse<PersonItemListQueryResponse>.fromJson(
      data,
      (json) => PersonItemListQueryResponse.fromJson(
          json as Map<String, dynamic>),
    );
    if (baseResponse.code != ResponseCodes.success) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data?.list ?? const <PersonItemList>[];
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
