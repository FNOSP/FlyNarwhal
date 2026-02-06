// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_library_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$mediaLibraryNotifierHash() =>
    r'f4883e5ffd576dd898fb102639b9015f0fe1e62e';

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

abstract class _$MediaLibraryNotifier
    extends BuildlessAutoDisposeAsyncNotifier<ItemListQueryResponse> {
  late final String guid;

  FutureOr<ItemListQueryResponse> build(
    String guid,
  );
}

/// See also [MediaLibraryNotifier].
@ProviderFor(MediaLibraryNotifier)
const mediaLibraryNotifierProvider = MediaLibraryNotifierFamily();

/// See also [MediaLibraryNotifier].
class MediaLibraryNotifierFamily
    extends Family<AsyncValue<ItemListQueryResponse>> {
  /// See also [MediaLibraryNotifier].
  const MediaLibraryNotifierFamily();

  /// See also [MediaLibraryNotifier].
  MediaLibraryNotifierProvider call(
    String guid,
  ) {
    return MediaLibraryNotifierProvider(
      guid,
    );
  }

  @override
  MediaLibraryNotifierProvider getProviderOverride(
    covariant MediaLibraryNotifierProvider provider,
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
  String? get name => r'mediaLibraryNotifierProvider';
}

/// See also [MediaLibraryNotifier].
class MediaLibraryNotifierProvider extends AutoDisposeAsyncNotifierProviderImpl<
    MediaLibraryNotifier, ItemListQueryResponse> {
  /// See also [MediaLibraryNotifier].
  MediaLibraryNotifierProvider(
    String guid,
  ) : this._internal(
          () => MediaLibraryNotifier()..guid = guid,
          from: mediaLibraryNotifierProvider,
          name: r'mediaLibraryNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$mediaLibraryNotifierHash,
          dependencies: MediaLibraryNotifierFamily._dependencies,
          allTransitiveDependencies:
              MediaLibraryNotifierFamily._allTransitiveDependencies,
          guid: guid,
        );

  MediaLibraryNotifierProvider._internal(
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
    covariant MediaLibraryNotifier notifier,
  ) {
    return notifier.build(
      guid,
    );
  }

  @override
  Override overrideWith(MediaLibraryNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: MediaLibraryNotifierProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<MediaLibraryNotifier,
      ItemListQueryResponse> createElement() {
    return _MediaLibraryNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MediaLibraryNotifierProvider && other.guid == guid;
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
mixin MediaLibraryNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<ItemListQueryResponse> {
  /// The parameter `guid` of this provider.
  String get guid;
}

class _MediaLibraryNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<MediaLibraryNotifier,
        ItemListQueryResponse> with MediaLibraryNotifierRef {
  _MediaLibraryNotifierProviderElement(super.provider);

  @override
  String get guid => (origin as MediaLibraryNotifierProvider).guid;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
