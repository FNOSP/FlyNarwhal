import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/base_response.dart';
import '../../../data/models/movie_detail_models.dart';
import '../../../data/models/tag_models.dart';
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
  @override
  FutureOr<MovieDetailState> build(String guid) async {
    state = const AsyncValue.loading();
    final dioClient = ref.read(dioClientProvider);
    final tagRepo = ref.read(tagRepositoryProvider);

    Future<T?> safeRequest<T>(Future<T> Function() request) async {
      try {
        return await request();
      } catch (_) {
        return null;
      }
    }

    final itemResult = await dioClient.dio.get('/v/api/v1/item/$guid');

    final streamResult = await safeRequest(
      () => dioClient.dio.get('/v/api/v1/stream/list/$guid'),
    );
    final playInfoResult = await safeRequest(
      () => dioClient.dio.post('/v/api/v1/play/info', data: {'guid': guid}),
    );
    final personListResult = await safeRequest(
      () => dioClient.dio.post('/v/api/v1/person/list/$guid', data: const {}),
    );
    final iso6391 = await safeRequest(() => tagRepo.getTag('iso6391')) ?? const <String, String>{};
    final iso6392 = await safeRequest(() => tagRepo.getTag('iso6392')) ?? const <String, String>{};
    final iso3166 = await safeRequest(() => tagRepo.getTag('iso3166')) ?? const <String, String>{};
    final genresList = await safeRequest(() => tagRepo.getGenres()) ?? const <GenresResponse>[];

    final itemResponse = FnBaseResponse<ItemResponse>.fromJson(
      itemResult.data as Map<String, dynamic>,
      (json) => ItemResponse.fromJson(json as Map<String, dynamic>),
    );
    if (itemResponse.code != 0) {
      throw Exception(itemResponse.msg);
    }

    final streamResponse = streamResult == null
        ? null
        : FnBaseResponse<StreamListResponse>.fromJson(
            (streamResult as dynamic).data as Map<String, dynamic>,
            (json) => StreamListResponse.fromJson(json as Map<String, dynamic>),
          );

    final playInfoResponse = playInfoResult == null
        ? null
        : FnBaseResponse<PlayInfoResponse>.fromJson(
            (playInfoResult as dynamic).data as Map<String, dynamic>,
            (json) => PlayInfoResponse.fromJson(json as Map<String, dynamic>),
          );

    final personListResponse = personListResult == null
        ? null
        : FnBaseResponse<PersonListResponse>.fromJson(
            (personListResult as dynamic).data as Map<String, dynamic>,
            (json) => PersonListResponse.fromJson(json as Map<String, dynamic>),
          );

    final genresMap = {for (var g in genresList) g.id: g.value};

    return MovieDetailState(
      item: itemResponse.data,
      streamList: streamResponse?.data,
      playInfo: playInfoResponse?.data,
      personList: personListResponse?.data?.list ?? [],
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

  bool _isSuccessResponse(dynamic data) {
    if (data is bool) return data;
    if (data is Map && data['success'] == true) return true;
    return false;
  }

  Future<ActionResult> toggleFavorite() async {
    final item = state.value?.item;
    if (item == null) return const ActionResult(success: false, message: '未找到影片信息');

    try {
      final dioClient = ref.read(dioClientProvider);
      final isFavorite = item.isFavorite == 1;

      debugPrint('favorite request: item_guid=$guid action=${isFavorite ? 'cancel' : 'add'}');
      final response = isFavorite
          ? await dioClient.dio.delete(
              '/v/api/v1/item/favorite',
              data: {'item_guid': guid},
            )
          : await dioClient.dio.put(
              '/v/api/v1/item/favorite',
              data: {'item_guid': guid},
            );

      if (_isSuccessResponse(response.data)) {
        final currentState = state.value!;
        state = AsyncValue.data(currentState.copyWith(
          item: item.copyWith(isFavorite: isFavorite ? 0 : 1),
        ));
        return ActionResult(success: true, message: isFavorite ? '已取消收藏' : '已收藏');
      }
      final message = response.data is Map ? response.data['message']?.toString() ?? '操作失败' : '操作失败';
      return ActionResult(success: false, message: message);
    } catch (e) {
      return ActionResult(success: false, message: e.toString());
    }
  }

  Future<ActionResult> toggleWatched() async {
    final item = state.value?.item;
    if (item == null) return const ActionResult(success: false, message: '未找到影片信息');

    try {
      final dioClient = ref.read(dioClientProvider);
      final isWatched = item.isWatched == 1;

      debugPrint('watched request: item_guid=$guid action=${isWatched ? 'cancel' : 'add'}');
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
        state = AsyncValue.data(currentState.copyWith(
          item: item.copyWith(isWatched: isWatched ? 0 : 1),
        ));
        return ActionResult(success: true, message: isWatched ? '标记为未观看' : '标记为已观看');
      }
      final message = response.data is Map ? response.data['message']?.toString() ?? '操作失败' : '操作失败';
      return ActionResult(success: false, message: message);
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
