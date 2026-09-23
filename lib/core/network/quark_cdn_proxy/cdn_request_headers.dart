/// Flattens metadata header values using HTTP syntax instead of List.toString.
/// Header names are normalized to avoid case-variant duplicate credentials.
Map<String, String> normalizeCdnRequestHeaders(Map<String, dynamic> headers) {
  final result = <String, String>{};
  for (final entry in headers.entries) {
    final name = entry.key.trim().toLowerCase();
    if (name.isEmpty || _isExcludedHeader(name) || entry.value == null) {
      continue;
    }
    final value = entry.value;
    final values = value is Iterable ? value : <dynamic>[value];
    final separator = name == 'cookie' ? '; ' : ', ';
    final text = values
        .where((value) => value != null)
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .join(separator);
    if (text.isNotEmpty) {
      result.update(name, (previous) => '$previous$separator$text',
          ifAbsent: () => text);
    }
  }
  return result;
}

bool _isExcludedHeader(String name) {
  return const {
        'host',
        'content-length',
        'connection',
        'keep-alive',
        'proxy-authenticate',
        'proxy-authorization',
        'te',
        'trailer',
        'transfer-encoding',
        'upgrade',
        'range',
        'accept-encoding',
        'authorization',
        'authx',
        'signx',
        'x-wp-header',
      }.contains(name) ||
      name.startsWith('x-trim-') ||
      name.startsWith('x-fn-') ||
      name.startsWith('x-nas-');
}
