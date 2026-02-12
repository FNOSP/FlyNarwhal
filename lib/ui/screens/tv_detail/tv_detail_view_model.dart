import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/models/base_response.dart';
import '../../../data/models/movie_detail_models.dart';
import '../../../data/models/season_list_response.dart';
import '../../../data/models/tag_models.dart';
import '../../../providers/providers.dart';

part 'tv_detail_view_model.g.dart';

class TvDetailState {
  final ItemResponse? item;
  final PlayInfoResponse? playInfo;
  final List<SeasonListResponse> seasonList;
  final List<PersonList> personList;
  final List<QueryTagResponse> iso6391;
  final List<QueryTagResponse> iso6392;
  final List<QueryTagResponse> iso3166;
  final bool isLoading;
  final String? error;

  TvDetailState({
    this.item,
    this.playInfo,
    this.seasonList = const [],
    this.personList = const [],
    this.iso6391 = const [],
    this.iso6392 = const [],
    this.iso3166 = const [],
    this.isLoading = false,
    this.error,
  });

  TvDetailState copyWith({
    ItemResponse? item,
    PlayInfoResponse? playInfo,
    List<SeasonListResponse>? seasonList,
    List<PersonList>? personList,
    List<QueryTagResponse>? iso6391,
    List<QueryTagResponse>? iso6392,
    List<QueryTagResponse>? iso3166,
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
  @override
  FutureOr<TvDetailState> build(String guid) async {
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
    
    final playInfoResult = await safeRequest(
      () => dioClient.dio.post('/v/api/v1/play/info', data: {'guid': guid}),
    );
    
    final seasonListResult = await safeRequest(
      () => dioClient.dio.get('/v/api/v1/season/list/$guid'),
    );

    final personListResult = await safeRequest(
      () => dioClient.dio.post('/v/api/v1/person/list/$guid'),
    );
    
    final iso6391 = await safeRequest(() => tagRepo.getTag('iso6391', lan: 'zh')) ?? const <QueryTagResponse>[];
    final iso6392 = await safeRequest(() => tagRepo.getTag('iso6392', lan: 'zh')) ?? const <QueryTagResponse>[];
    final iso3166 = await safeRequest(() => tagRepo.getTag('iso3166', lan: 'zh')) ?? const <QueryTagResponse>[];

    final itemResponse = FnBaseResponse<ItemResponse>.fromJson(
      itemResult.data as Map<String, dynamic>,
      (json) => ItemResponse.fromJson(json as Map<String, dynamic>),
    );
    if (itemResponse.code != 0) {
      throw Exception(itemResponse.msg);
    }

    final playInfoResponse = playInfoResult == null
        ? null
        : FnBaseResponse<PlayInfoResponse>.fromJson(
            (playInfoResult as dynamic).data as Map<String, dynamic>,
            (json) => PlayInfoResponse.fromJson(json as Map<String, dynamic>),
          );
          
    List<SeasonListResponse> seasons = [];
    if (seasonListResult != null && seasonListResult.data is List) {
       seasons = (seasonListResult.data as List).map((e) => SeasonListResponse.fromJson(e)).toList();
    }
    
    final personListResponse = personListResult == null
        ? null
        : FnBaseResponse<PersonListResponse>.fromJson(
            (personListResult as dynamic).data as Map<String, dynamic>,
            (json) => PersonListResponse.fromJson(json as Map<String, dynamic>),
          );

    return TvDetailState(
      item: itemResponse.data,
      playInfo: playInfoResponse?.data,
      seasonList: seasons,
      personList: personListResponse?.data?.list ?? [],
      iso6391: iso6391,
      iso6392: iso6392,
      iso3166: iso3166,
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
        // Update local state
        final currentState = state.value!;
        state = AsyncValue.data(currentState.copyWith(
          item: item.copyWith(isFavorite: isFavorite ? 0 : 1),
        ));
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> toggleWatched() async {
    final item = state.value?.item;
    if (item == null) return;

    try {
      final dioClient = ref.read(dioClientProvider);
      final isWatched = item.isWatched == 1;
      
      final response = await dioClient.dio.get(
        isWatched ? '/v/api/v1/watched/delete' : '/v/api/v1/watched/add',
        queryParameters: {'guid': guid},
      );

      if (response.data['success'] == true) {
        // Update local state
        final currentState = state.value!;
        state = AsyncValue.data(currentState.copyWith(
          item: item.copyWith(isWatched: isWatched ? 0 : 1),
        ));
      }
    } catch (e) {
      // Handle error
    }
  }
  
  Future<void> toggleSeasonWatched(String seasonGuid, bool currentWatchedState) async {
    try {
      final dioClient = ref.read(dioClientProvider);
      final response = await dioClient.dio.get(
        currentWatchedState ? '/v/api/v1/watched/delete' : '/v/api/v1/watched/add',
        queryParameters: {'guid': seasonGuid},
      );

      if (response.data['success'] == true) {
         // Need to refresh or update specific season in list
         // For simplicity, refresh whole data or update list locally
         final currentState = state.value!;
         final updatedList = currentState.seasonList.map((season) {
             if (season.guid == seasonGuid) {
                 // Creating a copy manually as SeasonListResponse is immutable and we didn't add copyWith
                 // Ideally should add copyWith to SeasonListResponse
                 // For now, let's just refresh the data to keep it simple and correct
                 return season; 
             }
             return season;
         }).toList();
         
         // Actually refreshing is better to get correct counts/status from server
         refresh();
      }
    } catch (e) {
      // Handle error
    }
  }
}
