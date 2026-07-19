/// Sanitizes sensitive fields before logs are persisted to disk.
class TalkerLogSanitizer {
  const TalkerLogSanitizer();

  String sanitize(String message) {
    var masked = message;

    // Mask common JSON and key-value credentials.
    masked = _replaceWithGroups(
      masked,
      RegExp(r'("password"\s*:\s*")[^"]+(")', caseSensitive: false),
      r'$1******$2',
    );
    masked = _replaceWithGroups(
      masked,
      RegExp(r'(password\s*[=:]\s*)[^,\s)]+', caseSensitive: false),
      r'$1******',
    );
    masked = _replaceWithGroups(
      masked,
      RegExp(r'("username"\s*:\s*")[^"]+(")', caseSensitive: false),
      r'$1******$2',
    );
    masked = _replaceWithGroups(
      masked,
      RegExp(r'(username\s*[=:]\s*)[^,\s)]+', caseSensitive: false),
      r'$1******',
    );
    masked = _replaceWithGroups(
      masked,
      RegExp(r'("source_name"\s*:\s*")[^"]+(")', caseSensitive: false),
      r'$1******$2',
    );
    masked = _replaceWithGroups(
      masked,
      RegExp(r'(source_name\s*[=:]\s*)[^,\s)]+', caseSensitive: false),
      r'$1******',
    );
    masked = _replaceWithGroups(
      masked,
      RegExp(r'("token"\s*:\s*")[^"]+(")', caseSensitive: false),
      r'$1******$2',
    );
    masked = _replaceWithGroups(
      masked,
      RegExp(r'(token\s*[=:]\s*)[^,\s)"]+', caseSensitive: false),
      r'$1******',
    );
    masked = _replaceWithGroups(
      masked,
      RegExp(r'(cookie\s*[=:]\s*)[^;\s,)]+', caseSensitive: false),
      r'$1******',
    );

    // Mask sensitive host fragments and local user folders.
    masked = _replaceWithGroups(
      masked,
      RegExp(r'(https?://)[^./]+\.5ddd\.com', caseSensitive: false),
      r'$1***.5ddd.com',
    );
    masked = _replaceWithGroups(
      masked,
      RegExp(r'(https?://)[^./]+\.fnos\.net', caseSensitive: false),
      r'$1***.fnos.net',
    );
    masked = _replaceWithGroups(
      masked,
      RegExp(r'(https?://)(?![^/\s]+\.(?:5ddd\.com|fnos\.net))[^/\s]+',
          caseSensitive: false),
      r'$1***',
    );
    masked = _replaceWithGroups(
      masked,
      RegExp(r'([a-z]:\\Users\\|/Users/|/home/)([^\\/\s]+)',
          caseSensitive: false),
      r'$1***',
    );

    return masked;
  }

  // Expand capture groups explicitly because replaceAll treats replacements literally.
  String _replaceWithGroups(
    String input,
    RegExp pattern,
    String replacement,
  ) {
    return input.replaceAllMapped(pattern, (match) {
      var resolved = replacement;
      for (var i = 1; i <= match.groupCount; i++) {
        resolved = resolved.replaceAll('\$$i', match.group(i) ?? '');
      }
      return resolved;
    });
  }
}
