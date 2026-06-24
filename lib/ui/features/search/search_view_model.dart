import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/home_models.dart';
import '../../../domain/entities/tag_entity.dart';
import '../../../providers/providers.dart';

/// Search state holding query, results and loading/error flags.
/// Mirrors Compose SearchViewModel's UiState (Initial/Loading/Success/Error).
class SearchState {
  final String query;
  final List<MediaItem> results;
  final bool isLoading;
  final String? error;
  final bool hasSearched;

  const SearchState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.error,
    this.hasSearched = false,
  });

  SearchState copyWith({
    String? query,
    List<MediaItem>? results,
    bool? isLoading,
    String? error,
    bool? hasSearched,
    bool clearError = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      hasSearched: hasSearched ?? this.hasSearched,
    );
  }
}

/// Search notifier with 300ms debounce, replicating Compose SearchViewModel.
class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this._ref) : super(const SearchState());

  final Ref _ref;
  Timer? _debounce;
  int _requestToken = 0;

  /// Debounced search; empty query resets to initial state.
  void search(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _requestToken++;
      state = const SearchState();
      return;
    }
    state = state.copyWith(query: query, isLoading: true, clearError: true);
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(query);
    });
  }

  Future<void> _runSearch(String query) async {
    final token = ++_requestToken;
    try {
      final remote = _ref.read(mediaRemoteDataSourceProvider);
      final result = await remote.search(query.trim());
      // Drop stale responses
      if (token != _requestToken) return;
      final items = result.getOrThrow();
      state = state.copyWith(
        query: query,
        results: items,
        isLoading: false,
        hasSearched: true,
        clearError: true,
      );
    } catch (e) {
      if (token != _requestToken) return;
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        hasSearched: true,
      );
    }
  }

  /// Clear search results and reset state.
  void clearSearch() {
    _debounce?.cancel();
    _requestToken++;
    state = const SearchState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final searchProvider =
    StateNotifierProvider.autoDispose<SearchNotifier, SearchState>(
  (ref) => SearchNotifier(ref),
);

/// Genre id -> name map for displaying genre labels in search results.
final searchGenresProvider = FutureProvider.autoDispose<Map<int, String>>(
  (ref) async {
    final repo = ref.read(iTagRepositoryProvider);
    final result = await repo.getGenres();
    final list = result.dataOrNull ?? const <GenreEntity>[];
    return {for (final g in list) g.id: g.name};
  },
);
