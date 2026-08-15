import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fly_narwhal/data/models/movie_detail_models.dart';
import 'package:fly_narwhal/data/models/player_models.dart';
import 'package:fly_narwhal/data/storage/player_settings_store.dart';
import 'package:fly_narwhal/data/storage/preferences_manager.dart';
import 'package:fly_narwhal/ui/features/player/controllers/player_session_coordinator.dart';
import 'package:fly_narwhal/ui/features/player/services/player_service.dart';

class _MockPlayerService extends Mock implements PlayerService {}

void main() {
  late Dio dio;
  late _MockPlayerService playerService;
  late PreferencesManager preferencesManager;
  late PlayerSettingsManager playerSettingsManager;
  late PlayerSessionCoordinator coordinator;

  setUpAll(() {
    registerFallbackValue(
      PlayPlayRequest(
        mediaGuid: 'fallback-media',
        videoGuid: 'fallback-video',
        videoEncoder: 'h264',
        resolution: '1080p',
        bitrate: 8000000,
        audioGuid: 'fallback-audio',
      ),
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'base_url': 'https://example.com',
      'auth_token': 'token',
      'cookie_state': 'cookie',
    });
    final prefs = await SharedPreferences.getInstance();
    dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.uri.host == '127.0.0.1' && options.uri.path == '/event') {
            handler.resolve(
              Response<void>(
                requestOptions: options,
                statusCode: 200,
              ),
            );
            return;
          }
          handler.next(options);
        },
      ),
    );
    playerService = _MockPlayerService();
    preferencesManager = PreferencesManager(prefs);
    playerSettingsManager = PlayerSettingsManager(prefs);
    coordinator = PlayerSessionCoordinator(
      playerService: playerService,
      preferencesManager: preferencesManager,
      playerSettingsManager: playerSettingsManager,
      dio: dio,
    );
  });

  group('PlayerSessionCoordinator.preparePlaySourceForMediaKit', () {
    test(
      'Given HLS master with subtitle media, When subtitle stream is missing, Then it still resolves the concrete video playlist',
      () async {
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final responseBody = switch (options.uri.path) {
                '/preset.m3u8' => '''
#EXTM3U
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",LANGUAGE="chi",NAME="Chinese",URI="subs/chi.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=1280000,SUBTITLES="subs"
video/main.m3u8
''',
                _ => '#EXTM3U',
              };

              handler.resolve(
                Response<String>(
                  requestOptions: options,
                  data: responseBody,
                  statusCode: 200,
                ),
              );
            },
          ),
        );

        final result = await coordinator.preparePlaySourceForMediaKit(
          playUri: 'https://example.com/preset.m3u8',
          currentSubtitleStream: null,
        );

        expect(result.playUri, equals('https://example.com/video/main.m3u8'));
        expect(result.useHlsSubtitleOverlay, isFalse);
        expect(result.subtitlePlaylistUrl, isNull);
      },
    );

    test(
      'Given matching internal subtitle stream, When HLS source is prepared, Then it keeps the video playlist and exposes subtitle overlay url',
      () async {
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final responseBody = switch (options.uri.path) {
                '/preset.m3u8' => '''
#EXTM3U
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",LANGUAGE="chi",NAME="Chinese",URI="subs/chi.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=1280000,SUBTITLES="subs"
video/main.m3u8
''',
                _ => '#EXTM3U',
              };

              handler.resolve(
                Response<String>(
                  requestOptions: options,
                  data: responseBody,
                  statusCode: 200,
                ),
              );
            },
          ),
        );

        final result = await coordinator.preparePlaySourceForMediaKit(
          playUri: 'https://example.com/preset.m3u8',
          currentSubtitleStream: _buildSubtitleStream(
            guid: 'subtitle-guid',
            title: 'Chinese',
            language: 'chi',
            index: 0,
            isExternal: 0,
            format: 'vtt',
          ),
        );

        expect(result.playUri, equals('https://example.com/video/main.m3u8'));
        expect(result.useHlsSubtitleOverlay, isTrue);
        expect(
          result.subtitlePlaylistUrl,
          equals('https://example.com/subs/chi.m3u8'),
        );
      },
    );
  });

  group('PlayerSessionCoordinator direct-link session state', () {
    test(
      'Given original quality, When session resolves to direct link, Then cache keeps direct-link mode and creates a record play link',
      () async {
        when(
          () => playerService.getPlayInfo(
            any(),
            mediaGuid: any(named: 'mediaGuid'),
          ),
        ).thenAnswer((_) async => _buildPlayInfoResponse());
        when(() => playerService.getIpHash(any())).thenReturn('ip-hash');
        when(
          () => playerService.getStreamInfo(
            any(),
            ip: any(named: 'ip'),
            level: any(named: 'level'),
          ),
        ).thenAnswer((_) async => _buildStreamResponse());

        final result = await coordinator.loadSession(
          const PlayerRouteTarget(guid: 'item-guid'),
        );

        expect(result.playingInfoCache.isUseDirectLink, isTrue);
        expect(result.playingInfoCache.playLink, isNull);
        expect(result.playingInfoCache.playRecordLink, isNotNull);
        expect(
          result.playingInfoCache.playRecordLink,
          matches(
            RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
            ),
          ),
        );
        expect(
          result.preparedPlaySource.playUri,
          equals('https://example.com/v/api/v1/media/range/media-guid'),
        );
      },
    );

    test(
      'Given first quality, When supportsDirectLink is evaluated, Then it treats the first quality as original quality',
      () {
        final stream = _buildVideoStream();
        final qualities = <QualityResponse>[
          QualityResponse(bitrate: 24000000, resolution: '4k'),
          QualityResponse(bitrate: 8000000, resolution: '1080p'),
        ];

        expect(
          coordinator.supportsDirectLink(stream, qualities.first, qualities),
          isTrue,
        );
        expect(
          coordinator.supportsDirectLink(stream, qualities.last, qualities),
          isFalse,
        );
      },
    );

    test(
      'Given saved quality, When session loads, Then it restores the saved quality and starts transcode with that selection',
      () async {
        await playerSettingsManager.setQuality(
          '1080p',
          8000000,
          userGuid: 'user-1',
        );
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.uri.path == '/preset.m3u8') {
                handler.resolve(
                  Response<String>(
                    requestOptions: options,
                    data: '#EXTM3U',
                    statusCode: 200,
                  ),
                );
                return;
              }
              handler.next(options);
            },
          ),
        );
        when(
          () => playerService.getPlayInfo(
            any(),
            mediaGuid: any(named: 'mediaGuid'),
          ),
        ).thenAnswer((_) async => _buildPlayInfoResponse());
        when(() => playerService.getIpHash(any())).thenReturn('ip-hash');
        when(
          () => playerService.getStreamInfo(
            any(),
            ip: any(named: 'ip'),
            level: any(named: 'level'),
          ),
        ).thenAnswer((_) async => _buildStreamResponse());
        when(
          () => playerService.playVideo(any()),
        ).thenAnswer((_) async => PlayPlayResponse(playLink: '/preset.m3u8'));

        final result = await coordinator.loadSession(
          const PlayerRouteTarget(
            guid: 'item-guid',
            userGuid: 'user-1',
          ),
        );

        expect(result.currentQuality?.resolution, equals('1080p'));
        expect(result.currentQuality?.bitrate, equals(8000000));
        expect(result.playingInfoCache.isUseDirectLink, isFalse);
        final captured = verify(() => playerService.playVideo(captureAny()))
            .captured
            .single as PlayPlayRequest;
        expect(captured.resolution, equals('1080p'));
        expect(captured.bitrate, equals(8000000));
        expect(captured.startTimestamp, equals(12));
      },
    );

    test(
      'Given saved resolution without matching bitrate, When session loads, Then it falls back to the highest bitrate of that resolution',
      () async {
        await playerSettingsManager.setQuality(
          '1080p',
          123456,
          userGuid: 'user-1',
        );

        final selected = coordinator.initializeQuality(
          _buildStreamResponse().qualities!,
          userGuid: 'user-1',
        );

        expect(selected?.resolution, equals('1080p'));
        expect(selected?.bitrate, equals(8000000));
      },
    );

    test(
      'Given another user saved quality, When session loads for current user, Then it does not reuse the other user quality',
      () async {
        await playerSettingsManager.setQuality(
          '1080p',
          8000000,
          userGuid: 'user-1',
        );
        when(
          () => playerService.getPlayInfo(
            any(),
            mediaGuid: any(named: 'mediaGuid'),
          ),
        ).thenAnswer((_) async => _buildPlayInfoResponse());
        when(() => playerService.getIpHash(any())).thenReturn('ip-hash');
        when(
          () => playerService.getStreamInfo(
            any(),
            ip: any(named: 'ip'),
            level: any(named: 'level'),
          ),
        ).thenAnswer((_) async => _buildStreamResponse());

        final result = await coordinator.loadSession(
          const PlayerRouteTarget(
            guid: 'item-guid',
            userGuid: 'user-2',
          ),
        );

        expect(result.currentQuality?.resolution, equals('4k'));
        expect(result.currentQuality?.bitrate, equals(24000000));
        expect(result.playingInfoCache.isUseDirectLink, isTrue);
        verifyNever(() => playerService.playVideo(any()));
      },
    );
  });
}

PlayInfoResponse _buildPlayInfoResponse() {
  return PlayInfoResponse(
    grandGuid: 'grand-guid',
    guid: 'play-guid',
    parentGuid: 'parent-guid',
    playConfig: null,
    ts: 12,
    type: 'Movie',
    videoGuid: 'video-guid',
    audioGuid: 'audio-guid',
    subtitleGuid: '',
    mediaGuid: 'media-guid',
    item: _buildItemResponse(),
    directLinkAudioIndex: -1,
  );
}

StreamResponse _buildStreamResponse() {
  return StreamResponse(
    videoStream: _buildVideoStream(),
    audioStreams: <AudioStream>[
      _buildAudioStream(),
    ],
    subtitleStreams: const <SubtitleStream>[],
    fileStream: _buildFileInfo(),
    qualities: <QualityResponse>[
      QualityResponse(bitrate: 24000000, resolution: '4k'),
      QualityResponse(bitrate: 8000000, resolution: '1080p'),
    ],
  );
}

ItemResponse _buildItemResponse() {
  return ItemResponse(
    guid: 'item-guid',
    trimId: 'trim-id',
    tvTitle: '',
    parentTitle: '',
    title: 'Movie',
    posters: '',
    posterWidth: 0,
    posterHeight: 0,
    voteAverage: '0',
    isFavorite: 0,
    isWatched: 0,
    watchedTs: 0,
    seasonNumber: 0,
    numberOfSeasons: 0,
    numberOfEpisodes: 0,
    localNumberOfEpisodes: 0,
    localNumberOfSeasons: 0,
    canPlay: 1,
    type: 'Movie',
    playError: '',
    parentGuid: 'parent-guid',
    ancestorName: '',
    playItemGuid: 'item-guid',
    duration: 7200,
    logicType: 0,
    episodeNumber: 0,
  );
}

FileInfo _buildFileInfo() {
  return FileInfo(
    guid: 'file-guid',
    path: '/movie.mkv',
    fileName: 'movie.mkv',
    size: 1,
    timestamp: 0,
    type: 0,
    canPlay: 1,
    playError: '',
    createTime: 0,
    updateTime: 0,
    fileBirthTime: 0,
    progressThumbHashDir: '',
  );
}

VideoStream _buildVideoStream() {
  return VideoStream(
    mediaGuid: 'media-guid',
    title: 'Main Video',
    guid: 'video-guid',
    resolutionType: '4k',
    colorRangeType: 'hdr',
    codecName: 'hevc',
    codecType: 'video',
    colorRange: 'tv',
    profile: 'main10',
    index: 0,
    width: 3840,
    height: 2160,
    codedWidth: 3840,
    codedHeight: 2160,
    displayAspectRatio: '16:9',
    pixFmt: 'yuv420p10le',
    level: '5.1',
    colorSpace: 'bt2020nc',
    colorTransfer: 'smpte2084',
    colorPrimaries: 'bt2020',
    duration: 7200,
    dvProfile: 0,
    refs: 1,
    rFrameRate: '24/1',
    avgFrameRate: '24/1',
    bitsPerRawSample: '10',
    bps: 24000000,
    progressive: 1,
    bitDepth: 10,
    wrapper: 'mkv',
    createTime: 0,
    updateTime: 0,
    rotation: 0,
    ext1: 0,
    isBluray: false,
  );
}

AudioStream _buildAudioStream() {
  return AudioStream(
    mediaGuid: 'media-guid',
    title: 'Main Audio',
    guid: 'audio-guid',
    audioType: 'default',
    codecName: 'aac',
    codecType: 'audio',
    language: 'chi',
    channels: 2,
    profile: 'lc',
    sampleRate: '48000',
    isDefault: 1,
    channelLayout: 'stereo',
    duration: 7200,
    index: 1,
    bitsPerRawSample: '16',
    bps: 192000,
    createTime: 0,
    updateTime: 0,
    isFake: false,
  );
}

SubtitleStream _buildSubtitleStream({
  required String guid,
  required String title,
  required String language,
  required int index,
  required int isExternal,
  required String format,
}) {
  return SubtitleStream(
    mediaGuid: 'media-guid',
    title: title,
    guid: guid,
    codecName: format,
    codecType: 'subtitle',
    language: language,
    forced: 0,
    index: index,
    isDefault: 0,
    isExternal: isExternal,
    format: format,
    trimId: '',
    sourceId: '',
    source: '',
    createTime: 0,
    updateTime: 0,
    extraFile: 0,
    isBitmap: 0,
    fileSize: 0,
  );
}
