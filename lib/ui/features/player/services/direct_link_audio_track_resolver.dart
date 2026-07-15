import 'package:media_kit/media_kit.dart';

import '../../../../core/utils/log/app_talker.dart';
import '../../../../data/models/movie_detail_models.dart';

class DirectLinkAudioTrackResolver {
  const DirectLinkAudioTrackResolver();

  List<AudioTrack> embeddedTracksOf(List<AudioTrack> audioTracks) {
    return audioTracks.where(_isEmbeddedTrack).toList(growable: false);
  }

  AudioTrack? resolve({
    required List<AudioStream> audioStreams,
    required List<AudioTrack> audioTracks,
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

  bool _isEmbeddedTrack(AudioTrack track) {
    return track.id != 'auto' && track.id != 'no' && track.uri == false;
  }

  bool _matchesTitleLanguageAndCodec(
    AudioTrack track,
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

    return _normalize(track.title) == normalizedTitle &&
        _normalize(track.language) == normalizedLanguage &&
        _normalize(track.codec) == normalizedCodec;
  }

  bool _matchesTitleAndLanguage(
    AudioTrack track,
    AudioStream audioStream,
  ) {
    final normalizedTitle = _normalize(audioStream.title);
    final normalizedLanguage = _normalize(audioStream.language);
    if (normalizedTitle.isEmpty || normalizedLanguage.isEmpty) {
      return false;
    }

    return _normalize(track.title) == normalizedTitle &&
        _normalize(track.language) == normalizedLanguage;
  }

  bool _matchesLanguageAndChannelCount(
    AudioTrack track,
    AudioStream audioStream,
  ) {
    final normalizedLanguage = _normalize(audioStream.language);
    if (normalizedLanguage.isEmpty || audioStream.channels <= 0) {
      return false;
    }

    return _normalize(track.language) == normalizedLanguage &&
        track.channelscount == audioStream.channels;
  }

  String _normalize(String? value) {
    return (value ?? '').trim().toLowerCase();
  }
}
