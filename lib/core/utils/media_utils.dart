import 'package:fluent_ui/fluent_ui.dart';
import 'date_utils.dart';
import 'file_utils.dart';

/// Data class for file information
class FileInfoData {
  final String location;
  final String size;
  final String createdDate;
  final String addedDate;

  const FileInfoData({
    this.location = '',
    this.size = '',
    this.createdDate = '',
    this.addedDate = '',
  });
}

/// Data class for media track information
class MediaTrackInfo {
  final String type;
  final String details;
  final IconData icon;

  const MediaTrackInfo({
    required this.type,
    this.details = '',
    required this.icon,
  });
}

/// Data class for complete media details
class MediaDetails {
  final FileInfoData fileInfo;
  final MediaTrackInfo videoTrack;
  final MediaTrackInfo audioTrack;
  final MediaTrackInfo subtitleTrack;
  final String imdbLink;

  const MediaDetails({
    required this.fileInfo,
    required this.videoTrack,
    required this.audioTrack,
    required this.subtitleTrack,
    required this.imdbLink,
  });
}

/// Media utility functions
class MediaUtils {
  const MediaUtils._();

  /// Generate IMDB link from ID
  static String getImdbLink(String? imdbId) {
    if (imdbId == null || imdbId.isEmpty) return '';
    return 'https://www.imdb.com/title/$imdbId/';
  }

  /// Convert raw media data to MediaDetails
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
            size: FileUtils.formatFileSize(fileInfo.size),
            createdDate: DateTimeUtils.formatTimestamp(fileInfo.updateTime),
            addedDate: DateTimeUtils.formatTimestamp(fileInfo.updateTime),
          )
        : const FileInfoData();

    final videoTrack = MediaTrackInfo(
      type: 'Video',
      details: videoStream != null
          ? '${videoStream.resolutionType} ${videoStream.codecName.toUpperCase()} ${FileUtils.formatBitrate(videoStream.bps)} · ${videoStream.bitDepth} bit'
          : '',
      icon: FluentIcons.video,
    );

    final audioTrack = MediaTrackInfo(
      type: 'Audio',
      details: audioStream != null
          ? '${_getLanguageName(audioStream.language, iso6391Map)} ${audioStream.codecName.toUpperCase()} ${audioStream.channelLayout} · ${audioStream.sampleRate} Hz'
          : '',
      icon: FluentIcons.volume0,
    );

    final subtitleTrack = MediaTrackInfo(
      type: 'Subtitle',
      details: subtitleStream != null
          ? '${_getLanguageName(subtitleStream.language, iso6391Map)} ${subtitleStream.codecName.toUpperCase()}'
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

  static String _getLanguageName(String? langCode, Map<String, String> iso6391Map) {
    if (langCode == null || langCode.isEmpty) return 'Unknown';
    if (langCode == '_no_display_') return 'None';
    return iso6391Map[langCode] ?? langCode;
  }
}

/// Placeholder classes for media stream data
/// These should be replaced with actual model classes
class FileInfo {
  final String path;
  final int size;
  final int updateTime;

  const FileInfo({
    required this.path,
    required this.size,
    required this.updateTime,
  });
}

class VideoStream {
  final String resolutionType;
  final String codecName;
  final int bps;
  final int bitDepth;

  const VideoStream({
    required this.resolutionType,
    required this.codecName,
    required this.bps,
    required this.bitDepth,
  });
}

class AudioStream {
  final String? language;
  final String codecName;
  final String channelLayout;
  final int sampleRate;

  const AudioStream({
    this.language,
    required this.codecName,
    required this.channelLayout,
    required this.sampleRate,
  });
}

class SubtitleStream {
  final String? language;
  final String codecName;

  const SubtitleStream({
    this.language,
    required this.codecName,
  });
}