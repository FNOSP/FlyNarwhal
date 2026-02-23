// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tv_detail_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$tvDetailNotifierHash() => r'bcbddf9e9a140ef65cc0624cd4db377b99c00946';

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

abstract class _$TvDetailNotifier
    extends BuildlessAutoDisposeAsyncNotifier<TvDetailState> {
  late final String guid;

  FutureOr<TvDetailState> build(
    String guid,
  );
}

/// See also [TvDetailNotifier].
@ProviderFor(TvDetailNotifier)
const tvDetailNotifierProvider = TvDetailNotifierFamily();

/// See also [TvDetailNotifier].
class TvDetailNotifierFamily extends Family<AsyncValue<TvDetailState>> {
  /// See also [TvDetailNotifier].
  const TvDetailNotifierFamily();

  /// See also [TvDetailNotifier].
  TvDetailNotifierProvider call(
    String guid,
  ) {
    return TvDetailNotifierProvider(
      guid,
    );
  }

  @override
  TvDetailNotifierProvider getProviderOverride(
    covariant TvDetailNotifierProvider provider,
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
  String? get name => r'tvDetailNotifierProvider';
}

/// See also [TvDetailNotifier].
class TvDetailNotifierProvider extends AutoDisposeAsyncNotifierProviderImpl<
    TvDetailNotifier, TvDetailState> {
  /// See also [TvDetailNotifier].
  TvDetailNotifierProvider(
    String guid,
  ) : this._internal(
          () => TvDetailNotifier()..guid = guid,
          from: tvDetailNotifierProvider,
          name: r'tvDetailNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$tvDetailNotifierHash,
          dependencies: TvDetailNotifierFamily._dependencies,
          allTransitiveDependencies:
              TvDetailNotifierFamily._allTransitiveDependencies,
          guid: guid,
        );

  TvDetailNotifierProvider._internal(
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
  FutureOr<TvDetailState> runNotifierBuild(
    covariant TvDetailNotifier notifier,
  ) {
    return notifier.build(
      guid,
    );
  }

  @override
  Override overrideWith(TvDetailNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: TvDetailNotifierProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<TvDetailNotifier, TvDetailState>
      createElement() {
    return _TvDetailNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TvDetailNotifierProvider && other.guid == guid;
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
mixin TvDetailNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<TvDetailState> {
  /// The parameter `guid` of this provider.
  String get guid;
}

class _TvDetailNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<TvDetailNotifier,
        TvDetailState> with TvDetailNotifierRef {
  _TvDetailNotifierProviderElement(super.provider);

  @override
  String get guid => (origin as TvDetailNotifierProvider).guid;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
