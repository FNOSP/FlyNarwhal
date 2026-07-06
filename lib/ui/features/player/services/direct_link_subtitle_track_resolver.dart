import 'package:media_kit/media_kit.dart';

import '../../../../core/utils/log/app_talker.dart';
import '../../../../data/models/movie_detail_models.dart';

class DirectLinkSubtitleTrackResolver {
  const DirectLinkSubtitleTrackResolver();

  List<SubtitleTrack> embeddedTracksOf(List<SubtitleTrack> subtitleTracks) {
    return subtitleTracks.where(_isEmbeddedTrack).toList(growable: false);
  }

  SubtitleTrack? resolve({
    required List<SubtitleStream> subtitleStreams,
    required List<SubtitleTrack> subtitleTracks,
    required SubtitleStream targetSubtitle,
  }) {
    if (targetSubtitle.isExternal == 1) {
      return null;
    }

    // Filter out placeholder or dynamically injected subtitle entries so the
    // resolver only compares real embedded tracks from the current media.
    final embeddedTracks = embeddedTracksOf(subtitleTracks);
    if (embeddedTracks.isEmpty) {
      AppTalker.info(
        'Player',
        'direct-link subtitle resolve skipped: no embedded subtitle tracks yet',
      );
      return null;
    }

    final exactMatches = embeddedTracks
        .where((track) => _matchesTitleAndLanguage(track, targetSubtitle))
        .toList();
    if (exactMatches.length == 1) {
      return exactMatches.single;
    }

    final embeddedSubtitles = subtitleStreams
        .where((subtitle) => subtitle.isExternal != 1)
        .toList()
      ..sort((left, right) => left.index.compareTo(right.index));
    final targetOrdinal = embeddedSubtitles.indexWhere(
      (subtitle) => subtitle.guid == targetSubtitle.guid,
    );
    if (targetOrdinal >= 0 && targetOrdinal < embeddedTracks.length) {
      return embeddedTracks[targetOrdinal];
    }

    AppTalker.warning(
      'Player',
      'direct-link subtitle resolve failed: guid=${targetSubtitle.guid}, '
          'title=${targetSubtitle.title}, language=${targetSubtitle.language}',
    );
    return null;
  }

  bool _isEmbeddedTrack(SubtitleTrack track) {
    return track.id != 'auto' &&
        track.id != 'no' &&
        track.uri == false &&
        track.data == false;
  }

  bool _matchesTitleAndLanguage(
    SubtitleTrack track,
    SubtitleStream subtitle,
  ) {
    final normalizedTitle = _normalize(subtitle.title);
    final normalizedLanguage = _normalize(subtitle.language);
    if (normalizedTitle.isEmpty || normalizedLanguage.isEmpty) {
      return false;
    }

    return _normalize(track.title) == normalizedTitle &&
        _normalize(track.language) == normalizedLanguage;
  }

  String _normalize(String? value) {
    return (value ?? '').trim().toLowerCase();
  }
}
