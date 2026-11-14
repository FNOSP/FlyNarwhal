/// One failure of a scan run, mirroring `ThumbnailScanFailureResponse`
/// (server >= 2.1.3): a queued file whose generation failed, or a configured
/// directory the run could not open at all.
library;

final class ThumbnailScanFailure {
  const ThumbnailScanFailure({
    required this.filePath,
    required this.rawError,
    required this.kind,
  });

  static const String kindFile = 'FILE';
  static const String kindDirectory = 'DIRECTORY';

  /// Normalized media path for [kindFile], the configured directory path for
  /// [kindDirectory].
  final String filePath;

  /// The server's own wording; humanized on the client, same convention as
  /// the config save errors.
  final String rawError;

  /// FILE / DIRECTORY.
  final String kind;

  bool get isDirectory => kind == kindDirectory;

  static ThumbnailScanFailure fromJson(Map<String, dynamic> json) {
    return ThumbnailScanFailure(
      filePath: (json['filePath'] as String?) ?? '',
      rawError: (json['error'] as String?) ?? '',
      kind: (json['kind'] as String?) ?? kindFile,
    );
  }
}