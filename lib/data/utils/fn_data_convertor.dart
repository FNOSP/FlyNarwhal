import 'package:fluent_ui/fluent_ui.dart';
import '../../data/models/movie_detail_models.dart';
import '../../data/models/tag_models.dart';

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

  static String getLanguageName(String? langCode, List<QueryTagResponse> iso6391, List<QueryTagResponse> iso6392) {
    if (langCode == null || langCode.isEmpty) return '未知';
    if (langCode == '_no_display_') return '无';
    
    // Try iso6391 first
    try {
      final tag1 = iso6391.firstWhere((t) => t.key == langCode);
      if (tag1.value.isNotEmpty) return tag1.value;
    } catch (_) {}

    // Try iso6392
    try {
      final tag2 = iso6392.firstWhere((t) => t.key == langCode);
      if (tag2.value.isNotEmpty) return tag2.value;
    } catch (_) {}

    return langCode;
  }

  static MediaDetails convertToMediaDetails({
    FileInfo? fileInfo,
    VideoStream? videoStream,
    AudioStream? audioStream,
    SubtitleStream? subtitleStream,
    String? imdbId,
    required Map<String, String> iso6391Map,
  }) {
    final fileInfoData = fileInfo != null
        ? FileInfoData(
            location: fileInfo.path,
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
          ? '${getLanguageNameFromMap(audioStream.language, iso6391Map)} ${audioStream.codecName.toUpperCase()} ${audioStream.channelLayout} · ${audioStream.sampleRate} Hz'
          : '',
      icon: FluentIcons.volume0,
    );

    final subtitleTrack = MediaTrackInfo(
      type: '字幕',
      details: subtitleStream != null
          ? '${getLanguageNameFromMap(subtitleStream.language, iso6391Map)} ${subtitleStream.codecName.toUpperCase()}'
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

  static String getLanguageNameFromMap(String? langCode, Map<String, String> iso6391Map) {
    if (langCode == null || langCode.isEmpty) return '未知';
    if (langCode == '_no_display_') return '无';
    return iso6391Map[langCode] ?? langCode;
  }

  static String getImdbLink(String? imdbId) {
    if (imdbId == null || imdbId.isEmpty) return '';
    return 'https://www.imdb.com/title/$imdbId/';
  }
}
