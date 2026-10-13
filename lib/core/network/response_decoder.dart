import 'dart:convert';
import 'dart:typed_data';

/// Shared response decoder for byte-based network reads and readable logging.
class ResponseDecoder {
  const ResponseDecoder._();

  static dynamic normalizeResponseData(dynamic data) {
    final bytes = extractBytes(data);
    if (bytes == null) {
      return data;
    }

    final text = decodeBytes(bytes);
    if (text.trim().isEmpty) {
      return '';
    }
    return maybeDecodeJson(text);
  }

  static List<int>? extractBytes(dynamic data) {
    if (data is Uint8List) {
      return data;
    }
    if (data is List<int>) {
      return data;
    }
    if (data is List) {
      final values = <int>[];
      for (final item in data) {
        if (item is! int) {
          return null;
        }
        values.add(item);
      }
      return values;
    }
    return null;
  }

  static String decodeBytes(List<int> bytes) {
    try {
      return stripUtf8Bom(utf8.decode(bytes));
    } on FormatException {
      return stripUtf8Bom(utf8.decode(bytes, allowMalformed: true));
    }
  }

  static String stripUtf8Bom(String value) {
    if (value.isNotEmpty && value.codeUnitAt(0) == 0xFEFF) {
      return value.substring(1);
    }
    return value;
  }

  static dynamic maybeDecodeJson(String text) {
    final candidate = text.trim();
    if (candidate.isEmpty) {
      return '';
    }
    try {
      return jsonDecode(candidate);
    } on FormatException {
      return text;
    }
  }

  static String previewBytes(List<int> bytes, {int limit = 16}) {
    return bytes
        .take(limit)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join(' ');
  }

  static String previewText(String value, {int? limit}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (limit == null || normalized.length <= limit) {
      return normalized;
    }
    return '${normalized.substring(0, limit)}...';
  }

  /// Identifies the payload when it is a known image container, so a sprite
  /// sheet reads as `jpeg` rather than an opaque byte count.
  static String? _binaryFormat(List<int> bytes) {
    if (_startsWith(bytes, const [0xFF, 0xD8, 0xFF])) {
      return 'jpeg';
    }
    if (_startsWith(bytes, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return 'png';
    }
    if (_startsWith(bytes, const [0x47, 0x49, 0x46, 0x38])) {
      return 'gif';
    }
    if (_startsWith(bytes, const [0x52, 0x49, 0x46, 0x46])) {
      return 'riff';
    }
    return null;
  }

  static bool _startsWith(List<int> bytes, List<int> prefix) {
    if (bytes.length < prefix.length) {
      return false;
    }
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) {
        return false;
      }
    }
    return true;
  }

  static String formatForLogging(dynamic data, {int? limit}) {
    final bytes = extractBytes(data);
    if (bytes != null) {
      // Binary payloads (the trickplay sprite JPEG) reach the log as a byte
      // list. Check the container signature first: image headers are bytes
      // below 0x80, so they decode as valid UTF-8 even though the payload as a
      // whole is binary, and a text preview of them would drag the rest of the
      // frame into the log.
      final format = _binaryFormat(bytes);
      if (format != null) {
        return 'binary $format, ${bytes.length} bytes, head ${previewBytes(bytes)}';
      }
      final text = decodeBytes(bytes);
      if (text.trim().isNotEmpty) {
        return previewText(text, limit: limit);
      }
      return 'binary ${bytes.length} bytes, head ${previewBytes(bytes)}';
    }

    if (data is String) {
      return previewText(data, limit: limit);
    }

    if (data is Map || data is List) {
      try {
        return previewText(jsonEncode(data), limit: limit);
      } catch (_) {
        return previewText(data.toString(), limit: limit);
      }
    }

    return previewText(data.toString(), limit: limit);
  }
}
