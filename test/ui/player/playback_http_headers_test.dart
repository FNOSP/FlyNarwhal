import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/ui/features/player/models/playback_source_spec.dart';
import 'package:fly_narwhal/ui/features/player/services/playback_http_headers.dart';

void main() {
  const nasHeaders = {'Authorization': 'nas-token', 'Cookie': 'nas-cookie'};
  const cloudHeaders = <String, dynamic>{
    'Cookie': ['provider=one', 'ticket=two'],
    'Referer': 'https://provider.example/',
  };

  test(
      'Given Quark range playback, when building local player headers, then no NAS or provider headers reach loopback',
      () {
    final headers = buildPlaybackHttpHeaders(
      transport: PlaybackTransport.quarkCdnRange,
      playUri: 'http://127.0.0.1:12345/source/media',
      baseUrl: 'https://nas.example',
      buildNasHeaders: () => throw StateError('NAS headers must not be read'),
      cloudHeaders: cloudHeaders,
    );
    expect(headers, isEmpty);
  });

  for (final path in [
    '/v/api/v1/media/range/media-guid?direct_link_quality_index=1',
    '/v/api/v1/wp/m3u8?originalUrl=encoded',
    '/v/media/session/preset.m3u8',
    '/v/media/session/segment001.ts',
  ]) {
    test(
        'Given legacy NAS playback at $path, when building headers, then retains NAS auth and encoded provider headers',
        () {
      final headers = buildPlaybackHttpHeaders(
        transport: PlaybackTransport.standard,
        playUri: 'https://nas.example$path',
        baseUrl: 'https://nas.example/',
        buildNasHeaders: () => nasHeaders,
        cloudHeaders: cloudHeaders,
      );
      expect(headers['Authorization'], 'nas-token');
      expect(headers['Cookie'], 'nas-cookie');
      expect(jsonDecode(headers['X-Wp-Header']!), cloudHeaders);
      expect(nasHeaders, isNot(contains('X-Wp-Header')));
    });
  }

  test(
      'Given a standard external HLS URL, when building headers, then preserves provider headers without NAS credentials',
      () {
    final headers = buildPlaybackHttpHeaders(
      transport: PlaybackTransport.standard,
      playUri: 'https://cdn.example/playlist.m3u8',
      baseUrl: 'https://nas.example',
      buildNasHeaders: () => throw StateError('Must not use NAS auth'),
      cloudHeaders: const {
        'Referer': 'https://provider.example/',
        'Empty': null
      },
    );
    expect(headers, {'Referer': 'https://provider.example/'});
  });

  test(
      'Given the NAS host at another port, when opening an external playlist, then does not attach NAS credentials',
      () {
    final headers = buildPlaybackHttpHeaders(
      transport: PlaybackTransport.standard,
      playUri: 'https://nas.example:9443/playlist.m3u8',
      baseUrl: 'https://nas.example:8443',
      buildNasHeaders: () => throw StateError('Port is not the NAS endpoint'),
      cloudHeaders: null,
    );
    expect(headers, isEmpty);
  });

  test(
      'Given Quark single-file to HLS to single-file transitions, when resolving player headers, then restores NAS auth only for the legacy HLS source',
      () {
    var nasHeaderReads = 0;
    Map<String, String> headersFor(PlaybackTransport transport, String uri) =>
        buildPlaybackHttpHeaders(
          transport: transport,
          playUri: uri,
          baseUrl: 'https://nas.example',
          buildNasHeaders: () {
            nasHeaderReads++;
            return nasHeaders;
          },
          cloudHeaders: cloudHeaders,
        );

    final first = headersFor(
        PlaybackTransport.quarkCdnRange, 'http://127.0.0.1:12345/first/media');
    final hls = headersFor(PlaybackTransport.standard,
        'https://nas.example/v/api/v1/media/range/id?direct_link_quality_index=1');
    final last = headersFor(
        PlaybackTransport.quarkCdnRange, 'http://127.0.0.1:23456/last/media');

    expect(first, isEmpty);
    expect(last, isEmpty);
    expect(hls['Authorization'], 'nas-token');
    expect(hls['Cookie'], 'nas-cookie');
    expect(jsonDecode(hls['X-Wp-Header']!), cloudHeaders);
    expect(nasHeaderReads, 1);
  });
}
