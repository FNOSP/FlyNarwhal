import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_result.dart';
import '../../../data/models/media_request_models.dart';
import '../../../data/models/movie_detail_models.dart';
import '../../../data/models/season_list_response.dart';
import '../../../providers/providers.dart';

part 'tv_detail_view_model.g.dart';

class TvDetailState {
  final ItemResponse? item;
  final PlayInfoResponse? playInfo;
  final List<SeasonListResponse> seasonList;
  final List<PersonList> personList;
  final Map<String, String> iso6391;
  final Map<String, String> iso6392;
  final Map<String, String> iso3166;
  final bool isLoading;
  final String? error;

  TvDetailState({
    this.item,
    this.playInfo,
    this.seasonList = const [],
    this.personList = const [],
    this.iso6391 = const {},
    this.iso6392 = const {},
    this.iso3166 = const {},
    this.isLoading = false,
    this.error,
  });

  TvDetailState copyWith({
    ItemResponse? item,
    PlayInfoResponse? playInfo,
    List<SeasonListResponse>? seasonList,
    List<PersonList>? personList,
    Map<String, String>? iso6391,
    Map<String, String>? iso6392,
    Map<String, String>? iso3166,
    bool? isLoading,
    String? error,
  }) {
    return TvDetailState(
      item: item ?? this.item,
      playInfo: playInfo ?? this.playInfo,
      seasonList: seasonList ?? this.seasonList,
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
class TvDetailNotifier extends _$TvDetailNotifier {
  Future<ItemResponse> _fetchItem() async {
    final remote = ref.read(mediaRemoteDataSourceProvider);
    return (await remote.getItemDetail(guid)).getOrThrow();
  }

  Future<PlayInfoResponse?> _fetchPlayInfo() async {
    final remote = ref.read(mediaRemoteDataSourceProvider);
    final result =
        await remote.getPlayInfo(ItemGuidRequest(itemGuid: guid));
    return result.dataOrNull;
  }

  Future<List<SeasonListResponse>> _fetchSeasonList() async {
    final remote = ref.read(mediaRemoteDataSourceProvider);
    final result = await remote.getSeasonList(guid);
    return result.dataOrNull ?? const <SeasonListResponse>[];
  }

  Future<void> _refreshState({
    bool refreshItem = true,
    bool refreshPlayInfo = false,
    bool refreshSeasonList = false,
  }) async {
    final currentState = state.value;
    if (currentState == null) return;

    final item = refreshItem ? await _fetchItem() : currentState.item;
    final playInfo =
        refreshPlayInfo ? await _fetchPlayInfo() : currentState.playInfo;
    final seasonList =
        refreshSeasonList ? await _fetchSeasonList() : currentState.seasonList;

    state = AsyncValue.data(currentState.copyWith(
      item: item,
      playInfo: playInfo,
      seasonList: seasonList,
    ));
  }

  @override
  FutureOr<TvDetailState> build(String guid) async {
    state = const AsyncValue.loading();
    final remote = ref.read(mediaRemoteDataSourceProvider);
    final tagRepo = ref.read(iTagRepositoryProvider);

    Future<T?> safeApiRequest<T>(Future<ApiResult<T>> Function() request) async {
      final result = await request();
      return result.dataOrNull;
    }

    final item = await _fetchItem();
    final playInfo = await _fetchPlayInfo();
    final seasons = await _fetchSeasonList();

    final personList = await safeApiRequest(
      () => remote.getPersonList(guid),
    );

    // Reuse ApiResult helpers so tag failures degrade to empty maps consistently.
    final iso6391 = await safeApiRequest(() => tagRepo.getTag('iso6391')) ??
        const <String, String>{};
    final iso6392 = await safeApiRequest(() => tagRepo.getTag('iso6392')) ??
        const <String, String>{};
    final iso3166 = await safeApiRequest(() => tagRepo.getTag('iso3166')) ??
        const <String, String>{};

    return TvDetailState(
      item: item,
      playInfo: playInfo,
      seasonList: seasons,
      personList: personList ?? const [],
      iso6391: iso6391,
      iso6392: iso6392,
      iso3166: iso3166,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<ActionResult> toggleFavorite() async {
    final item = state.value?.item;
    if (item == null) {
      return const ActionResult(success: false, message: '未找到剧集信息');
    }

    try {
      final remote = ref.read(mediaRemoteDataSourceProvider);
      final isFavorite = item.isFavorite == 1;
      final response = await remote.toggleFavorite(
        ItemGuidRequest(itemGuid: guid),
        isFavorite: isFavorite,
      );

      if (response.getOrElse(false)) {
        await _refreshState();
        return ActionResult(
            success: true, message: isFavorite ? '已取消收藏' : '已收藏');
      }
      return ActionResult(
        success: false,
        message: response.failureOrNull?.displayMessage ?? '操作失败',
      );
    } catch (e) {
      return ActionResult(success: false, message: e.toString());
    }
  }

  Future<ActionResult> toggleWatched() async {
    final item = state.value?.item;
    if (item == null) {
      return const ActionResult(success: false, message: '未找到剧集信息');
    }

    try {
      final remote = ref.read(mediaRemoteDataSourceProvider);
      final isWatched = item.isWatched == 1;
      final response = await remote.toggleWatched(
        ItemGuidRequest(itemGuid: guid),
        isWatched: isWatched,
      );

      if (response.getOrElse(false)) {
        await _refreshState(refreshPlayInfo: true, refreshSeasonList: true);
        return ActionResult(
            success: true, message: isWatched ? '标记为未观看' : '标记为已观看');
      }
      return ActionResult(
        success: false,
        message: response.failureOrNull?.displayMessage ?? '操作失败',
      );
    } catch (e) {
      return ActionResult(success: false, message: e.toString());
    }
  }

  Future<ActionResult> toggleSeasonWatched(
      String seasonGuid, bool currentWatchedState) async {
    try {
      final remote = ref.read(mediaRemoteDataSourceProvider);
      final response = await remote.toggleWatched(
        ItemGuidRequest(itemGuid: seasonGuid),
        isWatched: currentWatchedState,
      );

      if (response.getOrElse(false)) {
        await _refreshState(refreshPlayInfo: true, refreshSeasonList: true);
        return ActionResult(
            success: true, message: currentWatchedState ? '标记为未观看' : '标记为已观看');
      }
      return ActionResult(
        success: false,
        message: response.failureOrNull?.displayMessage ?? '操作失败',
      );
    } catch (e) {
      return ActionResult(success: false, message: e.toString());
    }
  }
}

class ActionResult {
  final bool success;
  final String message;

  const ActionResult({required this.success, required this.message});
}
