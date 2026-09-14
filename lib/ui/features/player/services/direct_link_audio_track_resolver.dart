import 'package:fvp/mdk.dart' as mdk;

import '../../../../core/utils/log/app_talker.dart';
import '../../../../data/models/movie_detail_models.dart';

/// Matches a server-side audio stream onto an embedded audio track of the
/// currently playing media.
///
/// mdk exposes no track ids, only indexes into `MediaInfo.audio`, so the
/// resolved result is the stream index to hand to `setActiveTracks`.
class DirectLinkAudioTrackResolver {
  const DirectLinkAudioTrackResolver();

  List<mdk.AudioStreamInfo> embeddedTracksOf(
    List<mdk.AudioStreamInfo> audioTracks,
  ) {
    return audioTracks.where(_isEmbeddedTrack).toList(growable: false);
  }

  mdk.AudioStreamInfo? resolve({
    required List<AudioStream> audioStreams,
    required List<mdk.AudioStreamInfo> audioTracks,
    required AudioStream targetAudio,
  }) {
    final embeddedTracks = embeddedTracksOf(audioTracks);
    if (embeddedTracks.isEmpty) {
      AppTalker.info(
        'Player',
        'direct-link audio resolve skipped: no embedded audio tracks yet',
      );
      return null;
    }

    final titleLanguageCodecMatches = embeddedTracks
        .where((track) => _matchesTitleLanguageAndCodec(track, targetAudio))
        .toList(growable: false);
    if (titleLanguageCodecMatches.length == 1) {
      return titleLanguageCodecMatches.single;
    }

    final titleLanguageMatches = embeddedTracks
        .where((track) => _matchesTitleAndLanguage(track, targetAudio))
        .toList(growable: false);
    if (titleLanguageMatches.length == 1) {
      return titleLanguageMatches.single;
    }

    final languageChannelMatches = embeddedTracks
        .where((track) => _matchesLanguageAndChannelCount(track, targetAudio))
        .toList(growable: false);
    if (languageChannelMatches.length == 1) {
      return languageChannelMatches.single;
    }

    final sortedAudioStreams = List<AudioStream>.of(audioStreams)
      ..sort((left, right) => left.index.compareTo(right.index));
    final targetOrdinal = sortedAudioStreams.indexWhere(
      (audioStream) => audioStream.guid == targetAudio.guid,
    );
    if (targetOrdinal >= 0 && targetOrdinal < embeddedTracks.length) {
      return embeddedTracks[targetOrdinal];
    }

    AppTalker.warning(
      'Player',
      'direct-link audio resolve failed: guid=${targetAudio.guid}, '
          'index=${targetAudio.index}, title=${targetAudio.title}, '
          'language=${targetAudio.language}',
    );
    return null;
  }

  /// Every stream in `MediaInfo.audio` belongs to the open media, so it is
  /// embedded by definition.
  bool _isEmbeddedTrack(mdk.AudioStreamInfo track) => true;

  bool _matchesTitleLanguageAndCodec(
    mdk.AudioStreamInfo track,
    AudioStream audioStream,
  ) {
    final normalizedTitle = _normalize(audioStream.title);
    final normalizedLanguage = _normalize(audioStream.language);
    final normalizedCodec = _normalize(audioStream.codecName);
    if (normalizedTitle.isEmpty ||
        normalizedLanguage.isEmpty ||
        normalizedCodec.isEmpty) {
      return false;
    }

    return _trackTitle(track) == normalizedTitle &&
        _trackLanguage(track) == normalizedLanguage &&
        _normalize(track.codec.codec) == normalizedCodec;
  }

  bool _matchesTitleAndLanguage(
    mdk.AudioStreamInfo track,
    AudioStream audioStream,
  ) {
    final normalizedTitle = _normalize(audioStream.title);
    final normalizedLanguage = _normalize(audioStream.language);
    if (normalizedTitle.isEmpty || normalizedLanguage.isEmpty) {
      return false;
    }

    return _trackTitle(track) == normalizedTitle &&
        _trackLanguage(track) == normalizedLanguage;
  }

  bool _matchesLanguageAndChannelCount(
    mdk.AudioStreamInfo track,
    AudioStream audioStream,
  ) {
    final normalizedLanguage = _normalize(audioStream.language);
    if (normalizedLanguage.isEmpty || audioStream.channels <= 0) {
      return false;
    }

    return _trackLanguage(track) == normalizedLanguage &&
        track.codec.channels == audioStream.channels;
  }

  static String _trackTitle(mdk.AudioStreamInfo track) =>
      _normalize(track.metadata['title']);

  static String _trackLanguage(mdk.AudioStreamInfo track) =>
      _normalize(track.metadata['language']);

  static String _normalize(String? value) {
    return (value ?? '').trim().toLowerCase();
  }
}
