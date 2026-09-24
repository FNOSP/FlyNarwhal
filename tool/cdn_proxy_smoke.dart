import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_http_range_source.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_proxy_service.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_range_session.dart';

import 'support/cdn_proxy_http_fixture.dart';

/// Run with `dart run tool/cdn_proxy_smoke.dart` from the repository root.
/// No Flutter engine, application state, credentials or external network is used.
Future<void> main() async {
  final fixture = await CdnProxyHttpFixture.start(
    totalBytes: 21 * fixtureMiB + 37,
    stallFirstBody: true,
  );
  final budget = CdnRangeBudget();
  final failures = <Object>[];
  final client = HttpClient()..findProxy = (_) => 'DIRECT';
  CdnProxyService createProxy() => CdnProxyService(
        source: CdnHttpRangeSource(),
        budget: budget,
        onError: failures.add,
      );
  final first = createProxy();
  final replacement = createProxy();
  StreamSubscription<List<int>>? abandonedBody;
  var bytesChecked = 0;
  try {
    final firstUri = await first.open(uri: fixture.uri, headers: const {});
    final pending = await client.getUrl(firstUri);
    pending.headers.set(HttpHeaders.rangeHeader, 'bytes=0-1048575');
    final response = await pending.close().timeout(const Duration(seconds: 5));
    _require(response.statusCode == HttpStatus.partialContent,
        'The proxy did not return Range response headers.');
    final firstPrefix = Completer<void>();
    abandonedBody = response.listen((data) {
      if (data.isNotEmpty && !firstPrefix.isCompleted) firstPrefix.complete();
    }, onError: (Object _) {});
    await firstPrefix.future.timeout(const Duration(seconds: 5));
    await fixture.firstBodyStarted.future.timeout(const Duration(seconds: 5));
    _require(
        budget.occupiedSlots > 0, 'The stalled request has no active lease.');
    await first.close().timeout(const Duration(seconds: 5));
    _require(first.activeWriterCount == 0 && budget.occupiedSlots == 0,
        'Closing an active request did not release writers and leases.');
    await first.close();

    final uri = await replacement.open(uri: fixture.uri, headers: const {});
    const start = 137;
    const end = 11 * fixtureMiB + 211;
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
    final ranged = await request.close().timeout(const Duration(seconds: 5));
    _require(ranged.statusCode == HttpStatus.partialContent,
        'The replacement proxy did not return HTTP 206.');
    _require(
        ranged.headers.value(HttpHeaders.contentRangeHeader) ==
            'bytes $start-$end/${fixture.totalBytes}',
        'Content-Range does not describe the requested interval.');
    _require(ranged.contentLength == end - start + 1,
        'Content-Length does not describe the requested interval.');
    _require(ranged.headers.contentType?.mimeType == 'application/octet-stream',
        'Content-Type was not preserved.');
    await for (final data in ranged.timeout(const Duration(seconds: 5))) {
      for (var i = 0; i < data.length; i++) {
        _require(data[i] == fixtureByteAt(start + bytesChecked + i),
            'The ranged body is corrupt or out of order.');
      }
      bytesChecked += data.length;
    }
    _require(bytesChecked == end - start + 1, 'The ranged body was truncated.');

    final head = await client.headUrl(uri);
    final headResponse = await head.close();
    _require(
        headResponse.statusCode == HttpStatus.ok &&
            headResponse.contentLength == fixture.totalBytes,
        'HEAD did not preserve resource length.');
    await headResponse.drain<void>();
    final invalid = await client.getUrl(uri);
    invalid.headers
        .set(HttpHeaders.rangeHeader, 'bytes=${fixture.totalBytes}-');
    final invalidResponse = await invalid.close();
    _require(
        invalidResponse.statusCode == HttpStatus.requestedRangeNotSatisfiable,
        'An out-of-bounds range was accepted.');
    _require(
        invalidResponse.headers.value(HttpHeaders.contentRangeHeader) ==
            'bytes */${fixture.totalBytes}',
        'HTTP 416 did not advertise the resource length.');
    await invalidResponse.drain<void>();
    await replacement.close().timeout(const Duration(seconds: 5));
    _require(replacement.activeWriterCount == 0 && budget.occupiedSlots == 0,
        'The replacement proxy did not release resources.');
    _require(failures.isEmpty, 'The proxy reported a playback failure.');
    _require(
        fixture.errors.isEmpty, 'The local fixture reported an I/O failure.');
    stdout.writeln(jsonEncode({
      'result': 'passed',
      'bytesVerified': bytesChecked,
      'rangeHeaders': true,
      'streamedBeforeStalledBodyCompleted': true,
      'activeRequestCancelled': true,
      'sharedBudgetReused': true,
      'occupiedAfterClose': budget.occupiedSlots,
      'writersAfterClose': replacement.activeWriterCount,
    }));
  } finally {
    await first.close();
    await replacement.close();
    await abandonedBody?.cancel();
    client.close(force: true);
    await fixture.close();
  }
}

void _require(bool condition, String message) {
  if (!condition) throw StateError(message);
}
