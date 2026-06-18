import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_result.dart';
import '../../../data/models/movie_detail_models.dart';
import '../../../data/models/episode_list_response.dart';
import '../../../data/models/media_request_models.dart';
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
  Future<T?> _safeApiRequest<T>(Future<ApiResult<T>> Function() request) async {
    final result = await request();
    return result.dataOrNull;
  }

  Future<PlayInfoResponse?> _fetchPlayInfo() async {
    final remote = ref.read(mediaRemoteDataSourceProvider);
    final result = await remote.getPlayInfo(ItemGuidRequest(itemGuid: guid));
    return result.dataOrNull;
  }

  Future<List<EpisodeListResponse>> _fetchEpisodeList() async {
    final remote = ref.read(mediaRemoteDataSourceProvider);
    final result = await remote.getEpisodeList(guid);
    return result.dataOrNull ?? const <EpisodeListResponse>[];
  }

  Future<void> _fetchStreamList() async {
    final remote = ref.read(mediaRemoteDataSourceProvider);
    await remote.getStreamList(guid);
  }

  @override
  FutureOr<TvSeasonDetailState> build(String guid) async {
    state = const AsyncValue.loading();
    final remote = ref.read(mediaRemoteDataSourceProvider);
    final tagRepo = ref.read(iTagRepositoryProvider);

    final itemResult = await _fetchItemDetailResult(guid);
    final item = itemResult.dataOrNull;
    if (item == null) {
      throw Exception(itemResult.failureOrNull?.displayMessage ?? '未找到分季信息');
    }
    final playInfo = await _fetchPlayInfo();
    final episodes = await _fetchEpisodeList();
    final personList = await _safeApiRequest(
      () => remote.getPersonList(guid),
    );
    // Reuse ApiResult helpers so tag loading matches the rest of the data flow.
    final iso6391 = await _safeApiRequest(() => tagRepo.getTag('iso6391')) ??
        const <String, String>{};
    final iso6392 = await _safeApiRequest(() => tagRepo.getTag('iso6392')) ??
        const <String, String>{};
    final iso3166 = await _safeApiRequest(() => tagRepo.getTag('iso3166')) ??
        const <String, String>{};

    return TvSeasonDetailState(
      item: item,
      playInfo: playInfo,
      episodeList: episodes,
      personList: personList ?? const [],
      iso6391: iso6391,
      iso6392: iso6392,
      iso3166: iso3166,
    );
  }

  Future<ItemResponse?> _fetchItemDetail(String itemGuid) async {
    final result = await _fetchItemDetailResult(itemGuid);
    return result.dataOrNull;
  }

  Future<ApiResult<ItemResponse>> _fetchItemDetailResult(
      String itemGuid) async {
    final remote = ref.read(mediaRemoteDataSourceProvider);
    return remote.getItemDetail(itemGuid);
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
      final remote = ref.read(mediaRemoteDataSourceProvider);
      final isFavorite = item.isFavorite == 1;
      final response = await remote.toggleFavorite(
        ItemGuidRequest(itemGuid: guid),
        isFavorite: isFavorite,
      );

      if (response.getOrElse(false)) {
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
      final remote = ref.read(mediaRemoteDataSourceProvider);
      final isWatched = item.isWatched == 1;
      final response = await remote.toggleWatched(
        ItemGuidRequest(itemGuid: guid),
        isWatched: isWatched,
      );

      if (response.getOrElse(false)) {
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
        message: response.failureOrNull?.displayMessage ?? '操作失败',
      );
    } catch (e) {
      return ActionResult(success: false, message: e.toString());
    }
  }

  Future<bool> toggleEpisodeFavorite(
      String episodeGuid, bool currentFavoriteState) async {
    try {
      final remote = ref.read(mediaRemoteDataSourceProvider);
      final response = await remote.toggleFavorite(
        ItemGuidRequest(itemGuid: episodeGuid),
        isFavorite: currentFavoriteState,
      );

      if (response.getOrElse(false)) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> toggleEpisodeWatched(
      String episodeGuid, bool currentWatchedState) async {
    try {
      final remote = ref.read(mediaRemoteDataSourceProvider);
      final response = await remote.toggleWatched(
        ItemGuidRequest(itemGuid: episodeGuid),
        isWatched: currentWatchedState,
      );

      if (response.getOrElse(false)) {
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
