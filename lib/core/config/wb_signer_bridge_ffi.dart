import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

/// Signs the canonical FNWB2 message with the white-box CMAC library.
///
/// The V2 secret exists only inside randomized AES white-box tables compiled
/// into the private c-shared library; it never enters Dart memory. Release
/// bundles ship the library next to the executable; development builds have
/// no library and therefore produce no Fnwb header.
abstract interface class WbSigner {
  /// Returns the 32-character lowercase-hex AES-128-CMAC of [message].
  ///
  /// Throws when the native signer fails — a release request must never be
  /// sent without its build proof.
  String sign(String message);
}

typedef _NativeGetAbiVersion = Uint32 Function();
typedef _DartGetAbiVersion = int Function();
typedef _NativeSign = Int32 Function(
  Pointer<Uint8> message,
  Size messageLength,
  Pointer<Uint8> output,
  Size capacity,
  Pointer<Size> outputLength,
);
typedef _DartSign = int Function(
  Pointer<Uint8> message,
  int messageLength,
  Pointer<Uint8> output,
  int capacity,
  Pointer<Size> outputLength,
);
typedef _NativeZeroize = Void Function(Pointer<Uint8> buffer, Size length);
typedef _DartZeroize = void Function(Pointer<Uint8> buffer, int length);
typedef _NativeLastErrorCode = Pointer<Utf8> Function();
typedef _DartLastErrorCode = Pointer<Utf8> Function();

/// FFI binding to the private fly-narwhal-whitebox c-shared signer library.
class FfiWbSigner implements WbSigner {
  FfiWbSigner({DynamicLibrary? library})
      : _library = library ?? DynamicLibrary.open(_resolveLibraryPath()) {
    _getAbiVersion =
        _library.lookupFunction<_NativeGetAbiVersion, _DartGetAbiVersion>(
            'fnwb_get_abi_version');
    _sign = _library.lookupFunction<_NativeSign, _DartSign>('fnwb_sign');
    _zeroizeNative =
        _library.lookupFunction<_NativeZeroize, _DartZeroize>('fnwb_zeroize');
    _lastErrorCode =
        _library.lookupFunction<_NativeLastErrorCode, _DartLastErrorCode>(
            'fnwb_last_error_code');

    if (_getAbiVersion() != _abiVersion) {
      throw StateError('Unsupported fly_narwhal_wb ABI version');
    }
  }

  static const int _abiVersion = 1;
  static const int _success = 0;
  static const int _bufferTooSmall = -1;

  /// fnwb_sign writes a fixed-length 32-byte lowercase-hex CMAC.
  static const int _signatureLength = 32;

  final DynamicLibrary _library;
  late final _DartGetAbiVersion _getAbiVersion;
  late final _DartSign _sign;
  late final _DartZeroize _zeroizeNative;
  late final _DartLastErrorCode _lastErrorCode;

  @override
  String sign(String message) {
    final messageBytes = utf8.encode(message);
    final messagePointer = calloc<Uint8>(messageBytes.length);
    final outputLengthPointer = calloc<Size>();
    Pointer<Uint8>? outputPointer;
    try {
      messagePointer.asTypedList(messageBytes.length).setAll(0, messageBytes);

      // Phase one: probe the required output length with a null buffer.
      final probeCode = _sign(
        messagePointer,
        messageBytes.length,
        nullptr,
        0,
        outputLengthPointer,
      );
      if (probeCode != _success) {
        throw _signingError(probeCode);
      }
      final requiredLength = outputLengthPointer.value;
      if (requiredLength != _signatureLength) {
        throw StateError('Unexpected fly_narwhal_wb signature length');
      }

      // Phase two: sign into a zeroized-after-use native buffer.
      outputPointer = calloc<Uint8>(requiredLength);
      final returnCode = _sign(
        messagePointer,
        messageBytes.length,
        outputPointer,
        requiredLength,
        outputLengthPointer,
      );
      if (returnCode == _bufferTooSmall) {
        throw StateError('Native white-box buffer size changed during signing');
      }
      if (returnCode != _success ||
          outputLengthPointer.value != requiredLength) {
        throw _signingError(returnCode);
      }
      return utf8.decode(
        outputPointer.asTypedList(requiredLength),
        allowMalformed: false,
      );
    } finally {
      if (outputPointer != null) {
        _zeroizeNative(outputPointer, outputLengthPointer.value);
        calloc.free(outputPointer);
      }
      _zeroizeNative(messagePointer, messageBytes.length);
      calloc.free(messagePointer);
      calloc.free(outputLengthPointer);
    }
  }

  StateError _signingError(int returnCode) {
    final codePointer = _lastErrorCode();
    final code =
        codePointer == nullptr ? 'unknown' : codePointer.toDartString();
    return StateError('White-box signing failed ($returnCode): $code');
  }

  static String _resolveLibraryPath() {
    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    final libraryName = switch (Platform.operatingSystem) {
      'windows' => 'fly_narwhal_wb.dll',
      'macos' => 'libfly_narwhal_wb.dylib',
      _ => 'libfly_narwhal_wb.so',
    };
    return path.join(executableDirectory, libraryName);
  }
}