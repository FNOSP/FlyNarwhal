import 'dart:io';
import 'dart:typed_data';

const _configurationKeys = <String>[
  'FLY_NARWHAL_API_SECRET',
  'FLY_NARWHAL_SECRET',
  'REPORT_URL',
  'REPORT_API_SECRET',
];

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln(
        'Usage: dart run scripts/release/verify_plaintext.dart <directory>');
    exitCode = 64;
    return;
  }

  final targetDirectory = Directory(arguments.single);
  if (!targetDirectory.existsSync()) {
    stderr.writeln('Target directory does not exist');
    exitCode = 66;
    return;
  }

  final prohibitedValues = _configurationKeys
      .map((key) => Platform.environment[key] ?? '')
      .where((value) => value.isNotEmpty)
      .map(_utf8Bytes)
      .toList(growable: false);
  if (prohibitedValues.isEmpty) {
    stderr.writeln('No configured values were supplied for plaintext scanning');
    exitCode = 64;
    return;
  }

  final matches = <String>[];
  await for (final entity in targetDirectory.list(recursive: true)) {
    if (entity is! File) {
      continue;
    }
    final content = await entity.readAsBytes();
    if (prohibitedValues.any((value) => _containsBytes(content, value))) {
      matches.add(entity.path);
    }
  }

  if (matches.isNotEmpty) {
    stderr.writeln('Plaintext configuration detected in release output');
    for (final match in matches) {
      stderr.writeln(match);
    }
    exitCode = 1;
  }
}

Uint8List _utf8Bytes(String value) {
  return Uint8List.fromList(value.codeUnits);
}

bool _containsBytes(Uint8List haystack, Uint8List needle) {
  if (needle.length > haystack.length) {
    return false;
  }
  for (var startingIndex = 0;
      startingIndex <= haystack.length - needle.length;
      startingIndex++) {
    var matches = true;
    for (var needleIndex = 0; needleIndex < needle.length; needleIndex++) {
      if (haystack[startingIndex + needleIndex] != needle[needleIndex]) {
        matches = false;
        break;
      }
    }
    if (matches) {
      return true;
    }
  }
  return false;
}
