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

  static String previewText(String value, {int limit = 1000}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= limit) {
      return normalized;
    }
    return '${normalized.substring(0, limit)}...';
  }

  static String formatForLogging(dynamic data, {int limit = 1000}) {
    final bytes = extractBytes(data);
    if (bytes != null) {
      final text = decodeBytes(bytes);
      if (text.trim().isNotEmpty) {
        return previewText(text, limit: limit);
      }
      return 'bytes(${bytes.length}): ${previewBytes(bytes)}';
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
