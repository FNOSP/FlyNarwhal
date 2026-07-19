// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$mediaDbListNotifierHash() =>
    r'5d89fee0cd72aaf9b3ece7f2c1e8df174639aeaf';

/// See also [MediaDbListNotifier].
@ProviderFor(MediaDbListNotifier)
final mediaDbListNotifierProvider = AutoDisposeAsyncNotifierProvider<
    MediaDbListNotifier, List<MediaDbListResponse>>.internal(
  MediaDbListNotifier.new,
  name: r'mediaDbListNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$mediaDbListNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MediaDbListNotifier
    = AutoDisposeAsyncNotifier<List<MediaDbListResponse>>;
String _$mediaSumNotifierHash() => r'b63e3266e27a47fe408255c39aaa310a07a03b2a';

/// See also [MediaSumNotifier].
@ProviderFor(MediaSumNotifier)
final mediaSumNotifierProvider = AutoDisposeAsyncNotifierProvider<
    MediaSumNotifier, Map<String, int>>.internal(
  MediaSumNotifier.new,
  name: r'mediaSumNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$mediaSumNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MediaSumNotifier = AutoDisposeAsyncNotifier<Map<String, int>>;
String _$playListNotifierHash() => r'73632ffa35c5845d91fa72364c45361806d5530a';

/// See also [PlayListNotifier].
@ProviderFor(PlayListNotifier)
final playListNotifierProvider = AutoDisposeAsyncNotifierProvider<
    PlayListNotifier, List<PlayDetailResponse>>.internal(
  PlayListNotifier.new,
  name: r'playListNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$playListNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$PlayListNotifier = AutoDisposeAsyncNotifier<List<PlayDetailResponse>>;
String _$itemListNotifierHash() => r'b9a0795fae04ceee491b0883de2dfe04ffc796ac';

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

abstract class _$ItemListNotifier
    extends BuildlessAutoDisposeAsyncNotifier<ItemListQueryResponse> {
  late final String guid;

  FutureOr<ItemListQueryResponse> build(
    String guid,
  );
}

/// See also [ItemListNotifier].
@ProviderFor(ItemListNotifier)
const itemListNotifierProvider = ItemListNotifierFamily();

/// See also [ItemListNotifier].
class ItemListNotifierFamily extends Family<AsyncValue<ItemListQueryResponse>> {
  /// See also [ItemListNotifier].
  const ItemListNotifierFamily();

  /// See also [ItemListNotifier].
  ItemListNotifierProvider call(
    String guid,
  ) {
    return ItemListNotifierProvider(
      guid,
    );
  }

  @override
  ItemListNotifierProvider getProviderOverride(
    covariant ItemListNotifierProvider provider,
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
  String? get name => r'itemListNotifierProvider';
}

/// See also [ItemListNotifier].
class ItemListNotifierProvider extends AutoDisposeAsyncNotifierProviderImpl<
    ItemListNotifier, ItemListQueryResponse> {
  /// See also [ItemListNotifier].
  ItemListNotifierProvider(
    String guid,
  ) : this._internal(
          () => ItemListNotifier()..guid = guid,
          from: itemListNotifierProvider,
          name: r'itemListNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$itemListNotifierHash,
          dependencies: ItemListNotifierFamily._dependencies,
          allTransitiveDependencies:
              ItemListNotifierFamily._allTransitiveDependencies,
          guid: guid,
        );

  ItemListNotifierProvider._internal(
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
  FutureOr<ItemListQueryResponse> runNotifierBuild(
    covariant ItemListNotifier notifier,
  ) {
    return notifier.build(
      guid,
    );
  }

  @override
  Override overrideWith(ItemListNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: ItemListNotifierProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<ItemListNotifier,
      ItemListQueryResponse> createElement() {
    return _ItemListNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ItemListNotifierProvider && other.guid == guid;
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
mixin ItemListNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<ItemListQueryResponse> {
  /// The parameter `guid` of this provider.
  String get guid;
}

class _ItemListNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<ItemListNotifier,
        ItemListQueryResponse> with ItemListNotifierRef {
  _ItemListNotifierProviderElement(super.provider);

  @override
  String get guid => (origin as ItemListNotifierProvider).guid;
}

String _$favoriteNotifierHash() => r'b8537f29afe723a8b47b64ce9ef646cb434bf77f';

/// See also [FavoriteNotifier].
@ProviderFor(FavoriteNotifier)
final favoriteNotifierProvider = AutoDisposeNotifierProvider<FavoriteNotifier,
    FavoriteActionResult?>.internal(
  FavoriteNotifier.new,
  name: r'favoriteNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$favoriteNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$FavoriteNotifier = AutoDisposeNotifier<FavoriteActionResult?>;
String _$watchedNotifierHash() => r'722ff8ff070ff2bb7e1e9d21d8065e83c9489ca4';

/// See also [WatchedNotifier].
@ProviderFor(WatchedNotifier)
final watchedNotifierProvider =
    AutoDisposeNotifierProvider<WatchedNotifier, WatchedActionResult?>.internal(
  WatchedNotifier.new,
  name: r'watchedNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$watchedNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$WatchedNotifier = AutoDisposeNotifier<WatchedActionResult?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
