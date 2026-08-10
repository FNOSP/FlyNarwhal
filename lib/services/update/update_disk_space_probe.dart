import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart' as ffi_pkg;

/// Replaceable free-space query used before creating a partial download.
abstract interface class UpdateDiskSpaceProbe {
  Future<int> getAvailableBytes(String directoryPath);
}

/// Queries host disk tools directly without invoking a command shell.
final class IoUpdateDiskSpaceProbe implements UpdateDiskSpaceProbe {
  const IoUpdateDiskSpaceProbe();

  @override
  Future<int> getAvailableBytes(String directoryPath) async {
    final directory = Directory(directoryPath);
    await directory.create(recursive: true);
    if (Platform.isWindows) {
      return _getWindowsAvailableBytes(directory.absolute.path);
    }

    final result = await Process.run('df', <String>['-Pk', directoryPath]);
    if (result.exitCode == 0) {
      final lines = result.stdout.toString().trim().split(RegExp(r'\r?\n'));
      if (lines.length >= 2) {
        final columns = lines.last.trim().split(RegExp(r'\s+'));
        if (columns.length >= 4) {
          final availableKilobytes = int.tryParse(columns[3]);
          if (availableKilobytes != null) {
            return availableKilobytes * 1024;
          }
        }
      }
    }
    throw FileSystemException(
      'Unable to query available disk space.',
      directoryPath,
    );
  }
}

final class FixedUpdateDiskSpaceProbe implements UpdateDiskSpaceProbe {
  const FixedUpdateDiskSpaceProbe(this.availableBytes);

  final int availableBytes;

  @override
  Future<int> getAvailableBytes(String directoryPath) async => availableBytes;
}

int _getWindowsAvailableBytes(String directoryPath) {
  final kernel32 = ffi.DynamicLibrary.open('kernel32.dll');
  final getDiskFreeSpaceEx = kernel32.lookupFunction<
      ffi.Int32 Function(
        ffi.Pointer<ffi.Uint16> directoryName,
        ffi.Pointer<ffi.Uint64> freeBytesAvailableToCaller,
        ffi.Pointer<ffi.Uint64> totalNumberOfBytes,
        ffi.Pointer<ffi.Uint64> totalNumberOfFreeBytes,
      ),
      int Function(
        ffi.Pointer<ffi.Uint16> directoryName,
        ffi.Pointer<ffi.Uint64> freeBytesAvailableToCaller,
        ffi.Pointer<ffi.Uint64> totalNumberOfBytes,
        ffi.Pointer<ffi.Uint64> totalNumberOfFreeBytes,
      )>('GetDiskFreeSpaceExW');

  final nativeDirectoryPath = directoryPath.toNativeUtf16().cast<ffi.Uint16>();
  final freeBytesAvailableToCaller = ffi_pkg.calloc<ffi.Uint64>();
  final totalNumberOfBytes = ffi_pkg.calloc<ffi.Uint64>();
  final totalNumberOfFreeBytes = ffi_pkg.calloc<ffi.Uint64>();
  try {
    final succeeded = getDiskFreeSpaceEx(
      nativeDirectoryPath,
      freeBytesAvailableToCaller,
      totalNumberOfBytes,
      totalNumberOfFreeBytes,
    );
    if (succeeded == 0) {
      throw FileSystemException(
        'Unable to query available disk space through GetDiskFreeSpaceExW.',
        directoryPath,
      );
    }
    return freeBytesAvailableToCaller.value;
  } finally {
    ffi_pkg.calloc.free(nativeDirectoryPath);
    ffi_pkg.calloc.free(freeBytesAvailableToCaller);
    ffi_pkg.calloc.free(totalNumberOfBytes);
    ffi_pkg.calloc.free(totalNumberOfFreeBytes);
  }
}

int? parseFsutilAvailableBytes(String output) {
  final lines = output.split(RegExp(r'\r?\n'));
  final availableToCallerMarkers = <String>[
    'total # of avail free bytes',
    'available free bytes to caller',
    '可供调用方使用的空闲字节',
  ];
  for (final line in lines) {
    final normalizedLine = line.toLowerCase();
    if (!availableToCallerMarkers.any(normalizedLine.contains)) continue;
    final separatorIndex = line.indexOf(':');
    if (separatorIndex < 0) return null;
    final valueText = line.substring(separatorIndex + 1);
    final leadingNumber =
        RegExp(r'^\s*([0-9][0-9,._ ]*)').firstMatch(valueText);
    if (leadingNumber == null) return null;
    final digits = leadingNumber.group(1)!.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : int.tryParse(digits);
  }
  return null;
}

int calculateRequiredDownloadSpace(int expectedSize) {
  const minimumReserve = 256 * 1024 * 1024;
  final percentageReserve = (expectedSize / 10).ceil();
  return expectedSize +
      (percentageReserve > minimumReserve ? percentageReserve : minimumReserve);
}
