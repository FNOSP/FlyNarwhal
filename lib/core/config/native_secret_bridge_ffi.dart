import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

import 'runtime_configuration.dart';

typedef _NativeGetAbiVersion = Uint32 Function();
typedef _DartGetAbiVersion = int Function();
typedef _NativeGetSecret = Int32 Function(
  Uint32 secretId,
  Pointer<Uint8> output,
  Size capacity,
  Pointer<Size> outputLength,
);
typedef _DartGetSecret = int Function(
  int secretId,
  Pointer<Uint8> output,
  int capacity,
  Pointer<Size> outputLength,
);
typedef _NativeZeroize = Void Function(Pointer<Uint8> buffer, Size length);
typedef _DartZeroize = void Function(Pointer<Uint8> buffer, int length);

/// Reads configuration bytes from the private c-shared library.
class FfiSecretBridge implements NativeSecretBridge {
  FfiSecretBridge({DynamicLibrary? library})
      : _library = library ?? DynamicLibrary.open(_resolveLibraryPath()) {
    _getAbiVersion =
        _library.lookupFunction<_NativeGetAbiVersion, _DartGetAbiVersion>(
            'fnob_get_abi_version');
    _getSecret = _library.lookupFunction<_NativeGetSecret, _DartGetSecret>(
      'fnob_get_secret',
    );
    _zeroizeNative =
        _library.lookupFunction<_NativeZeroize, _DartZeroize>('fnob_zeroize');

    if (_getAbiVersion() != _abiVersion) {
      throw StateError('Unsupported fly_narwhal_obfuscator ABI version');
    }
  }

  static const int _abiVersion = 1;
  static const int _success = 0;
  static const int _bufferTooSmall = -1;

  final DynamicLibrary _library;
  late final _DartGetAbiVersion _getAbiVersion;
  late final _DartGetSecret _getSecret;
  late final _DartZeroize _zeroizeNative;

  @override
  Future<Uint8List> readSecret(RuntimeSecret secret) async {
    final outputLengthPointer = calloc<Size>();
    Pointer<Uint8>? nativeBuffer;
    try {
      final requiredLength = _probeSecretLength(secret, outputLengthPointer);
      if (requiredLength == 0) {
        return Uint8List(0);
      }

      nativeBuffer = calloc<Uint8>(requiredLength);
      final returnCode = _getSecret(
        _secretIdFor(secret),
        nativeBuffer,
        requiredLength,
        outputLengthPointer,
      );
      if (returnCode == _bufferTooSmall) {
        throw StateError('Native secret buffer size changed during read');
      }
      if (returnCode != _success ||
          outputLengthPointer.value != requiredLength) {
        throw StateError('Unable to read native configuration value');
      }
      return Uint8List.fromList(nativeBuffer.asTypedList(requiredLength));
    } finally {
      if (nativeBuffer != null) {
        _zeroizeNative(nativeBuffer, outputLengthPointer.value);
        calloc.free(nativeBuffer);
      }
      calloc.free(outputLengthPointer);
    }
  }

  @override
  Future<void> zeroize(Uint8List bytes) async {
    if (bytes.isEmpty) {
      return;
    }

    final nativeBuffer = calloc<Uint8>(bytes.length);
    try {
      nativeBuffer.asTypedList(bytes.length).setAll(0, bytes);
      _zeroizeNative(nativeBuffer, bytes.length);
    } finally {
      calloc.free(nativeBuffer);
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  int _probeSecretLength(RuntimeSecret secret, Pointer<Size> outputLength) {
    final returnCode =
        _getSecret(_secretIdFor(secret), nullptr, 0, outputLength);
    if (returnCode != _success) {
      throw StateError('Unable to probe native configuration value');
    }
    return outputLength.value;
  }

  int _secretIdFor(RuntimeSecret secret) {
    return switch (secret) {
      RuntimeSecret.flyNarwhalApiSecret => 1,
      RuntimeSecret.flyNarwhalSecret => 2,
      RuntimeSecret.reportUrl => 3,
      RuntimeSecret.reportApiSecret => 4,
    };
  }

  static String _resolveLibraryPath() {
    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    final libraryName = switch (Platform.operatingSystem) {
      'windows' => 'fly_narwhal_obfuscator.dll',
      'macos' => 'libfly_narwhal_obfuscator.dylib',
      _ => 'libfly_narwhal_obfuscator.so',
    };
    return path.join(executableDirectory, libraryName);
  }
}
