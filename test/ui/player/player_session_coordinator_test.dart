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

  group('PlayerSessionCoordinator.getDirectPlayLink', () {
    test(
      'Given Quark qualities, When selecting another quality, Then it marks that exact CDN URL for bounded range transport',
      () async {
        final qualities = [
          DirectLinkQuality(
              resolution: '原画', url: 'https://cdn.example/raw.mkv'),
          DirectLinkQuality(
              resolution: '流畅', url: 'https://cdn.example/small.mp4'),
        ];
        for (var index = 0; index < qualities.length; index++) {
          final result = await coordinator.getDirectPlayLink(
            mediaGuid: 'media-guid',
            startPositionMs: 12345,
            directLinkQualityIndex: index,
            directLinkQualities: qualities,
            cloudStorageType: 4,
          );
          expect(result.playUri, qualities[index].url);
          expect(result.transport, PlaybackTransport.quarkCdnRange);
          expect(result.sourceError, isNull);
          expect(result.effectiveStartMs, 12345);
        }
      },
    );

    test(
      'Given an invalid Quark single-file URL, When resolving direct playback, Then it returns a manual recovery error without a NAS URL',
      () async {
        for (final quality in [
          DirectLinkQuality(resolution: '原画', url: '', isM3u8: false),
          DirectLinkQuality(resolution: '原画', url: 'file:///movie.mkv'),
        ]) {
          final result = await coordinator.getDirectPlayLink(
            mediaGuid: 'media-guid',
            startPositionMs: 0,
            directLinkQualityIndex: 0,
            directLinkQualities: [quality],
            cloudStorageType: 4,
          );
          expect(result.sourceError, contains('NAS'));
          expect(result.transport, PlaybackTransport.standard);
          expect(result.playUri, isNot(contains('/media/range')));
        }
      },
    );

    test(
      'Given recognized Quark HLS, When resolving a selected quality, Then it preserves the NAS route and original index even without a public URL',
      () async {
        for (final quality in [
          DirectLinkQuality(
              resolution: 'HLS',
              url: 'https://cdn.example/opaque',
              isM3u8: true),
          DirectLinkQuality(resolution: 'HLS', isM3u8: true),
          DirectLinkQuality.fromJson({
            'resolution': 'HLS',
            'url': null,
            'is_m3u8': true,
          }),
          DirectLinkQuality(
              resolution: 'HLS', url: 'https://cdn.example/video.m3u8'),
          DirectLinkQuality(
              resolution: 'HLS',
              url: 'https://cdn.example/video.M3U8?token=test'),
          DirectLinkQuality(
              resolution: 'HLS',
              url: 'https://cdn.example/video.M3u8?token=test'),
        ]) {
          final result = await coordinator.getDirectPlayLink(
            mediaGuid: 'media-guid',
            startPositionMs: 12345,
            directLinkQualityIndex: 1,
            directLinkQualities: [
              DirectLinkQuality(
                  resolution: '原画', url: 'https://cdn.example/raw.mkv'),
              quality,
            ],
            cloudStorageType: 4,
          );
          expect(result.playUri,
              'https://example.com/v/api/v1/media/range/media-guid?direct_link_quality_index=1');
          expect(result.playLinkRaw, '/v/api/v1/media/range/media-guid');
          expect(result.transport, PlaybackTransport.standard);
          expect(result.sourceError, isNull);
          expect(result.effectiveStartMs, 12345);
        }
      },
    );

    test(
      'Given invalid Quark quality index, When resolving direct playback, Then it does not silently fall back to NAS',
      () async {
        final result = await coordinator.getDirectPlayLink(
          mediaGuid: 'media-guid',
          startPositionMs: 0,
          directLinkQualityIndex: 2,
          directLinkQualities: [DirectLinkQuality(resolution: '原画')],
          cloudStorageType: 4,
        );
        expect(result.sourceError, isNotNull);
        expect(result.playUri, isEmpty);
      },
    );

    test(
      'Given STRM media, When resolving the direct play link, Then it plays the NAS-resolved URL directly',
      () async {
        const strmUrl =
            'http://192.168.31.73:8024/smartstrm_fid/movie.mkv?sign=abc';
        final result = await coordinator.getDirectPlayLink(
          mediaGuid: 'media-guid',
          startPositionMs: 16000,
          directLinkQualityIndex: 0,
          directLinkQualities: [
            DirectLinkQuality(
              resolution: '原画',
              url: strmUrl,
              isM3u8: false,
            ),
          ],
          cloudStorageType: CloudStorageInfo.strmCloudStorageType,
        );

        expect(result.playUri, equals(strmUrl));
        expect(result.transport, PlaybackTransport.standard);
        expect(result.playLinkRaw, equals(strmUrl));
        expect(result.effectiveStartMs, equals(16000));
      },
    );

    test(
      'Given Baidu Pan media, When resolving the direct play link, Then it still routes through the media/range proxy',
      () async {
        final result = await coordinator.getDirectPlayLink(
          mediaGuid: 'media-guid',
          startPositionMs: 0,
          directLinkQualityIndex: 0,
          directLinkQualities: [
            DirectLinkQuality(
              resolution: '原画',
              url: 'https://pan.example.com/movie.mkv',
              isM3u8: false,
            ),
          ],
          cloudStorageType: 1,
        );

        expect(
          result.playUri,
          equals(
            'https://example.com/v/api/v1/media/range/media-guid'
            '?direct_link_quality_index=0',
          ),
        );
        expect(result.transport, PlaybackTransport.standard);
      },
    );
  });

  group('Quark transport session boundaries', () {
    void stubStream(StreamResponse stream) {
      when(() => playerService.getPlayInfo(any(),
              mediaGuid: any(named: 'mediaGuid')))
          .thenAnswer((_) async => _buildPlayInfoResponse());
      when(() => playerService.getIpHash(any())).thenReturn('ip-hash');
      when(() => playerService.getStreamInfo(any(),
          ip: any(named: 'ip'),
          level: any(named: 'level'))).thenAnswer((_) async => stream);
    }

    test(
      'Given Quark direct mode, When loading or retrying a session, Then it prepares the current CDN without a NAS transcode',
      () async {
        stubStream(_buildQuarkStreamResponse());
        for (var attempt = 0; attempt < 2; attempt++) {
          final result = await coordinator.loadSession(
            const PlayerRouteTarget(guid: 'item-guid', userGuid: 'user-1'),
          );
          expect(result.preparedPlaySource.transport,
              PlaybackTransport.quarkCdnRange);
          expect(result.preparedPlaySource.playUri,
              'https://cdn.example/movie.mkv');
          expect(result.preparedPlaySource.sourceError, isNull);
          expect(result.playingInfoCache.directLinkQualityIndex, 0);
          expect(result.playingInfoCache.streamInfo?.header?['Cookie'],
              ['provider=one', 'ticket=two']);
        }
        verifyNever(() => playerService.playVideo(any()));
      },
    );

    test(
      'Given only HLS Quark qualities, When loading or retrying direct mode, Then it preserves visible qualities and the existing NAS route',
      () async {
        stubStream(_buildQuarkStreamResponse(hlsOnly: true));
        var requests = 0;
        dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
          requests++;
          handler.reject(DioException(requestOptions: options));
        }));
        for (var attempt = 0; attempt < 2; attempt++) {
          final result = await coordinator.loadSession(
            const PlayerRouteTarget(guid: 'item-guid'),
          );
          expect(result.preparedPlaySource.sourceError, isNull);
          expect(
              result.preparedPlaySource.transport, PlaybackTransport.standard);
          expect(result.preparedPlaySource.playUri,
              'https://example.com/v/api/v1/media/range/media-guid?direct_link_quality_index=0');
          expect(result.preparedPlaySource.useHlsSubtitleOverlay, isFalse);
          expect(
              result.playingInfoCache.streamInfo?.isCloudDirectMedia, isTrue);
          expect(result.playingInfoCache.isUseDirectLink, isTrue);
          expect(result.playingInfoCache.directLinkQualityIndex, 0);
          expect(result.playingInfoCache.directLinkQualities, hasLength(1));
          expect(result.playingInfoCache.currentQualities, hasLength(1));
          expect(result.currentQuality?.resolution, '原画');
          expect(result.currentQuality?.isM3u8, isTrue);
        }
        expect(requests, 0);
        verifyNever(() => playerService.playVideo(any()));
      },
    );

    test(
      'Given mixed Quark qualities, When loading the default or saved single-file quality, Then HLS remains visible and CDN indices stay original',
      () async {
        stubStream(_buildQuarkStreamResponse(directQualities: [
          DirectLinkQuality(
              resolution: 'HLS',
              url: 'https://cdn.example/opaque',
              isM3u8: true),
          DirectLinkQuality(
              resolution: '原画', url: 'https://cdn.example/raw.mkv'),
          DirectLinkQuality(
              resolution: '流畅', url: 'https://cdn.example/smooth.mp4'),
        ]));
        final initial = await coordinator.loadSession(
          const PlayerRouteTarget(guid: 'item-guid', userGuid: 'user-1'),
        );
        expect(initial.playingInfoCache.directLinkQualityIndex, 2);
        expect(initial.preparedPlaySource.playUri,
            'https://cdn.example/smooth.mp4');
        expect(initial.preparedPlaySource.transport,
            PlaybackTransport.quarkCdnRange);
        expect(initial.qualities.map((quality) => quality.resolution),
            ['HLS', '原画', '流畅']);
        expect(initial.qualities.first.isM3u8, isTrue);

        await playerSettingsManager.setNetdiskQuality('原画', userGuid: 'user-1');
        final retried = await coordinator.loadSession(
          const PlayerRouteTarget(guid: 'item-guid', userGuid: 'user-1'),
        );
        expect(retried.playingInfoCache.directLinkQualityIndex, 1);
        expect(
            retried.preparedPlaySource.playUri, 'https://cdn.example/raw.mkv');
        expect(retried.preparedPlaySource.transport,
            PlaybackTransport.quarkCdnRange);
        expect(retried.preparedPlaySource.sourceError, isNull);
        verifyNever(() => playerService.playVideo(any()));
      },
    );

    test(
      'Given a saved Quark quality with an unflagged uppercase HLS URL, When loading or retrying, Then it uses the original NAS index',
      () async {
        stubStream(_buildQuarkStreamResponse(directQualities: [
          DirectLinkQuality(
              resolution: '原画', url: 'https://cdn.example/raw.mkv'),
          DirectLinkQuality(
              resolution: '高清',
              url: 'https://cdn.example/video.M3U8?token=test'),
        ]));
        await playerSettingsManager.setNetdiskQuality('高清', userGuid: 'user-1');
        for (var attempt = 0; attempt < 2; attempt++) {
          final result = await coordinator.loadSession(
            const PlayerRouteTarget(guid: 'item-guid', userGuid: 'user-1'),
          );
          expect(result.playingInfoCache.directLinkQualityIndex, 1);
          expect(result.qualities.map((quality) => quality.resolution),
              ['原画', '高清']);
          expect(result.preparedPlaySource.playUri,
              'https://example.com/v/api/v1/media/range/media-guid?direct_link_quality_index=1');
          expect(
              result.preparedPlaySource.transport, PlaybackTransport.standard);
          expect(result.preparedPlaySource.sourceError, isNull);
          expect(result.effectiveStartPositionMs, 12000);
        }
        verifyNever(() => playerService.playVideo(any()));
      },
    );

    test(
      'Given empty or absent Quark qualities, When loading direct mode, Then it preserves a recoverable cloud session without opening NAS',
      () async {
        for (final qualities in <List<DirectLinkQuality>?>[[], null]) {
          final original = _buildStreamResponse();
          stubStream(StreamResponse(
            videoStream: original.videoStream,
            fileStream: original.fileStream,
            audioStreams: original.audioStreams,
            subtitleStreams: original.subtitleStreams,
            qualities: original.qualities,
            cloudStorageInfo: CloudStorageInfo(cloudStorageType: 4),
            directLinkQualities: qualities,
          ));
          final result = await coordinator.loadSession(
            const PlayerRouteTarget(guid: 'item-guid'),
          );
          expect(result.preparedPlaySource.sourceError, contains('NAS'));
          expect(result.preparedPlaySource.playUri, isEmpty);
          expect(
              result.preparedPlaySource.transport, PlaybackTransport.standard);
          expect(
              result.playingInfoCache.streamInfo?.cloudStorageInfo
                  ?.cloudStorageType,
              4);
          expect(result.playingInfoCache.isUseDirectLink, isTrue);
          expect(result.playingInfoCache.currentQualities, isEmpty);
          expect(result.currentQuality, isNull);
          verifyNever(() => playerService.playVideo(any()));
        }
      },
    );

    test(
      'Given Quark NAS mode with an original-file transcode result, When loading, Then it remains on the standard NAS transport',
      () async {
        stubStream(_buildQuarkStreamResponse());
        await playerSettingsManager.setCloudPlayMode(4, 'proxy',
            userGuid: 'user-1');
        when(() => playerService.playVideo(any())).thenAnswer(
            (_) async => PlayPlayResponse(playLink: '/nas/movie.mkv'));
        final result = await coordinator.loadSession(
          const PlayerRouteTarget(guid: 'item-guid', userGuid: 'user-1'),
        );
        expect(result.preparedPlaySource.transport, PlaybackTransport.standard);
        expect(result.preparedPlaySource.playUri,
            'https://example.com/nas/movie.mkv');
        expect(result.preparedPlaySource.sourceError, isNull);
        expect(result.playingInfoCache.directLinkQualityIndex, isNull);
        expect(playerSettingsManager.getCloudPlayMode(4, 'user-1'), 'proxy');
        verify(() => playerService.playVideo(any())).called(1);
      },
    );

    test(
      'Given Quark NAS mode and server error 8192, When the existing original-file fallback runs, Then it never gains CDN range transport',
      () async {
        stubStream(_buildQuarkStreamResponse());
        await playerSettingsManager.setCloudPlayMode(4, 'proxy',
            userGuid: 'user-1');
        when(() => playerService.playVideo(any())).thenThrow(Exception('8192'));
        final result = await coordinator.loadSession(
          const PlayerRouteTarget(guid: 'item-guid', userGuid: 'user-1'),
        );
        expect(result.playingInfoCache.isUseDirectLink, isTrue);
        expect(result.playingInfoCache.directLinkQualityIndex, isNull);
        expect(result.preparedPlaySource.transport, PlaybackTransport.standard);
        expect(result.preparedPlaySource.playUri,
            'https://example.com/v/api/v1/media/range/media-guid');
        expect(result.preparedPlaySource.sourceError, isNull);
        expect(playerSettingsManager.getCloudPlayMode(4, 'user-1'), 'proxy');
      },
    );

    test(
      'Given Quark HLS and single-file qualities, When filtering, Then every quality and its original index remain available',
      () {
        final result = PlayerSessionCoordinator.filterDirectLinkQualities(
          cloudStorageType: 4,
          qualities: [
            DirectLinkQuality(
                resolution: 'HLS', url: 'https://cdn.example/video.m3u8'),
            DirectLinkQuality(
                resolution: '原画', url: 'https://cdn.example/video.mkv'),
          ],
        );
        expect(result.originalIndices, [0, 1]);
        expect(result.qualities.map((quality) => quality.resolution),
            ['HLS', '原画']);
      },
    );
  });
}

StreamResponse _buildQuarkStreamResponse({
  bool hlsOnly = false,
  List<DirectLinkQuality>? directQualities,
}) {
  final original = _buildStreamResponse();
  return StreamResponse(
    videoStream: original.videoStream,
    audioStreams: original.audioStreams,
    subtitleStreams: original.subtitleStreams,
    fileStream: original.fileStream,
    qualities: original.qualities,
    cloudStorageInfo: CloudStorageInfo(cloudStorageType: 4),
    directLinkQualities: directQualities ??
        [
          DirectLinkQuality(
            resolution: '原画',
            url: hlsOnly
                ? 'https://cdn.example/movie.m3u8'
                : 'https://cdn.example/movie.mkv',
            isM3u8: hlsOnly,
          ),
        ],
    header: {
      'Cookie': ['provider=one', 'ticket=two']
    },
  );
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
