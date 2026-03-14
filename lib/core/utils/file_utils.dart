/// File utility functions
class FileUtils {
  const FileUtils._();

  /// Format file size to readable string
  /// Example: 1536 -> "1.50 KB"
  static String formatFileSize(int size) {
    if (size <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    int unitIndex = 0;
    double fileSize = size.toDouble();
    while (fileSize >= 1024 && unitIndex < units.length - 1) {
      fileSize /= 1024;
      unitIndex++;
    }
    return '${fileSize.toStringAsFixed(2)} ${units[unitIndex]}';
  }

  /// Format bitrate to readable string
  /// Example: 1536000 -> "1.54 Mbps"
  static String formatBitrate(int bps) {
    if (bps <= 0) return '0 bps';
    const units = ['bps', 'Kbps', 'Mbps', 'Gbps'];
    int unitIndex = 0;
    double bitrate = bps.toDouble();
    while (bitrate >= 1000 && unitIndex < units.length - 1) {
      bitrate /= 1000;
      unitIndex++;
    }
    return '${bitrate.toStringAsFixed(2)} ${units[unitIndex]}';
  }

  /// Get file extension from path
  static String getExtension(String path) {
    if (path.isEmpty) return '';
    final lastDot = path.lastIndexOf('.');
    if (lastDot == -1 || lastDot == path.length - 1) return '';
    return path.substring(lastDot + 1).toLowerCase();
  }

  /// Get file name from path
  static String getFileName(String path) {
    if (path.isEmpty) return '';
    final lastSlash = path.lastIndexOf('/');
    final lastBackslash = path.lastIndexOf('\\');
    final lastIndex = lastSlash > lastBackslash ? lastSlash : lastBackslash;
    if (lastIndex == -1) return path;
    return path.substring(lastIndex + 1);
  }

  /// Get file name without extension
  static String getFileNameWithoutExtension(String path) {
    final fileName = getFileName(path);
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot == -1) return fileName;
    return fileName.substring(0, lastDot);
  }

  /// Check if path is a video file
  static bool isVideoFile(String path) {
    const videoExtensions = [
      'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm',
      'm4v', 'mpeg', 'mpg', '3gp', 'ts', 'mts', 'm2ts',
    ];
    final ext = getExtension(path);
    return videoExtensions.contains(ext);
  }

  /// Check if path is an audio file
  static bool isAudioFile(String path) {
    const audioExtensions = [
      'mp3', 'wav', 'flac', 'aac', 'ogg', 'wma', 'm4a',
      'ape', 'alac', 'opus', 'aiff',
    ];
    final ext = getExtension(path);
    return audioExtensions.contains(ext);
  }

  /// Check if path is an image file
  static bool isImageFile(String path) {
    const imageExtensions = [
      'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg',
      'ico', 'tiff', 'tif', 'heic', 'heif',
    ];
    final ext = getExtension(path);
    return imageExtensions.contains(ext);
  }

  /// Check if path is a subtitle file
  static bool isSubtitleFile(String path) {
    const subtitleExtensions = ['srt', 'ass', 'ssa', 'vtt', 'sub', 'idx'];
    final ext = getExtension(path);
    return subtitleExtensions.contains(ext);
  }

  /// Parse volume path to Chinese name
  /// Example: "/vol1/Movies" -> "存储空间 1"
  static String getVolumeCNName(String path, {bool hasSpace = true}) {
    if (path.isEmpty) return '';
    final regex = RegExp(r'^/vol(\d+)');
    final match = regex.firstMatch(path);
    if (match != null) {
      final volumeNumber = match.group(1);
      return '存储空间${hasSpace ? ' ' : ''}$volumeNumber';
    }
    return path;
  }
}