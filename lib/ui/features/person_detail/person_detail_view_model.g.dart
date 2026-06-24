// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'person_detail_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$personDetailNotifierHash() =>
    r'a1b2c3d4e5f60718293a4b5c6d7e8f9001122334';

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

abstract class _$PersonDetailNotifier
    extends BuildlessAutoDisposeAsyncNotifier<PersonDetailState> {
  late final String guid;

  FutureOr<PersonDetailState> build(
    String guid,
  );
}

/// See also [PersonDetailNotifier].
@ProviderFor(PersonDetailNotifier)
const personDetailNotifierProvider = PersonDetailNotifierFamily();

/// See also [PersonDetailNotifier].
class PersonDetailNotifierFamily extends Family<AsyncValue<PersonDetailState>> {
  /// See also [PersonDetailNotifier].
  const PersonDetailNotifierFamily();

  /// See also [PersonDetailNotifier].
  PersonDetailNotifierProvider call(
    String guid,
  ) {
    return PersonDetailNotifierProvider(
      guid,
    );
  }

  @override
  PersonDetailNotifierProvider getProviderOverride(
    covariant PersonDetailNotifierProvider provider,
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
  String? get name => r'personDetailNotifierProvider';
}

/// See also [PersonDetailNotifier].
class PersonDetailNotifierProvider extends AutoDisposeAsyncNotifierProviderImpl<
    PersonDetailNotifier, PersonDetailState> {
  /// See also [PersonDetailNotifier].
  PersonDetailNotifierProvider(
    String guid,
  ) : this._internal(
          () => PersonDetailNotifier()..guid = guid,
          from: personDetailNotifierProvider,
          name: r'personDetailNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$personDetailNotifierHash,
          dependencies: PersonDetailNotifierFamily._dependencies,
          allTransitiveDependencies:
              PersonDetailNotifierFamily._allTransitiveDependencies,
          guid: guid,
        );

  PersonDetailNotifierProvider._internal(
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
  FutureOr<PersonDetailState> runNotifierBuild(
    covariant PersonDetailNotifier notifier,
  ) {
    return notifier.build(
      guid,
    );
  }

  @override
  Override overrideWith(PersonDetailNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: PersonDetailNotifierProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<PersonDetailNotifier,
      PersonDetailState> createElement() {
    return _PersonDetailNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PersonDetailNotifierProvider && other.guid == guid;
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
mixin PersonDetailNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<PersonDetailState> {
  /// The parameter `guid` of this provider.
  String get guid;
}

class _PersonDetailNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<PersonDetailNotifier,
        PersonDetailState> with PersonDetailNotifierRef {
  _PersonDetailNotifierProviderElement(super.provider);

  @override
  String get guid => (origin as PersonDetailNotifierProvider).guid;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
