import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/network/api_result.dart';
import '../../../data/models/media_request_models.dart';
import '../../../data/models/movie_detail_models.dart';
import '../../../domain/entities/tag_entity.dart';
import '../../../providers/providers.dart';

part 'movie_detail_view_model.g.dart';

class MovieDetailState {
  final ItemResponse? item;
  final StreamListResponse? streamList;
  final PlayInfoResponse? playInfo;
  final List<PersonList> personList;
  final Map<String, String> iso6391;
  final Map<String, String> iso6392;
  final Map<String, String> iso3166;
  final Map<int, String> genres;
  final bool isLoading;
  final String? error;

  MovieDetailState({
    this.item,
    this.streamList,
    this.playInfo,
    this.personList = const [],
    this.iso6391 = const {},
    this.iso6392 = const {},
    this.iso3166 = const {},
    this.genres = const {},
    this.isLoading = false,
    this.error,
  });

  MovieDetailState copyWith({
    ItemResponse? item,
    StreamListResponse? streamList,
    PlayInfoResponse? playInfo,
    List<PersonList>? personList,
    Map<String, String>? iso6391,
    Map<String, String>? iso6392,
    Map<String, String>? iso3166,
    Map<int, String>? genres,
    bool? isLoading,
    String? error,
  }) {
    return MovieDetailState(
      item: item ?? this.item,
      streamList: streamList ?? this.streamList,
      playInfo: playInfo ?? this.playInfo,
      personList: personList ?? this.personList,
      iso6391: iso6391 ?? this.iso6391,
      iso6392: iso6392 ?? this.iso6392,
      iso3166: iso3166 ?? this.iso3166,
      genres: genres ?? this.genres,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

@riverpod
class MovieDetailNotifier extends _$MovieDetailNotifier {
  Future<ItemResponse> _fetchItem() async {
    final remote = ref.read(mediaRemoteDataSourceProvider);
    return (await remote.getItemDetail(guid)).getOrThrow();
  }

  Future<StreamListResponse?> _fetchStreamList() async {
    final remote = ref.read(mediaRemoteDataSourceProvider);
    final result = await remote.getStreamList(guid);
    return result.dataOrNull;
  }

  @override
  FutureOr<MovieDetailState> build(String guid) async {
    final remote = ref.read(mediaRemoteDataSourceProvider);
    final tagRepo = ref.read(iTagRepositoryProvider);

    Future<T?> safeApiRequest<T>(
        Future<ApiResult<T>> Function() request) async {
      final result = await request();
      return result.dataOrNull;
    }

    final results = await Future.wait([
      _fetchItem(),
      _fetchStreamList(),
      safeApiRequest(
        () => remote.getPlayInfo(ItemGuidRequest(itemGuid: guid)),
      ),
      safeApiRequest(() => remote.getPersonList(guid)),
      safeApiRequest(() => tagRepo.getTag('iso6391')),
      safeApiRequest(() => tagRepo.getTag('iso6392')),
      safeApiRequest(() => tagRepo.getTag('iso3166')),
      safeApiRequest(() => tagRepo.getGenres()),
    ]);

    final item = results[0] as ItemResponse;
    final streamList = results[1] as StreamListResponse?;
    final playInfo = results[2] as PlayInfoResponse?;
    final personList = results[3] as List<PersonList>?;
    final iso6391 =
        (results[4] as Map<String, String>?) ?? const <String, String>{};
    final iso6392 =
        (results[5] as Map<String, String>?) ?? const <String, String>{};
    final iso3166 =
        (results[6] as Map<String, String>?) ?? const <String, String>{};
    final genresList =
        (results[7] as List<GenreEntity>?) ?? const <GenreEntity>[];
    final genresMap = <int, String>{for (final g in genresList) g.id: g.name};

    return MovieDetailState(
      item: item,
      streamList: streamList,
      playInfo: playInfo,
      personList: personList ?? const [],
      iso6391: iso6391,
      iso6392: iso6392,
      iso3166: iso3166,
      genres: genresMap,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<ActionResult> toggleFavorite() async {
    final item = state.value?.item;
    if (item == null) {
      return const ActionResult(success: false, message: '未找到影片信息');
    }

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
      return const ActionResult(success: false, message: '未找到影片信息');
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
        final refreshedItem = await _fetchItem();
        final refreshedStreamList = await _fetchStreamList();
        state = AsyncValue.data(currentState.copyWith(
          item: refreshedItem,
          streamList: refreshedStreamList,
        ));
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
}

class ActionResult {
  final bool success;
  final String message;

  const ActionResult({required this.success, required this.message});
}
