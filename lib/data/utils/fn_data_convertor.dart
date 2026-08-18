import 'package:fluent_ui/fluent_ui.dart';
import '../../data/models/file_models.dart';
import '../../data/models/movie_detail_models.dart';

class FileInfoData {
  final String location;
  final String size;
  final String createdDate;
  final String addedDate;

  FileInfoData({
    this.location = '',
    this.size = '',
    this.createdDate = '',
    this.addedDate = '',
  });
}

class MediaTrackInfo {
  final String type;
  final String details;
  final IconData icon;

  MediaTrackInfo({
    required this.type,
    this.details = '',
    required this.icon,
  });
}

class MediaDetails {
  final FileInfoData fileInfo;
  final MediaTrackInfo videoTrack;
  final MediaTrackInfo audioTrack;
  final MediaTrackInfo subtitleTrack;
  final String imdbLink;

  MediaDetails({
    required this.fileInfo,
    required this.videoTrack,
    required this.audioTrack,
    required this.subtitleTrack,
    required this.imdbLink,
  });
}

class FnDataConvertor {
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

  static String formatTimestamp(int timestamp) {
    if (timestamp == 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  static String formatSecondsToCNDateTime(int seconds) {
    if (seconds <= 0) return '0 分钟';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0 && minutes > 0) {
      return '$hours 小时 $minutes 分钟';
    } else if (hours > 0) {
      return '$hours 小时';
    } else if (minutes > 0 && remainingSeconds > 0) {
      return '$minutes 分钟 $remainingSeconds 秒';
    } else {
      return '$minutes 分钟';
    }
  }

  static String getLanguageName(
    String? langCode,
    Map<String, String> iso6391,
    Map<String, String> iso6392,
  ) {
    final language = langCode?.trim();
    if (language == null || language == '_no_display_') return '无';
    if ({'', 'und', 'zxx', 'qaa-qtz', 'zz-unknow'}.contains(language)) {
      return '未知';
    }

    if (language.length == 2) {
      final iso6391Value = iso6391[language];
      return iso6391Value?.isNotEmpty == true ? iso6391Value! : language;
    }

    if (language.length == 3) {
      final iso6392Value = iso6392[language];
      return iso6392Value?.isNotEmpty == true ? iso6392Value! : language;
    }

    return language;
  }

  /// Format a raw server file path to a user-friendly location string,
  static String formatFileLocation(
    String path, {
    List<AuthDir>? authDirs,
  }) {
    if (path.isEmpty) return '';

    final normalized = path.startsWith('/') ? path.substring(1) : path;
    final segments = normalized.split('/');
    if (segments.length < 2) return path;

    final volMatch = RegExp(r'^vol(\d+)$').firstMatch(segments[0]);
    if (volMatch == null) return path;
    final volumeLabel = '存储空间 ${volMatch.group(1)}';

    final uid = segments[1];

    String? username;
    for (final dir in authDirs ?? const <AuthDir>[]) {
      final dirPath = dir.path.trim();
      if (dirPath.isEmpty) continue;
      final normalizedDir =
          dirPath.startsWith('/') ? dirPath.substring(1) : dirPath;
      // findDirItem equivalent: the authorized dir path is a prefix of the
      // file path (segments match up to the dir's depth).
      final dirSegments = normalizedDir.split('/');
      if (dirSegments.length >= 2 &&
          dirSegments[0] == segments[0] &&
          dirSegments[1] == uid &&
          _segmentsPrefixOf(dirSegments, segments)) {
        username = dir.uname.trim();
        if (username.isNotEmpty) break;
      }
    }

    final userLabel = username != null && username.isNotEmpty
        ? '$username 的文件'
        : '用户 $uid';

    final rest = segments.length > 2
        ? segments.sublist(2).join('/')
        : '';

    if (rest.isEmpty) {
      return '$volumeLabel/$userLabel';
    }
    return '$volumeLabel/$userLabel/$rest';
  }

  static bool _segmentsPrefixOf(List<String> prefix, List<String> full) {
    if (prefix.length > full.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (prefix[i] != full[i]) return false;
    }
    return true;
  }

  static MediaDetails convertToMediaDetails({
    FileInfo? fileInfo,
    VideoStream? videoStream,
    AudioStream? audioStream,
    SubtitleStream? subtitleStream,
    String? imdbId,
    List<AuthDir>? authDirs,
    required Map<String, String> iso6391Map,
    required Map<String, String> iso6392Map,
  }) {
    final fileInfoData = fileInfo != null
        ? FileInfoData(
            location: formatFileLocation(fileInfo.path, authDirs: authDirs),
            size: formatFileSize(fileInfo.size),
            createdDate: formatTimestamp(fileInfo.updateTime),
            addedDate: formatTimestamp(fileInfo.updateTime),
          )
        : FileInfoData();

    final videoTrack = MediaTrackInfo(
      type: '视频',
      details: videoStream != null
          ? '${videoStream.resolutionType} ${videoStream.codecName.toUpperCase()} ${formatBitrate(videoStream.bps)} · ${videoStream.bitDepth} bit'
          : '',
      icon: FluentIcons.video,
    );

    final audioTrack = MediaTrackInfo(
      type: '音频',
      details: audioStream != null
          ? '${getLanguageName(audioStream.language, iso6391Map, iso6392Map)} ${audioStream.codecName.toUpperCase()} ${audioStream.channelLayout} · ${audioStream.sampleRate} Hz'
          : '',
      icon: FluentIcons.volume0,
    );

    final subtitleTrack = MediaTrackInfo(
      type: '字幕',
      details: subtitleStream != null
          ? '${getLanguageName(subtitleStream.language, iso6391Map, iso6392Map)} ${subtitleStream.codecName.toUpperCase()}'
          : '',
      icon: FluentIcons.reading_mode,
    );

    return MediaDetails(
      fileInfo: fileInfoData,
      videoTrack: videoTrack,
      audioTrack: audioTrack,
      subtitleTrack: subtitleTrack,
      imdbLink: getImdbLink(imdbId),
    );
  }

  static String getImdbLink(String? imdbId) {
    if (imdbId == null || imdbId.isEmpty) return '';
    return 'https://www.imdb.com/title/$imdbId/';
  }

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

  /// Sidebar label for an authorized directory, matching the web player's file
  /// picker classification by `storageType`:
  ///   0 -> 外接存储, 2 -> 远程挂载, 3 -> 存储空间 N, else -> volume name.
  /// A path-regex alone is wrong here: a remote mount such as `/vol02/...`
  /// would otherwise be mislabelled "存储空间 02".
  static String getAuthDirSidebarLabel(String path, int storageType) {
    switch (storageType) {
      case 0:
        return '外接存储';
      case 2:
        return '远程挂载';
      case 3:
        return getVolumeCNName(path);
      default:
        final name = getVolumeCNName(path);
        return name.isEmpty ? path : name;
    }
  }

  /// Cloud storage labels aligned with the web player enum mapping.
  static const Map<int, String> _cloudStorageTypeLabels = {
    1: '百度网盘',
    2: '阿里云盘',
    3: '115 生活',
    4: '夸克网盘',
    5: '123 云盘',
    6: 'Microsoft OneDrive',
    7: 'Google Drive',
    8: 'Dropbox',
    9: 'Microsoft OneDrive for Business',
    10: 'Microsoft OneDrive',
  };

  static bool isValidCloudStorageType(int? cloudStorageType) {
    return cloudStorageType != null &&
        _cloudStorageTypeLabels.containsKey(cloudStorageType);
  }

  static String getCloudStorageTypeLabel(int? cloudStorageType) {
    if (!isValidCloudStorageType(cloudStorageType)) return '';
    return _cloudStorageTypeLabels[cloudStorageType] ?? '';
  }

  /// Build the display name for an authorized directory root node.
  /// For cloud storage mounts, match the web player as:
  ///   <cloud storage label> - <comment>
  /// For other remote mounts, fall back to:
  ///   <comment> - <username>@<address>
  static String getAuthDirRootLabel(AuthDir dir) {
    if (dir.storageType != 2) {
      final segments =
          dir.path.split('/').where((segment) => segment.isNotEmpty);
      return segments.isEmpty ? dir.path : segments.last;
    }

    if (isValidCloudStorageType(dir.cloudStorageType)) {
      final cloudLabel = getCloudStorageTypeLabel(dir.cloudStorageType);
      final displayName = dir.comment.trim();
      if (cloudLabel.isNotEmpty && displayName.isNotEmpty) {
        return '$cloudLabel - $displayName';
      }
      if (cloudLabel.isNotEmpty) return cloudLabel;
      if (displayName.isNotEmpty) return displayName;
    }

    final comment = dir.comment.trim();
    final username = dir.username.trim();
    final address = dir.address.trim();
    final account =
        [username, address].where((segment) => segment.isNotEmpty).join('@');
    final fallback =
        [comment, account].where((segment) => segment.isNotEmpty).join(' - ');

    if (fallback.isNotEmpty) return fallback;

    final segments = dir.path.split('/').where((segment) => segment.isNotEmpty);
    return segments.isEmpty ? dir.path : segments.last;
  }
}
