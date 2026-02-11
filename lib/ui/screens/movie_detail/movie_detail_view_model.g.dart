// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_detail_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$movieDetailNotifierHash() =>
    r'c6c7a8e691e78a0862c33773acb5a0d36d0e2786';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$MovieDetailNotifier
    extends BuildlessAutoDisposeAsyncNotifier<MovieDetailState> {
  late final String guid;

  FutureOr<MovieDetailState> build(
    String guid,
  );
}

/// See also [MovieDetailNotifier].
@ProviderFor(MovieDetailNotifier)
const movieDetailNotifierProvider = MovieDetailNotifierFamily();

/// See also [MovieDetailNotifier].
class MovieDetailNotifierFamily extends Family<AsyncValue<MovieDetailState>> {
  /// See also [MovieDetailNotifier].
  const MovieDetailNotifierFamily();

  /// See also [MovieDetailNotifier].
  MovieDetailNotifierProvider call(
    String guid,
  ) {
    return MovieDetailNotifierProvider(
      guid,
    );
  }

  @override
  MovieDetailNotifierProvider getProviderOverride(
    covariant MovieDetailNotifierProvider provider,
  ) {
    return call(
      provider.guid,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'movieDetailNotifierProvider';
}

/// See also [MovieDetailNotifier].
class MovieDetailNotifierProvider extends AutoDisposeAsyncNotifierProviderImpl<
    MovieDetailNotifier, MovieDetailState> {
  /// See also [MovieDetailNotifier].
  MovieDetailNotifierProvider(
    String guid,
  ) : this._internal(
          () => MovieDetailNotifier()..guid = guid,
          from: movieDetailNotifierProvider,
          name: r'movieDetailNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$movieDetailNotifierHash,
          dependencies: MovieDetailNotifierFamily._dependencies,
          allTransitiveDependencies:
              MovieDetailNotifierFamily._allTransitiveDependencies,
          guid: guid,
        );

  MovieDetailNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.guid,
  }) : super.internal();

  final String guid;

  @override
  FutureOr<MovieDetailState> runNotifierBuild(
    covariant MovieDetailNotifier notifier,
  ) {
    return notifier.build(
      guid,
    );
  }

  @override
  Override overrideWith(MovieDetailNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: MovieDetailNotifierProvider._internal(
        () => create()..guid = guid,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        guid: guid,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<MovieDetailNotifier, MovieDetailState>
      createElement() {
    return _MovieDetailNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MovieDetailNotifierProvider && other.guid == guid;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, guid.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MovieDetailNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<MovieDetailState> {
  /// The parameter `guid` of this provider.
  String get guid;
}

class _MovieDetailNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<MovieDetailNotifier,
        MovieDetailState> with MovieDetailNotifierRef {
  _MovieDetailNotifierProviderElement(super.provider);

  @override
  String get guid => (origin as MovieDetailNotifierProvider).guid;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
