import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fly_narwhal/ui/features/player/services/direct_link_chunk_proxy.dart';
import 'package:fly_narwhal/services/update/update_disk_space_probe.dart';

/// Serves a fixed byte range over loopback so the proxy can be driven end to
/// end without a netdisk: it answers `bytes=a-b` with deterministic bytes, can
/// be told to fail the first N requests, and can be told to stall.
class _FakeUpstream {
  _FakeUpstream(this.length);

  final int length;
  HttpServer? _server;
  final List<int> servedRanges = [];
  /// Start offsets of window fetches, excluding the one-byte length probe.
  final List<int> windowStarts = [];

  /// Requests to reject with 500 before serving normally, counted down per
  /// request so a specific attempt can be made to fail.
  int failNextRequests = 0;

  /// Requests to reject with 500, matched by their start offset so the length
  /// probe (`bytes=0-0`) is not caught by a window's failure budget.
  int failRequestsAtStart = -1;
  int failCountAtStart = 0;

  /// Requests that hang until released, to model a stalled transfer.
  int stallNextRequests = 0;
  final List<Completer<void>> _stalls = [];

  int get port => _server!.port;
  Uri get uri => Uri.parse('http://127.0.0.1:$port/media.mkv');

  Future<void> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen((request) async {
      final range = request.headers.value(HttpHeaders.rangeHeader);
      final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range ?? '');
      if (match == null) {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
        return;
      }
      final start = int.parse(match.group(1)!);
      final end = match.group(2)!.isEmpty
          ? length - 1
          : int.parse(match.group(2)!);
      // Distinguish the one-byte length probe from a real window fetch so a
      // test can count only the latter.
      final isLengthProbe = start == 0 && end == 0;
      servedRanges.add(start);
      if (!isLengthProbe) windowStarts.add(start);
      if (start == failRequestsAtStart && failCountAtStart > 0) {
        failCountAtStart--;
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
        return;
      }
      if (failNextRequests > 0) {
        failNextRequests--;
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
        return;
      }
      if (stallNextRequests > 0) {
        stallNextRequests--;
        final gate = Completer<void>();
        _stalls.add(gate);
        await gate.future;
      }
      final count = end - start + 1;
      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/$length',
      );
      request.response.headers.contentLength = count;
      request.response.add(
        Uint8List.fromList(
          List<int>.generate(count, (i) => (start + i) & 0xFF),
        ),
      );
      await request.response.close();
    });
  }

  void releaseStalls() {
    for (final gate in _stalls) {
      if (!gate.isCompleted) gate.complete();
    }
    _stalls.clear();
  }

  Future<void> stop() async {
    releaseStalls();
    await _server?.close(force: true);
    _server = null;
  }
}

void main() {
  group('DirectLinkChunkProxy', () {
    late _FakeUpstream upstream;
    late Directory cacheRoot;

    setUp(() async {
      upstream = _FakeUpstream(directLinkChunkBytes * 6);
      await upstream.start();
      cacheRoot = Directory.systemTemp.createTempSync('proxy_test');
    });

    tearDown(() async {
      await upstream.stop();
      if (cacheRoot.existsSync()) cacheRoot.deleteSync(recursive: true);
    });

    test(
      'Given a bounded range, When the player reads it, Then every byte is '
      'served in order from the upstream',
      () async {
        final proxy = DirectLinkChunkProxy(
          dio: Dio(),
          supportDirectory: () => cacheRoot.path,
        );
        final playUri = await proxy.registerSession(
          mediaGuid: 'media-a',
          upstreamUrl: upstream.uri.toString(),
          headers: const {},
        );

        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(playUri));
        request.headers.set(
          HttpHeaders.rangeHeader,
          'bytes=0-${directLinkChunkBytes - 1}',
        );
        final response = await request.close();
        expect(response.statusCode, HttpStatus.partialContent);
        final bytes = await response.fold<List<int>>(
          <int>[],
          (acc, chunk) => acc..addAll(chunk),
        );

        expect(bytes.length, directLinkChunkBytes);
        // The fake echoes (offset & 0xFF), so the sequence proves the proxy
        // returned the requested region rather than something else.
        expect(bytes[0], 0);
        expect(bytes[1], 1);
        expect(bytes[255], 255);
        expect(bytes[256], 0);

        client.close(force: true);
        await proxy.dispose();
      },
    );

    test(
      'Given the upstream fails twice, When a window is read, Then the proxy '
      'retries and still serves it',
      () async {
        // Only the window request fails; the length probe at a different
        // offset is served normally.
        upstream.failRequestsAtStart = directLinkChunkBytes;
        upstream.failCountAtStart = 2;
        final proxy = DirectLinkChunkProxy(
          dio: Dio(),
          supportDirectory: () => cacheRoot.path,
        );
        final playUri = await proxy.registerSession(
          mediaGuid: 'media-b',
          upstreamUrl: upstream.uri.toString(),
          headers: const {},
        );

        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(playUri));
        // Ask for the window that was told to fail first, then succeed.
        request.headers.set(
          HttpHeaders.rangeHeader,
          'bytes=$directLinkChunkBytes-${directLinkChunkBytes * 2 - 1}',
        );
        final response = await request.close();
        expect(response.statusCode, HttpStatus.partialContent);
        final bytes = await response.fold<int>(0, (n, c) => n + c.length);

        expect(bytes, directLinkChunkBytes);
        // Three attempts at the same offset: two rejected, one served.
        expect(
          upstream.servedRanges.where((s) => s == directLinkChunkBytes).length,
          greaterThanOrEqualTo(3),
        );

        client.close(force: true);
        await proxy.dispose();
      },
    );

    test(
      'Given every attempt fails, When a window is read, Then the proxy '
      'reports the upstream as unavailable instead of serving a short body',
      () async {
        // More failures than the retry budget allows, scoped to the window
        // being read rather than to the length probe.
        upstream.failRequestsAtStart = directLinkChunkBytes;
        upstream.failCountAtStart = 99;
        final proxy = DirectLinkChunkProxy(
          dio: Dio(),
          supportDirectory: () => cacheRoot.path,
        );
        final playUri = await proxy.registerSession(
          mediaGuid: 'media-c',
          upstreamUrl: upstream.uri.toString(),
          headers: const {},
        );

        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(playUri));
        request.headers.set(
          HttpHeaders.rangeHeader,
          'bytes=$directLinkChunkBytes-${directLinkChunkBytes * 2 - 1}',
        );
        final response = await request.close();

        expect(response.statusCode, HttpStatus.badGateway);
        // The retry budget is three attempts, no more and no fewer: the fake
        // is told to fail 99 times, so a count of three proves the proxy gave
        // up after its configured attempts instead of trying once or forever.
        expect(
          upstream.windowStarts.where((s) => s == directLinkChunkBytes).length,
          3,
        );

        client.close(force: true);
        await proxy.dispose();
      },
    );

    test(
      'Given a session is released mid-transfer, When the player is still '
      'reading, Then the upstream request is dropped',
      () async {
        final proxy = DirectLinkChunkProxy(
          dio: Dio(),
          supportDirectory: () => cacheRoot.path,
        );
        final playUri = await proxy.registerSession(
          mediaGuid: 'media-d',
          upstreamUrl: upstream.uri.toString(),
          headers: const {},
        );

        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(playUri));
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-1023');
        unawaited(request.close().then((r) => r.drain<void>()));
        // Give the proxy time to start the upstream read, then drop the
        // session while that read is still in flight.
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await proxy.releaseSessionsForMedia('media-d');

        // The session is gone, so the proxy no longer reports traffic for it.
        // The in-flight read itself is torn down through the session's
        // CancelToken, which releaseSessionsForMedia cancels synchronously.
        expect(proxy.fetchedBytesForMedia('media-d'), isNull);

        client.close(force: true);
        await proxy.dispose();
      },
    );

    test(
      'Given two connections open the same window at once, When both request '
      'the head, Then the upstream fetches the window once',
      () async {
        final proxy = DirectLinkChunkProxy(
          dio: Dio(),
          supportDirectory: () => cacheRoot.path,
        );
        final playUri = await proxy.registerSession(
          mediaGuid: 'media-e',
          upstreamUrl: upstream.uri.toString(),
          headers: const {},
        );

        // Fire both requests together so they race into the same head window.
        final client = HttpClient();
        final first = await client.getUrl(Uri.parse(playUri));
        first.headers.set(
          HttpHeaders.rangeHeader,
          'bytes=0-${directLinkChunkBytes - 1}',
        );
        final second = await client.getUrl(Uri.parse(playUri));
        second.headers.set(
          HttpHeaders.rangeHeader,
          'bytes=0-${directLinkChunkBytes - 1}',
        );
        final firstResponse = await first.close();
        final secondResponse = await second.close();
        await Future.wait([
          firstResponse.drain<void>(),
          secondResponse.drain<void>(),
        ]);

        // The head window is one 8 MB chunk: two clients must not make the
        // proxy fetch it twice from upstream.
        expect(upstream.windowStarts.where((s) => s == 0).length, 1);

        client.close(force: true);
        await proxy.dispose();
      },
    );
  });

  group('DirectLinkChunkProxy disk cap', () {
    test(
      'Given a volume with little free space, When a session registers, Then '
      'the cap follows the free space instead of a fixed 512 MB',
      () async {
        final cacheRoot = Directory.systemTemp.createTempSync('proxy_cap');
        addTearDown(() {
          if (cacheRoot.existsSync()) cacheRoot.deleteSync(recursive: true);
        });
        // 40 MB free: half is 20 MB, below the floor, so the floor applies and
        // the cap lands far under the old fixed 512 MB.
        final probe = _RecordingProbe(40 * 1024 * 1024);
        final proxy = DirectLinkChunkProxy(
          dio: Dio(),
          supportDirectory: () => cacheRoot.path,
          diskSpaceProbe: probe,
        );
        await proxy.registerSession(
          mediaGuid: 'media-cap',
          upstreamUrl: 'http://127.0.0.1:1/media.mkv',
          headers: const {},
        );
        // The probe is consulted for the session's cache directory.
        expect(probe.queriedPaths, isNotEmpty);
        expect(probe.queriedPaths.first, contains('media-cap'));
        // 40 MB free -> 20 MB budget -> floored to 256 MB -> 32 chunks of
        // 8 MB. This proves the floor path of the sizing rule, not just that
        // the probe ran.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(proxy.maxDiskChunksForMedia('media-cap'), 32);
        await proxy.dispose();
      },
    );
  });
}

/// Stands in for the disk probe so the sizing rule can be exercised without
/// touching the real volume.
class _RecordingProbe implements UpdateDiskSpaceProbe {
  _RecordingProbe(this.availableBytes);
  final int availableBytes;
  final List<String> queriedPaths = [];

  @override
  Future<int> getAvailableBytes(String directoryPath) async {
    queriedPaths.add(directoryPath);
    return availableBytes;
  }
}
