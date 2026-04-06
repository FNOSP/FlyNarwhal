import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/models/base_response.dart';
import '../../../data/models/movie_detail_models.dart';
import '../../../data/models/episode_list_response.dart';
import '../../../providers/providers.dart';

part 'tv_season_detail_view_model.g.dart';

class TvSeasonDetailState {
  final ItemResponse? item;
  final PlayInfoResponse? playInfo;
  final List<EpisodeListResponse> episodeList;
  final List<PersonList> personList;
  final Map<String, String> iso6391;
  final Map<String, String> iso6392;
  final Map<String, String> iso3166;
  final bool isLoading;
  final String? error;

  TvSeasonDetailState({
    this.item,
    this.playInfo,
    this.episodeList = const [],
    this.personList = const [],
    this.iso6391 = const {},
    this.iso6392 = const {},
    this.iso3166 = const {},
    this.isLoading = false,
    this.error,
  });

  TvSeasonDetailState copyWith({
    ItemResponse? item,
    PlayInfoResponse? playInfo,
    List<EpisodeListResponse>? episodeList,
    List<PersonList>? personList,
    Map<String, String>? iso6391,
    Map<String, String>? iso6392,
    Map<String, String>? iso3166,
    bool? isLoading,
    String? error,
  }) {
    return TvSeasonDetailState(
      item: item ?? this.item,
      playInfo: playInfo ?? this.playInfo,
      episodeList: episodeList ?? this.episodeList,
      personList: personList ?? this.personList,
      iso6391: iso6391 ?? this.iso6391,
      iso6392: iso6392 ?? this.iso6392,
      iso3166: iso3166 ?? this.iso3166,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

@riverpod
class TvSeasonDetailNotifier extends _$TvSeasonDetailNotifier {
  Future<T?> _safeRequest<T>(Future<T> Function() request) async {
    try {
      return await request();
    } catch (_) {
      return null;
    }
  }

  List<EpisodeListResponse> _parseEpisodeList(dynamic payload) {
    if (payload is List) {
      return payload
          .map((e) => EpisodeListResponse.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (payload is Map<String, dynamic>) {
      final baseResponse = FnBaseResponse<List<EpisodeListResponse>>.fromJson(
        payload,
        (json) => ((json as List<dynamic>?) ?? const <dynamic>[])
            .map((e) =>
                EpisodeListResponse.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      return baseResponse.data ?? const <EpisodeListResponse>[];
    }
    return const <EpisodeListResponse>[];
  }

  Future<PlayInfoResponse?> _fetchPlayInfo() async {
    final dioClient = ref.read(dioClientProvider);
    final response = await _safeRequest(
      () => dioClient.dio.post('/v/api/v1/play/info', data: {'guid': guid}),
    );
    if (response == null) {
      return null;
    }
    final playInfoResponse = FnBaseResponse<PlayInfoResponse>.fromJson(
      (response as dynamic).data as Map<String, dynamic>,
      (json) => PlayInfoResponse.fromJson(json as Map<String, dynamic>),
    );
    return playInfoResponse.data;
  }

  Future<List<EpisodeListResponse>> _fetchEpisodeList() async {
    final dioClient = ref.read(dioClientProvider);
    final response = await _safeRequest(
      () => dioClient.dio.get('/v/api/v1/episode/list/$guid'),
    );
    if (response == null) {
      return const <EpisodeListResponse>[];
    }
    return _parseEpisodeList((response as dynamic).data);
  }

  Future<void> _fetchStreamList() async {
    final dioClient = ref.read(dioClientProvider);
    final response = await _safeRequest(
      () => dioClient.dio.get('/v/api/v1/stream/list/$guid'),
    );
    if (response == null) {
      return;
    }
    FnBaseResponse<StreamListResponse>.fromJson(
      (response as dynamic).data as Map<String, dynamic>,
      (json) => StreamListResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  String _resolveMessage(dynamic data) {
    if (data is Map) {
      return data['message']?.toString() ?? data['msg']?.toString() ?? '操作失败';
    }
    return '操作失败';
  }

  @override
  FutureOr<TvSeasonDetailState> build(String guid) async {
    state = const AsyncValue.loading();
    final tagRepo = ref.read(tagRepositoryProvider);

    final item = await _fetchItemDetail(guid);
    if (item == null) {
      throw Exception('未找到分季信息');
    }
    final playInfo = await _fetchPlayInfo();
    final episodes = await _fetchEpisodeList();
    final personListResult = await _safeRequest(
      () => ref.read(dioClientProvider).dio.post(
            '/v/api/v1/person/list/$guid',
            data: const {},
          ),
    );
    final iso6391 = await _safeRequest(() => tagRepo.getTag('iso6391')) ??
        const <String, String>{};
    final iso6392 = await _safeRequest(() => tagRepo.getTag('iso6392')) ??
        const <String, String>{};
    final iso3166 = await _safeRequest(() => tagRepo.getTag('iso3166')) ??
        const <String, String>{};
    final personListResponse = personListResult == null
        ? null
        : FnBaseResponse<PersonListResponse>.fromJson(
            (personListResult as dynamic).data as Map<String, dynamic>,
            (json) => PersonListResponse.fromJson(json as Map<String, dynamic>),
          );

    return TvSeasonDetailState(
      item: item,
      playInfo: playInfo,
      episodeList: episodes,
      personList: personListResponse?.data?.list ?? [],
      iso6391: iso6391,
      iso6392: iso6392,
      iso3166: iso3166,
    );
  }

  bool _isSuccessResponse(dynamic data) {
    if (data is bool) {
      return data;
    }
    if (data is Map && (data['success'] == true || data['code'] == 0)) {
      return true;
    }
    return false;
  }

  Future<ItemResponse?> _fetchItemDetail(String itemGuid) async {
    final response = await _safeRequest(
      () => ref.read(dioClientProvider).dio.get('/v/api/v1/item/$itemGuid'),
    );
    if (response == null) {
      return null;
    }
    final itemResponse = FnBaseResponse<ItemResponse>.fromJson(
      (response as dynamic).data as Map<String, dynamic>,
      (json) => ItemResponse.fromJson(json as Map<String, dynamic>),
    );
    if (itemResponse.code == 0) {
      return itemResponse.data;
    }
    return null;
  }

  void _replaceItem(ItemResponse item) {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(
      currentState.copyWith(item: item),
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> toggleFavorite() async {
    final item = state.value?.item;
    if (item == null) return;

    try {
      final dioClient = ref.read(dioClientProvider);
      final isFavorite = item.isFavorite == 1;

      final response = await dioClient.dio.get(
        isFavorite ? '/v/api/v1/favorite/delete' : '/v/api/v1/favorite/add',
        queryParameters: {'guid': guid},
      );

      if (response.data['success'] == true) {
        final currentState = state.value!;
        state = AsyncValue.data(currentState.copyWith(
          item: item.copyWith(isFavorite: isFavorite ? 0 : 1),
        ));
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<ActionResult> toggleWatched() async {
    final item = state.value?.item;
    if (item == null) {
      return const ActionResult(success: false, message: '未找到分季信息');
    }

    try {
      final dioClient = ref.read(dioClientProvider);
      final isWatched = item.isWatched == 1;

      final response = isWatched
          ? await dioClient.dio.delete(
              '/v/api/v1/item/watched',
              data: {'item_guid': guid},
            )
          : await dioClient.dio.post(
              '/v/api/v1/item/watched',
              data: {'item_guid': guid},
            );

      if (_isSuccessResponse(response.data)) {
        final currentState = state.value!;
        final results = await Future.wait<dynamic>([
          _fetchStreamList(),
          _fetchItemDetail(guid),
          _fetchEpisodeList(),
        ]);
        final refreshedItem = results[1] as ItemResponse?;
        final refreshedEpisodeList = results[2] as List<EpisodeListResponse>;
        state = AsyncValue.data(currentState.copyWith(
          item: refreshedItem ?? currentState.item,
          episodeList: refreshedEpisodeList,
        ));
        return ActionResult(
          success: true,
          message: isWatched ? '标记为未观看' : '标记为已观看',
        );
      }
      return ActionResult(
        success: false,
        message: _resolveMessage(response.data),
      );
    } catch (e) {
      return ActionResult(success: false, message: e.toString());
    }
  }

  Future<bool> toggleEpisodeFavorite(
      String episodeGuid, bool currentFavoriteState) async {
    try {
      final dioClient = ref.read(dioClientProvider);
      final response = currentFavoriteState
          ? await dioClient.dio.delete(
              '/v/api/v1/item/favorite',
              data: {'item_guid': episodeGuid},
            )
          : await dioClient.dio.put(
              '/v/api/v1/item/favorite',
              data: {'item_guid': episodeGuid},
            );

      if (_isSuccessResponse(response.data)) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> toggleEpisodeWatched(
      String episodeGuid, bool currentWatchedState) async {
    try {
      final dioClient = ref.read(dioClientProvider);
      final response = currentWatchedState
          ? await dioClient.dio.delete(
              '/v/api/v1/item/watched',
              data: {'item_guid': episodeGuid},
            )
          : await dioClient.dio.post(
              '/v/api/v1/item/watched',
              data: {'item_guid': episodeGuid},
            );

      if (_isSuccessResponse(response.data)) {
        final item = await _fetchItemDetail(guid);
        if (item != null) {
          _replaceItem(item);
        }
        return true;
      }
    } catch (_) {}
    return false;
  }
}

class ActionResult {
  final bool success;
  final String message;

  const ActionResult({required this.success, required this.message});
}
