import 'dart:convert';
import 'dart:io';

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
      final absolutePath = directory.absolute.path;
      final volume = absolutePath.length >= 2 && absolutePath[1] == ':'
          ? absolutePath.substring(0, 2)
          : absolutePath;
      final result = await Process.run(
        'fsutil',
        <String>['volume', 'diskfree', volume],
        stdoutEncoding: utf8,
      );
      if (result.exitCode == 0) {
        final availableBytes = parseFsutilAvailableBytes(
          result.stdout.toString(),
        );
        if (availableBytes != null) return availableBytes;
      }
      throw FileSystemException(
        'Unable to query available disk space.',
        directoryPath,
      );
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
