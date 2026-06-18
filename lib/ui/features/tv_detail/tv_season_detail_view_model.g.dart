// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tv_season_detail_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$tvSeasonDetailNotifierHash() =>
    r'3d474c4be13dc701c0d80a048f5613059525b11f';

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

abstract class _$TvSeasonDetailNotifier
    extends BuildlessAutoDisposeAsyncNotifier<TvSeasonDetailState> {
  late final String guid;

  FutureOr<TvSeasonDetailState> build(
    String guid,
  );
}

/// See also [TvSeasonDetailNotifier].
@ProviderFor(TvSeasonDetailNotifier)
const tvSeasonDetailNotifierProvider = TvSeasonDetailNotifierFamily();

/// See also [TvSeasonDetailNotifier].
class TvSeasonDetailNotifierFamily
    extends Family<AsyncValue<TvSeasonDetailState>> {
  /// See also [TvSeasonDetailNotifier].
  const TvSeasonDetailNotifierFamily();

  /// See also [TvSeasonDetailNotifier].
  TvSeasonDetailNotifierProvider call(
    String guid,
  ) {
    return TvSeasonDetailNotifierProvider(
      guid,
    );
  }

  @override
  TvSeasonDetailNotifierProvider getProviderOverride(
    covariant TvSeasonDetailNotifierProvider provider,
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
  String? get name => r'tvSeasonDetailNotifierProvider';
}

/// See also [TvSeasonDetailNotifier].
class TvSeasonDetailNotifierProvider
    extends AutoDisposeAsyncNotifierProviderImpl<TvSeasonDetailNotifier,
        TvSeasonDetailState> {
  /// See also [TvSeasonDetailNotifier].
  TvSeasonDetailNotifierProvider(
    String guid,
  ) : this._internal(
          () => TvSeasonDetailNotifier()..guid = guid,
          from: tvSeasonDetailNotifierProvider,
          name: r'tvSeasonDetailNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$tvSeasonDetailNotifierHash,
          dependencies: TvSeasonDetailNotifierFamily._dependencies,
          allTransitiveDependencies:
              TvSeasonDetailNotifierFamily._allTransitiveDependencies,
          guid: guid,
        );

  TvSeasonDetailNotifierProvider._internal(
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
  FutureOr<TvSeasonDetailState> runNotifierBuild(
    covariant TvSeasonDetailNotifier notifier,
  ) {
    return notifier.build(
      guid,
    );
  }

  @override
  Override overrideWith(TvSeasonDetailNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: TvSeasonDetailNotifierProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<TvSeasonDetailNotifier,
      TvSeasonDetailState> createElement() {
    return _TvSeasonDetailNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TvSeasonDetailNotifierProvider && other.guid == guid;
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
mixin TvSeasonDetailNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<TvSeasonDetailState> {
  /// The parameter `guid` of this provider.
  String get guid;
}

class _TvSeasonDetailNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<TvSeasonDetailNotifier,
        TvSeasonDetailState> with TvSeasonDetailNotifierRef {
  _TvSeasonDetailNotifierProviderElement(super.provider);

  @override
  String get guid => (origin as TvSeasonDetailNotifierProvider).guid;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
