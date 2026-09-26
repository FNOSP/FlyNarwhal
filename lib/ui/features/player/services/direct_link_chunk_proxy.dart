import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/utils/log/app_talker.dart';
import '../../../../services/update/update_disk_space_probe.dart';

/// Upstream window size used when fetching bytes from the NAS media/range
/// proxy, in bytes.
///
/// The cloud CDN behind the original-quality tier of some netdisks throttles
/// any single range whose window exceeds roughly 393 MB down to about
/// 100 KB/s. Media players open a remote Matroska file with an open-ended
/// `bytes=0-` request that lands squarely in that throttled window, so every
/// upstream request issued here is clamped regardless of what the player
/// asked for.
///
/// The official Android player fetches 50 MB at a time, but it can afford to:
/// its fetches land in a disk cache that the demuxer reads from as they fill,
/// so playback starts after the first few kilobytes. This proxy has to hand a
/// complete chunk to the player before it can respond at all, which makes the
/// chunk size a direct startup latency: a 50 MB chunk measured ~7.5 s before
/// the response headers went out, and the player timed out waiting. 8 MB keeps
/// that latency near a second while staying well clear of the ~393 MB
/// throttle cliff.
const int directLinkChunkBytes = 8 * 1024 * 1024;

/// Starting number of simultaneous chunk downloads.
///
/// The count is no longer derived from a fixed per-connection figure: a
/// constant measured on one machine says nothing about a slower link, and
/// sizing from it either opened too many connections on a fast link or too few
/// on a slow one. Downloads are timed and the count moves in response to what
/// the link actually delivers, so the start value only has to be safe.
const int _initialConcurrentDownloads = 2;

/// Bounds on the number of simultaneous chunk downloads.
///
/// The floor keeps one connection on the wire so playback never stalls for
/// lack of a fetch. The ceiling caps the load a single session places on the
/// netdisk account; four was the highest count measured to still improve
/// aggregate throughput on a fast link.
const int _minConcurrentDownloads = 1;
const int _maxConcurrentDownloads = 4;

/// Throughput one upstream connection is *assumed* to deliver before any
/// measurement exists, in bytes per second.
///
/// Used only to decide whether the bitrate already justifies more than the
/// starting count. Once real samples exist they replace it. Deliberately low:
/// overestimating it would under-provision the connection count for the first
/// seconds of playback, which is the failure this replaced.
const int _assumedBytesPerConnectionPerSecond = 2000000;

/// How long traffic is accumulated before the throughput is read from it.
///
/// Four seconds is several chunks at the working sizes, so the figure is not
/// dominated by one slow transfer, while still short enough that a change in
/// link speed is acted on while playback is still in its first seconds.
const int _throughputMeasurementWindowMs = 4000;

/// Headroom factor applied to the stream bitrate when deciding how much
/// aggregate download throughput is enough.
const int _throughputHeadroomFactor = 2;

/// Ceiling on how far the concurrency probe may climb without having shown a
/// measurable throughput gain.
///
/// A low-bitrate stream needs one connection and must not be pushed to the
/// ceiling just to discover that extra connections add nothing: the netdisk
/// account would see every episode open four requests instead of one.
const int _maxUnproductiveProbes = 2;

/// Chunks kept on disk per session before the least recently used are removed,
/// outside the pinned head and tail regions.
///
/// The official player stores chunks as individual files and evicts them by
/// LRU once a cap is reached; this mirrors that, but sizes the cap from the
/// free space on the volume holding the cache rather than a fixed count, so a
/// machine short on disk is not asked for a fixed half gigabyte.
///
/// The share of free space is the official player's (half of what is
/// available, capped at 1 GB); the floor is this implementation's, because a
/// cache smaller than a few chunks cannot cover a seek at all.
const double _maxDiskShareOfFreeSpace = 0.5;
const int _maxDiskCacheBytesCap = 1024 * 1024 * 1024;
const int _maxDiskCacheBytesFloor = 256 * 1024 * 1024;

/// Chunk cap used when the free-space query fails, matching the previous fixed
/// 512 MB so behaviour on such a machine is unchanged.
const int _fallbackMaxDiskChunks = 64;

/// How often the free-space query is repeated while a session is running.
///
/// Repeating it matters because the cache is released the moment playback
/// stops: a long pause followed by more playback would otherwise keep filling
/// toward a total that is no longer accurate.
const Duration _diskSpaceRefreshInterval = Duration(minutes: 2);

/// Chunks pinned at each end of the file, never evicted.
///
/// The player probes the container head and the tail index repeatedly while it
/// settles — measured at eight separate reads of the head and four of the tail
/// — and each retry is a fresh network fetch unless the bytes are still
/// cached. Two chunks per end covers the EBML head and the Cues index while
/// keeping the fixed reservation small relative to the rolling region.
const int _pinnedChunksPerEnd = 2;

/// Sessions without traffic for this long are dropped.
const Duration _sessionIdleTimeout = Duration(minutes: 15);

/// Upper bound on simultaneous sessions held open.
const int _maxSessions = 4;

/// Number of attempts a single window download gets before it is reported as
/// failed.
///
/// The official player retries a chunk three times before giving up on it, and
/// a cloud CDN does drop the occasional request. Retrying here keeps a
/// transient failure from surfacing to the player, which can only respond by
/// re-issuing the whole range.
const int _windowFetchAttempts = 3;

/// Delay before the second and later attempts at the same window.
///
/// A short backoff, not a timeout: the goal is to let a dropped connection
/// clear rather than to wait out a slow one.
const Duration _windowFetchRetryDelay = Duration(milliseconds: 300);

/// Largest span served to a single open-ended request.
///
/// An open-ended request (`bytes=N-`, or no Range header at all) is how a
/// player says "give me everything from here on". Answering it with the whole
/// file keeps one connection streaming for minutes: the player gets its header
/// slowly, opens another connection to make progress, and the appended
/// connections then compete for the same upstream link and slow the first one
/// further. Bounding the answer turns every request into a short, promptly
/// completed transfer that the player extends on demand, which is also how the
/// web player drives the same endpoint. Large files are unaffected: the player
/// simply issues the next range when it reaches the end of this one.
///
/// Sized to cover several chunks so a normal sequential read is served without
/// the player having to re-request after every single one.
const int _maxOpenEndedSpanBytes = 4 * directLinkChunkBytes;

/// Path prefix that identifies a loopback chunk-proxy playback URL.
const String _proxyPathPrefix = '/direct-link-stream/';

/// Whether [playUri] points at a session served by [DirectLinkChunkProxy]
/// rather than directly at the NAS.
bool isDirectLinkChunkProxyUrl(String playUri) {
  return playUri.contains(_proxyPathPrefix);
}

/// Per-playback state for one upstream media/range URL.
class _ChunkSession {
  _ChunkSession({
    required this.id,
    required this.mediaGuid,
    required this.upstreamUri,
    required this.headers,
    required this.cacheDir,
    required this.bitrate,
  });

  final String id;
  final String mediaGuid;
  final Uri upstreamUri;
  final Map<String, String> headers;

  /// Directory holding this session's chunk files. Chunks are written here as
  /// `chunk_<index>.bin` so a seek back into an already-downloaded region is
  /// served from disk instead of the netdisk, and so the memory footprint does
  /// not grow with the size of the file.
  final Directory cacheDir;

  /// Source bitrate in bits per second, used to size download concurrency.
  /// Zero when the backend does not report one.
  final int bitrate;

  int? totalBytes;
  /// In-flight length probe, so two connections opening the same session at
  /// the same time share one HEAD-equivalent request instead of each probing
  /// and then racing into the first window fetch.
  Future<int>? _totalProbe;
  String contentType = 'application/octet-stream';
  DateTime lastAccess = DateTime.now();
  bool closed = false;

  /// Cumulative bytes pulled from the network for this session.
  ///
  /// Only upstream reads count: windows served from [_cache] cost no
  /// bandwidth, so the served-to-player rate would overstate the network
  /// throughput whenever the player re-reads a region.
  int fetchedBytes = 0;

  /// Bytes pulled since the current measurement window opened.
  ///
  /// The rate the concurrency is sized from is an aggregate one: bytes counted
  /// as they arrive, divided by the wall-clock time the window covered. Timing
  /// single transfers instead would not work, because with several downloads
  /// in flight each one runs slower than the link does — a per-transfer rate
  /// reports roughly the aggregate divided by the connection count, which
  /// reads as "the link is too slow" on a link that is already saturated and
  /// would drive the count up without limit.
  int _windowBytes = 0;

  /// When the current measurement window opened, in milliseconds since the
  /// epoch; zero before the first window download completes.
  int _windowStartedAtMs = 0;

  /// Aggregate bytes per second over the last completed measurement window, or
  /// null before enough traffic has been observed.
  double? _measuredBytesPerSecond;

  /// Current number of simultaneous downloads allowed for this session.
  ///
  /// Moves up while the link is not keeping up with the bitrate and down when
  /// it has headroom, bounded by [_minConcurrentDownloads] and
  /// [_maxConcurrentDownloads].
  int _downloadConcurrency = _initialConcurrentDownloads;

  /// Whether a probe step is still pending an observation.
  ///
  /// A step up is only kept if it made aggregate throughput measurably better;
  /// counting the steps that did not teaches the session to stop raising the
  /// count on a link where extra connections do not help.
  int _unproductiveProbes = 0;
  bool _probePending = false;

  /// Aggregate throughput measured before the last step up, in bytes per
  /// second, used as the baseline the step has to beat.
  double _preProbeThroughput = 0;

  /// Chunk cap derived from the free space on the cache volume.
  ///
  /// Re-resolved periodically because the cache is dropped when playback
  /// stops, so the free space seen at session start can be stale by the time
  /// the cache has been filling for a while.
  int maxDiskChunks = _fallbackMaxDiskChunks;
  DateTime? _diskSpaceResolvedAt;

  // ── TEMPORARY fetch probe ────────────────────────────────────────────────
  // Measures why a 261 MB episode pulled ~2 GB off the network. Counts how
  // often each 8 MB window is fetched, so the log shows whether the over-read
  // is sequential (a normal full pass) or repeated (the same windows again).
  // Remove once the cause is known.
  int fetchCount = 0;
  int activeRequests = 0;
  /// TEMPORARY: how many upstream fetches were avoided by the cache.
  int cacheHits = 0;
  final Map<int, int> windowFetchCounts = {};
  final List<int> recentWindows = [];

  /// Aborts the upstream reads that are already in flight.
  ///
  /// Flipping [closed] only stops the *next* window: an 8 MB read already on
  /// the wire would still finish, and a player that keeps the connection open
  /// could hold the loopback response past the end of the session. Cancelling
  /// tears the upstream transfer down immediately instead.
  final CancelToken cancelToken = CancelToken();

  /// Chunk indices present on disk, oldest first by last use.
  ///
  /// Order doubles as the LRU list: a hit or a store moves its index to the
  /// end, and eviction drops from the front while skipping pinned entries.
  final List<int> _cachedIndices = [];
  /// Chunk indices from the pinned head/tail regions, which eviction skips.
  /// Populated once the total length is known.
  final Set<int> _pinnedIndices = {};

  File _chunkFile(int index) =>
      File('${cacheDir.path}${Platform.pathSeparator}chunk_$index.bin');

  /// Sets the starting concurrency from the bitrate alone.
  ///
  /// There is no measurement yet at this point, so the count is a guess, but a
  /// cheap one: a stream whose bitrate a single connection can obviously carry
  /// starts at one, and a higher-bitrate one starts at the initial count. The
  /// guess is corrected within a measurement window by [recordNetworkWindow].
  void seedConcurrency() {
    if (bitrate <= 0) {
      _downloadConcurrency = _initialConcurrentDownloads;
      return;
    }
    final required = bitrate ~/ 8 * _throughputHeadroomFactor;
    _downloadConcurrency = required <= _assumedBytesPerConnectionPerSecond
        ? _minConcurrentDownloads
        : _initialConcurrentDownloads;
  }

  /// Whether the chunk cap is due to be re-resolved.
  ///
  /// Checked instead of a timer so the refresh rides along with activity the
  /// session is already doing rather than holding a timer of its own.
  bool get diskCapRefreshDue {
    final resolvedAt = _diskSpaceResolvedAt;
    if (resolvedAt == null) return true;
    return DateTime.now().difference(resolvedAt) >= _diskSpaceRefreshInterval;
  }

  /// Updates the chunk cap from [availableBytes] on the cache volume.
  ///
  /// The cap is the official player's rule — half the free space, capped at
  /// 1 GB — with a floor so a machine with little room to spare still gets a
  /// cache large enough to cover a seek. A query that fails or reports nothing
  /// leaves the previous cap in place.
  void applyAvailableBytes(int available, {required int nowMillis}) {
    _diskSpaceResolvedAt = DateTime.fromMillisecondsSinceEpoch(nowMillis);
    if (available <= 0) return;
    var budget = (available * _maxDiskShareOfFreeSpace).round();
    if (budget > _maxDiskCacheBytesCap) budget = _maxDiskCacheBytesCap;
    if (budget < _maxDiskCacheBytesFloor) budget = _maxDiskCacheBytesFloor;
    maxDiskChunks = (budget ~/ directLinkChunkBytes).clamp(
      _pinnedChunksPerEnd * 2,
      _fallbackMaxDiskChunks * 8,
    );
  }

  /// Number of chunk downloads to keep in flight for this stream.
  ///
  /// Read by the send loop before every window, so a change made by
  /// [_adjustConcurrency] takes effect on the next window rather than at the
  /// next session.
  int get downloadConcurrency => _downloadConcurrency;

  /// Aggregate bytes per second over the last completed measurement window.
  double? get measuredBytesPerSecond => _measuredBytesPerSecond;

  /// Records one completed window download and, once a measurement window has
  /// elapsed, moves the concurrency in response.
  ///
  /// Windows served from cache are not recorded: they measure the disk, not
  /// the link. [millis] is the transfer's own duration, used only to anchor
  /// the very first measurement — the window it opens starts when that
  /// transfer did, so a single slow first window is not divided by a span it
  /// did not occupy.
  void recordNetworkWindow(int bytes, int millis) {
    if (bytes <= 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_windowStartedAtMs == 0) {
      _windowStartedAtMs = now - millis;
    }
    _windowBytes += bytes;
    final span = now - _windowStartedAtMs;
    if (span < _throughputMeasurementWindowMs) return;
    final measured = _windowBytes * 1000 / span;
    _measuredBytesPerSecond = measured;
    _windowBytes = 0;
    _windowStartedAtMs = now;
    _adjustConcurrency(measured);
  }

  /// Moves the concurrency in response to [measured] aggregate throughput.
  void _adjustConcurrency(double measured) {
    if (_probePending) {
      // Settle the pending step: keep it if it bought throughput, give up on
      // climbing once enough steps have been tried without a gain.
      _probePending = false;
      if (measured > _preProbeThroughput * 1.15) {
        _unproductiveProbes = 0;
      } else {
        _unproductiveProbes++;
      }
      return;
    }

    if (bitrate <= 0) return;
    // bits/s to bytes/s, with headroom so playback is not riding the edge.
    final required = bitrate ~/ 8 * _throughputHeadroomFactor;
    final atFloor = _downloadConcurrency <= _minConcurrentDownloads;
    final atCeiling = _downloadConcurrency >= _maxConcurrentDownloads;

    if (measured < required && !atCeiling) {
      if (_unproductiveProbes >= _maxUnproductiveProbes) return;
      _preProbeThroughput = measured;
      _probePending = true;
      _downloadConcurrency++;
      return;
    }
    // Drop only on a clear surplus, so a link sitting near the required rate
    // does not oscillate between two counts.
    if (measured > required * 2 && !atFloor) {
      _downloadConcurrency--;
      _unproductiveProbes = 0;
    }
  }

  /// Reads chunk [index] from disk, or null when it is not cached.
  ///
  /// Synchronous: the caller is a loop already doing async network work, the
  /// files are local, and a failed read has to fall back to the network
  /// immediately rather than interleave with other awaits.
  Uint8List? take(int index) {
    if (!_cachedIndices.contains(index)) return null;
    final file = _chunkFile(index);
    try {
      if (!file.existsSync()) {
        _cachedIndices.remove(index);
        return null;
      }
      final data = file.readAsBytesSync();
      if (data.isEmpty) {
        _cachedIndices.remove(index);
        return null;
      }
      _touch(index);
      cacheHits++;
      return data;
    } catch (_) {
      _cachedIndices.remove(index);
      return null;
    }
  }

  /// Moves [index] to the most-recently-used end of the eviction order.
  void _touch(int index) {
    _cachedIndices.remove(index);
    _cachedIndices.add(index);
  }

  /// Writes chunk [index] to disk and enforces the cache cap.
  void store(int index, Uint8List data) {
    try {
      final temp = File('${_chunkFile(index).path}.tmp');
      temp.writeAsBytesSync(data, flush: true);
      temp.renameSync(_chunkFile(index).path);
      _touch(index);
    } catch (_) {
      // A failed write only costs a future network read; keep playback going.
      return;
    }
    _evictUnpinned(index);
  }

  /// Removes least recently used unpinned chunks until the cache fits
  /// [maxDiskChunks].
  void _evictUnpinned(int justStored) {
    // The pinned head and tail count toward the cap like any other chunk; they
    // are simply never the ones chosen for eviction.
    while (_cachedIndices.length > maxDiskChunks) {
      final candidate = _cachedIndices.firstWhere(
        (key) => !_pinnedIndices.contains(key),
        orElse: () => justStored,
      );
      if (candidate == justStored) return;
      _cachedIndices.remove(candidate);
      try {
        _chunkFile(candidate).deleteSync();
      } catch (_) {
        // Leaving the file behind is harmless; the index list is the truth.
      }
    }
  }

  /// In-flight upstream reads keyed by window index.
  ///
  /// The player opens several overlapping reads at once, and during that first
  /// burst none of them is in the cache yet, so each one used to start its own
  /// upstream fetch for the same window. Joining the running read collapses
  /// them to one fetch.
  ///
  /// An entry stays here until the fetch has also finished writing the chunk
  /// to disk. Removing it the moment the future completes leaves a gap: the
  /// bytes are in memory but not yet in [_cachedIndices], so a connection
  /// arriving in that gap starts a duplicate fetch. The cleanup runs from the
  /// same synchronous [store] path, so by the time the entry disappears the
  /// cache index is authoritative.
  final Map<int, Future<Uint8List?>> _inFlight = {};

  /// Marks the head and tail windows of a file of [totalBytes] as pinned.
  void pinEnds(int totalBytes) {
    if (_pinnedIndices.isNotEmpty || totalBytes <= 0) return;
    final lastIndex = (totalBytes - 1) ~/ directLinkChunkBytes;
    for (var i = 0; i < _pinnedChunksPerEnd; i++) {
      _pinnedIndices.add(i);
      final tailIndex = lastIndex - i;
      if (tailIndex > i) _pinnedIndices.add(tailIndex);
    }
  }

  /// The read already running for [index], if any.
  Future<Uint8List?>? inFlightFor(int index) => _inFlight[index];

  /// Whether [index] is either cached on disk or currently being fetched.
  ///
  /// The caller checks this before starting a fetch; it covers the gap between
  /// a fetch completing and its chunk landing in [_cachedIndices].
  bool isCachedOrInFlight(int index) =>
      _cachedIndices.contains(index) || _inFlight.containsKey(index);

  /// Publishes [operation] as the read for [index].
  ///
  /// Registration happens before the caller's first await, so a connection
  /// arriving later in the same event-loop turn finds the entry and joins
  /// instead of starting a duplicate fetch.
  void registerInFlight(int index, Future<Uint8List?> operation) {
    _inFlight[index] = operation;
    unawaited(
      operation.whenComplete(() {
        // Keep the entry while the completed bytes make their way into the
        // cache index. A successful fetch calls store() before completing, so
        // by this point the index is already updated; a failed fetch leaves no
        // cache entry and is dropped immediately.
        scheduleMicrotask(() {
          if (identical(_inFlight[index], operation)) {
            _inFlight.remove(index);
          }
        });
      }),
    );
  }

}

/// Serves a cloud direct-link stream to the player over loopback, re-fetching
/// the upstream bytes in bounded windows.
///
/// The player cannot be pointed at the NAS range proxy directly: it opens the
/// stream with an open-ended range request, which the cloud CDN throttles to
/// roughly 1/200 of the available bandwidth, so the container header never
/// arrives and playback verification times out. Serving the player from a
/// loopback endpoint lets the player keep issuing whatever ranges it likes
/// while this class decides the upstream request shape.
///
/// Only the desktop targets are supported; this relies on `dart:io`.
class DirectLinkChunkProxy {
  DirectLinkChunkProxy({
    required Dio dio,
    String? Function()? supportDirectory,
    UpdateDiskSpaceProbe diskSpaceProbe = const IoUpdateDiskSpaceProbe(),
  })  : _dio = dio,
        _supportDirectoryProvider = supportDirectory,
        _diskSpaceProbe = diskSpaceProbe;

  final Dio _dio;
  /// Supplies the parent directory for the chunk cache; null falls back to a
  /// temp directory. Injected rather than looked up here so this class stays
  /// free of platform plugins and remains unit-testable.
  final String? Function()? _supportDirectoryProvider;
  /// Answers how much space the cache volume has left. Used to size the chunk
  /// cap; injected so the sizing rule is testable without touching the disk.
  final UpdateDiskSpaceProbe _diskSpaceProbe;
  final Map<String, _ChunkSession> _sessions = {};
  HttpServer? _server;
  Future<void>? _pendingStart;
  int _port = 0;
  /// Throttle state for the temporary request probe.
  DateTime? _lastRequestLogAt;
  /// Counter behind the temporary per-connection probe ids.
  int _connectionCounter = 0;
  /// Root of the on-disk chunk cache, resolved on first use.
  Directory? _cacheRootDirectory;
  /// TEMPORARY: when the previous player request arrived, plus a count of how
  /// often each requested start offset has been asked for. Together these show
  /// whether the player is advancing through the file or re-requesting the
  /// same spans, and how long it waits between attempts.
  DateTime? _previousRequestAt;
  final Map<int, int> _requestCountsByStart = {};
  int _requestCount = 0;

  /// Registers [upstreamUrl] and returns the loopback URL to hand the player.
  Future<String> registerSession({
    required String mediaGuid,
    required String upstreamUrl,
    required Map<String, String> headers,
    int bitrate = 0,
  }) async {
    await _ensureServer();
    await releaseSessionsForMedia(mediaGuid);
    _dropIdleSessions();
    // One directory per session, mirroring the official player's per-video
    // cache but keyed by the session rather than only the media: the media
    // guid is stable across plays, so two sessions for the same title would
    // otherwise write the same `chunk_<index>.bin` paths. Releasing the media
    // still drops the whole tree, so nothing is left behind.
    final sessionId = _newSessionId();
    final cacheDir = Directory(
      '${_cacheRoot().path}${Platform.pathSeparator}$mediaGuid'
      '${Platform.pathSeparator}$sessionId',
    );
    try {
      if (cacheDir.existsSync()) {
        cacheDir.deleteSync(recursive: true);
      }
      cacheDir.createSync(recursive: true);
    } catch (_) {
      // Without a writable directory the proxy still works; every read simply
      // falls through to the network.
    }
    final session = _ChunkSession(
      id: sessionId,
      mediaGuid: mediaGuid,
      upstreamUri: Uri.parse(upstreamUrl),
      headers: Map<String, String>.from(headers),
      cacheDir: cacheDir,
      bitrate: bitrate,
    );
    session.seedConcurrency();
    _sessions[session.id] = session;
    unawaited(_refreshDiskCap(session));
    _evictExcessSessions();
    AppTalker.info(
      'Player',
      'direct-link chunk proxy registered: guid=$mediaGuid items='
          '${upstreamUrl.contains('direct_link_quality_index') ? 'quality' : 'default'}',
    );
    return 'http://127.0.0.1:$_port$_proxyPathPrefix${session.id}';
  }

  /// Cumulative network bytes pulled for [mediaGuid] since its current session
  /// was registered, or null when no session is serving that media.
  ///
  /// Callers sample this over time to show the live netdisk throughput; the
  /// value only advances when a window actually comes off the network.
  int? fetchedBytesForMedia(String mediaGuid) {
    for (final session in _sessions.values) {
      if (session.mediaGuid == mediaGuid) return session.fetchedBytes;
    }
    return null;
  }

  /// Re-resolves [session]'s chunk cap from the cache volume's free space.
  ///
  /// Failures are swallowed: without an answer the session keeps the fallback
  /// cap and playback is unaffected.
  Future<void> _refreshDiskCap(_ChunkSession session) async {
    if (!session.diskCapRefreshDue) return;
    try {
      final available = await _diskSpaceProbe.getAvailableBytes(
        session.cacheDir.path,
      );
      session.applyAvailableBytes(
        available,
        nowMillis: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // Keep the previous cap.
    }
  }

  /// Resolves the stream length, sharing one probe between connections that
  /// arrive while a probe is already running.
  ///
  /// Without this, two connections opening the same fresh session both see
  /// `totalBytes == null`, both probe, and then both race into the first
  /// window fetch before either has published its in-flight marker. Sharing
  /// the probe makes their downstream progress deterministic: the second
  /// connection cannot leave the shared await before the first has the length
  /// cached and its first window fetch underway.
  Future<int> _probeTotalShared(_ChunkSession session) {
    final running = session._totalProbe;
    if (running != null) return running;
    final probe = _probeTotal(session);
    session._totalProbe = probe;
    return probe.whenComplete(() {
      if (identical(session._totalProbe, probe)) {
        session._totalProbe = null;
      }
    });
  }

  /// Drops every session for [mediaGuid] so a superseded quality switch or a
  /// reload cannot keep streaming in the background.
  Future<void> releaseSessionsForMedia(String mediaGuid) async {
    final stale = _sessions.values
        .where((session) => session.mediaGuid == mediaGuid)
        .toList(growable: false);
    if (stale.isEmpty) return;
    for (final session in stale) {
      _closeSession(session);
      _sessions.remove(session.id);
    }
    // Logged so a switch/exit can be confirmed to drop the upstream transfer
    // immediately instead of leaving it to the idle timeout. The totals are
    // included because the periodic summary only fires every 64 fetches, so a
    // short session otherwise ends without any record of what it downloaded.
    final totalFetched = stale.fold<int>(
      0,
      (sum, session) => sum + session.fetchedBytes,
    );
    final totalFetches = stale.fold<int>(
      0,
      (sum, session) => sum + session.fetchCount,
    );
    AppTalker.info(
      'Player',
      'direct-link chunk proxy released ${stale.length} session(s): '
          'guid=$mediaGuid '
          'fetchedMB=${(totalFetched / 1048576).round()} '
          'fetches=$totalFetches',
    );
  }

  Future<void> releaseAllSessions() async {
    for (final session in _sessions.values) {
      _closeSession(session);
    }
    _sessions.clear();
  }

  /// Marks [session] closed and aborts its in-flight upstream reads.
  void _closeSession(_ChunkSession session) {
    session.closed = true;
    if (!session.cancelToken.isCancelled) {
      session.cancelToken.cancel('direct-link session released');
    }
    // Drop the on-disk chunks with the session: the cache exists to cover
    // seeks within one playback, and leaving it behind would accumulate a
    // directory for every playback ever started. The per-media parent is
    // removed only once it is empty, so a sibling session still serving the
    // same title keeps its bytes.
    try {
      final dir = session.cacheDir;
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      _pruneEmptyDirectory(dir.parent);
    } catch (_) {
      // A leftover directory is reclaimed the next time this guid is played.
    }
  }

  /// Deletes [directory] when it has no entries left.
  ///
  /// Used to clear the per-media directory once its last session's chunk
  /// directory is gone; a directory still holding a sibling session's files
  /// fails the emptiness check and is left alone.
  void _pruneEmptyDirectory(Directory directory) {
    try {
      if (directory.existsSync() && directory.listSync().isEmpty) {
        directory.deleteSync();
      }
    } catch (_) {
      // Leftovers are reclaimed the next time this media is played.
    }
  }

  Future<void> dispose() async {
    await releaseAllSessions();
    final server = _server;
    _server = null;
    _port = 0;
    try {
      await server?.close(force: true);
    } catch (_) {
      // The listener may already be gone during app shutdown.
    }
  }

  Future<void> _ensureServer() async {
    if (_server != null) return;
    final pending = _pendingStart;
    if (pending != null) return pending;
    final start = _startServer();
    _pendingStart = start;
    try {
      await start;
    } finally {
      _pendingStart = null;
    }
  }

  Future<void> _startServer() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.autoCompress = false;
    _server = server;
    _port = server.port;
    server.listen(
      (request) => unawaited(_handleRequest(request)),
      onError: (Object error, StackTrace stackTrace) {
        AppTalker.error(
          'Player',
          error: error,
          stackTrace: stackTrace,
          message: 'direct-link chunk proxy listener error',
        );
      },
    );
    AppTalker.info(
      'Player',
      'direct-link chunk proxy listening on 127.0.0.1:$_port',
    );
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;
    // TEMPORARY: identify each player connection so the probe can tell eight
    // concurrent reads apart from one read that stalls.
    final connectionId = ++_connectionCounter;
    final openedAt = DateTime.now();
    var sentBytes = 0;
    final sentWindows = <int>[];
    // Whether the status line has been committed. HttpResponse gives no way to
    // ask, and setting statusCode after the headers are on the wire throws, so
    // the fact has to be tracked here.
    var statusCommitted = false;
    try {
      final session = _sessionForPath(request.uri.path);
      if (session == null) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      session.lastAccess = DateTime.now();

      final total = session.totalBytes ?? await _probeTotalShared(session);
      session.totalBytes = total;
      // With the length known, the windows the player probes repeatedly can be
      // pinned so retries are served from memory instead of the network.
      session.pinEnds(total);
      // Ride the disk-cap refresh along with the traffic already happening,
      // rather than holding a timer for it.
      unawaited(_refreshDiskCap(session));

      if (request.method == 'HEAD') {
        response.statusCode = HttpStatus.ok;
        response.headers.contentType = _parseContentType(session.contentType);
        response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        response.headers.contentLength = total;
        await response.close();
        return;
      }

      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      var start = 0;
      var end = total - 1;
      if (rangeHeader != null) {
        final parsed = _parseRange(rangeHeader, total);
        if (parsed == null) {
          // Report the real length on an unsatisfiable range so the player
          // retries against a valid window instead of treating the whole
          // source as broken.
          response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes */$total',
          );
          await response.close();
          return;
        }
        start = parsed.start;
        end = parsed.end;
      }
      // Bound the span actually served. A player asking for "everything from
      // here" is answered with one bounded chunk and then asks for the next
      // one; serving the whole file instead keeps a single connection busy for
      // minutes and provokes the extra parallel connections that made a 262 MB
      // episode pull over 1 GB.
      final wasOpenEnded = end >= total - 1;
      if (wasOpenEnded) {
        end = math.min(end, start + _maxOpenEndedSpanBytes - 1);
      }
      final length = end - start + 1;

      // Fetch the first window before committing the status line: once the
      // headers are on the wire an upstream failure can only be reported as a
      // truncated body, which the player would retry against the same broken
      // window. Probing first lets a genuine upstream error surface as 502.
      final firstIndex = start ~/ directLinkChunkBytes;
      final firstWindowStart = firstIndex * directLinkChunkBytes;
      final firstWindowEnd =
          math.min(firstWindowStart + directLinkChunkBytes, total) - 1;
      final firstData = await _fetchWindow(
        session,
        firstIndex,
        firstWindowStart,
        firstWindowEnd,
      );
      if (firstData == null) {
        AppTalker.warning(
          'Player',
          'direct-link chunk proxy upstream unavailable: '
              'index=$firstIndex bytes=$firstWindowStart-$firstWindowEnd',
        );
        response.statusCode = HttpStatus.badGateway;
        await response.close();
        return;
      }

      response.headers.contentType = _parseContentType(session.contentType);
      response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      if (rangeHeader == null) {
        // A bounded answer to an unbounded request is still a partial
        // response; advertising 200 with a short body would make the player
        // believe it received the whole file.
        if (wasOpenEnded) {
          response.statusCode = HttpStatus.partialContent;
          response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $start-$end/$total',
          );
        } else {
          response.statusCode = HttpStatus.ok;
        }
      } else {
        response.statusCode = HttpStatus.partialContent;
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/$total',
        );
      }
      response.headers.contentLength = length;

      statusCommitted = true;
      _logIncomingRequest(
        connectionId,
        session,
        start,
        length,
        rangeHeader,
      );
      _traceRequest(connectionId, start, length);
      await _streamRange(
        connectionId,
        session,
        response,
        start,
        length,
        total,
        firstIndex,
        firstData,
        onWindowSent: (index, bytes) {
          sentBytes += bytes;
          sentWindows.add(index);
        },
      );
      _logConnectionClosed(
        connectionId,
        'completed',
        openedAt,
        sentBytes,
        sentWindows,
      );
    } catch (error, stackTrace) {
      _logConnectionClosed(
        connectionId,
        'failed: ${error.runtimeType}',
        openedAt,
        sentBytes,
        sentWindows,
      );
      if (!_isClientDisconnect(error)) {
        AppTalker.error(
          'Player',
          error: error,
          stackTrace: stackTrace,
          message: 'direct-link chunk proxy request failed',
        );
        // Report an upstream failure as such when the status line has not gone
        // out yet. Closing without a status would send the player a 200 with an
        // empty body, which reads as "this file is empty" rather than "try
        // again"; a player that concludes the source is empty gives up on it.
        if (!statusCommitted) {
          try {
            response.statusCode = HttpStatus.badGateway;
          } catch (_) {
            // Headers turned out to be committed after all; the close below
            // still ends the request.
          }
        }
      }
      try {
        await response.close();
      } catch (_) {
        // The client is already gone.
      }
    }
  }

  /// Streams [length] bytes starting at [start], fetching one bounded upstream
  /// window at a time so a large player request never turns into a large
  /// upstream request.
  Future<void> _streamRange(
    int connectionId,
    _ChunkSession session,
    HttpResponse response,
    int start,
    int length,
    int total,
    int firstIndex,
    Uint8List firstData,
    {
    required void Function(int index, int bytes) onWindowSent,
  }
  ) async {
    var position = start;
    var remaining = length;
    final startedAt = DateTime.now();
    var sentWindows = 0;
    // Chunks are fetched ahead of the send loop so several upstream reads are
    // in flight at once: one netdisk connection cannot outrun a high-bitrate
    // remux, and the send loop must still emit bytes strictly in order.
    final pipeline = <int, Future<Uint8List?>>{};
    // Whether the window the loop is about to send still has to be fetched.
    //
    // While that is the case the read-ahead stays shut, so the fetch gating the
    // first byte is not competing with its own successors for the link: on a
    // path where the upstream shares one pipe between connections, opening the
    // read-ahead here would slow this fetch down and delay the response. Once
    // the window is in hand, bandwidth spent ahead of the playhead costs
    // nothing, and the read-ahead opens.
    var gateFirstWindow = false;
    try {
      while (remaining > 0) {
        if (session.closed) {
          AppTalker.info(
            'Player',
            'chunk probe conn=$connectionId stopped: session closed '
                'after ${DateTime.now().difference(startedAt).inMilliseconds}ms '
                'sent=$sentWindows window(s)',
          );
          break;
        }
        final index = position ~/ directLinkChunkBytes;
        final windowStart = index * directLinkChunkBytes;
        final windowEnd =
            math.min(windowStart + directLinkChunkBytes, total) - 1;
        // While the window the loop is about to send still has to be fetched,
        // the read-ahead stays shut so that fetch is not competing with its own
        // successors for the link: on a path where the upstream shares one pipe
        // between connections, opening the read-ahead here would slow this
        // fetch down and delay the bytes the player is waiting for. Once the
        // window is in hand the read-ahead opens, because bytes spent ahead of
        // the playhead cost nothing.
        gateFirstWindow = !(index == firstIndex ||
            pipeline.containsKey(index) ||
            session.take(index) != null);
        _scheduleAhead(
          session: session,
          pipeline: pipeline,
          fromIndex: index + (gateFirstWindow ? 1 : 0),
          total: total,
        );
        final Uint8List? data;
        final fetchStartedAt = DateTime.now();
        if (index == firstIndex) {
          pipeline.remove(index);
          data = firstData;
        } else {
          final scheduled = pipeline.remove(index);
          data = scheduled != null
              ? await scheduled
              : await _fetchWindow(session, index, windowStart, windowEnd);
        }
        final fetchMs =
            DateTime.now().difference(fetchStartedAt).inMilliseconds;
        if (data == null) {
          AppTalker.info(
            'Player',
            'chunk probe conn=$connectionId no data for window $index '
                'after ${fetchMs}ms (sent=$sentWindows)',
          );
          break;
        }
        // TEMPORARY: log every window fetch's cost and position. The earlier
        // run showed the same 32 MB span taking 3s near the file start and 48s
        // near the end, so the position of each slow fetch matters as much as
        // its duration.
        if (fetchMs > 1500) {
          AppTalker.info(
            'Player',
            'chunk slow conn=$connectionId window=$index '
                'atMB=${(windowStart / 1048576).round()} '
                'ofMB=${(total / 1048576).round()} '
                'took=${fetchMs}ms',
          );
        }
        final offset = position - windowStart;
        if (offset >= data.length) break;
        final take = math.min(remaining, data.length - offset);
        if (take <= 0) break;
        response.add(data.sublist(offset, offset + take));
        // Flush per window so a slow player throttles the upstream fetches
        // instead of letting unanswered bytes pile up in memory.
        await response.flush();
        onWindowSent(index, take);
        sentWindows++;
        position += take;
        remaining -= take;
      }
      pipeline.clear();
      AppTalker.info(
        'Player',
        'chunk probe conn=$connectionId stream loop ended: '
            'sent=$sentWindows window(s) remaining=${(remaining / 1048576).toStringAsFixed(1)}MB '
            'elapsed=${DateTime.now().difference(startedAt).inMilliseconds}ms',
      );
    } finally {
      // A truncated body must still close cleanly; the player sees a short
      // read and re-issues a fresh range for the region it still needs.
      try {
        await response.close();
      } catch (_) {
        // The player already dropped the connection.
      }
    }
  }

  /// Keeps up to [ChunkSession.downloadConcurrency] chunk reads in flight
  /// ahead of the send position.
  ///
  /// Only the fetch is started here; the send loop still awaits each future in
  /// order, so bytes reach the player sequentially. Requests already running
  /// for the same chunk are joined rather than duplicated.
  void _scheduleAhead({
    required _ChunkSession session,
    required Map<int, Future<Uint8List?>> pipeline,
    required int fromIndex,
    required int total,
  }) {
    if (session.closed) return;
    final lastIndex = (total - 1) ~/ directLinkChunkBytes;
    final concurrency = session.downloadConcurrency;
    for (var ahead = 0;
        ahead < concurrency && pipeline.length < concurrency;
        ahead++) {
      final index = fromIndex + ahead;
      if (index > lastIndex || pipeline.containsKey(index)) continue;
      if (session.take(index) != null) continue;
      final windowStart = index * directLinkChunkBytes;
      final windowEnd =
          math.min(windowStart + directLinkChunkBytes, total) - 1;
      pipeline[index] = _fetchWindow(session, index, windowStart, windowEnd);
    }
  }

  /// Fetches one bounded window, preferring the session cache.
  Future<Uint8List?> _fetchWindow(
    _ChunkSession session,
    int index,
    int start,
    int end,
  ) async {
    // One check covers both states: a chunk already on disk, and one whose
    // fetch is still running. A window fetched but not yet written to the
    // cache index used to slip through as "missing", causing the next
    // connection to download it again.
    if (session.isCachedOrInFlight(index)) {
      final cached = session.take(index);
      if (cached != null) return cached;
      final running = session.inFlightFor(index);
      if (running != null) return running;
    }
    if (session.closed) return null;
    // Join a read another connection already started for this window. The
    // deduplication is deliberately scoped to the upstream fetch only: each
    // caller still receives its own copy below and streams it to its own
    // player connection, so a caller that arrives or departs mid-read cannot
    // leave another connection's response unfinished.
    final running = session.inFlightFor(index);
    if (running != null) return running;
    final operation = _fetchWindowFromUpstream(session, index, start, end);
    session.registerInFlight(index, operation);
    return operation;
  }

  /// Performs the upstream read behind [_fetchWindow], retrying a failed
  /// window before giving up on it.
  ///
  /// The official player retries each chunk three times, and a cloud CDN does
  /// drop the occasional request. Surfacing a transient failure to the player
  /// costs far more than a retry: the player can only answer by re-issuing the
  /// whole range. A cancelled session is not retried, because those reads were
  /// abandoned deliberately.
  Future<Uint8List?> _fetchWindowFromUpstream(
    _ChunkSession session,
    int index,
    int start,
    int end,
  ) async {
    for (var attempt = 1; attempt <= _windowFetchAttempts; attempt++) {
      final result = await _attemptWindowFetch(session, index, start, end);
      if (result != null) return result;
      if (session.closed || session.cancelToken.isCancelled) return null;
      if (attempt == _windowFetchAttempts) {
        AppTalker.warning(
          'Player',
          'direct-link chunk proxy gave up on window $index '
              'at=${(start / 1048576).round()}MB after $attempt attempts',
        );
        return null;
      }
      AppTalker.info(
        'Player',
        'direct-link chunk proxy retrying window $index '
            '(attempt ${attempt + 1}/$_windowFetchAttempts)',
      );
      await Future<void>.delayed(_windowFetchRetryDelay);
      if (session.closed || session.cancelToken.isCancelled) return null;
    }
    return null;
  }

  /// Performs one attempt at the upstream read behind [_fetchWindow].
  Future<Uint8List?> _attemptWindowFetch(
    _ChunkSession session,
    int index,
    int start,
    int end,
  ) async {
    final expected = end - start + 1;
    session.activeRequests++;
    final startedAt = DateTime.now();
    try {
      final response = await _dio.get<ResponseBody>(
        session.upstreamUri.toString(),
        cancelToken: session.cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            ...session.headers,
            HttpHeaders.rangeHeader: 'bytes=$start-$end',
          },
          receiveTimeout: const Duration(seconds: 60),
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );
      final body = response.data;
      if (body == null) return null;
      final builder = BytesBuilder(copy: false);
      await for (final piece in body.stream) {
        builder.add(piece);
      }
      final bytes = builder.takeBytes();
      if (bytes.isEmpty) return null;
      // Timed before the cache write so the sample measures the link rather
      // than the disk, and recorded for the concurrency decision.
      session.recordNetworkWindow(
        bytes.length,
        DateTime.now().difference(startedAt).inMilliseconds,
      );
      session.fetchedBytes += bytes.length;
      _recordFetch(session, index, bytes.length);
      // A short window must not enter the cache: later reads compute offsets
      // against a full window.
      if (bytes.length >= expected) {
        session.store(index, bytes);
      }
      return bytes;
    } on DioException catch (error, stackTrace) {
      // A released session cancels its reads on purpose; that is not a fault.
      if (CancelToken.isCancel(error)) return null;
      AppTalker.error(
        'Player',
        error: error,
        stackTrace: stackTrace,
        message: 'direct-link chunk proxy upstream fetch failed',
      );
      return null;
    } catch (error, stackTrace) {
      AppTalker.error(
        'Player',
        error: error,
        stackTrace: stackTrace,
        message: 'direct-link chunk proxy upstream fetch failed',
      );
      return null;
    } finally {
      session.activeRequests--;
    }
  }

  /// Reads the full stream length. HEAD is not implemented by the NAS range
  /// proxy, but a one-byte ranged GET still reports the total through
  /// `Content-Range`.
  ///
  /// Retried like a window download: this is the first request a session
  /// makes, so a single dropped connection here would otherwise fail playback
  /// before it starts.
  Future<int> _probeTotal(_ChunkSession session) async {
    Object? lastError;
    for (var attempt = 1; attempt <= _windowFetchAttempts; attempt++) {
      try {
        return await _attemptProbeTotal(session);
      } catch (error) {
        lastError = error;
        if (session.closed || session.cancelToken.isCancelled) rethrow;
        if (attempt == _windowFetchAttempts) break;
        await Future<void>.delayed(_windowFetchRetryDelay);
      }
    }
    throw HttpException(
      'upstream stream length is unknown: $lastError',
    );
  }

  /// Performs one attempt at reading the stream length.
  Future<int> _attemptProbeTotal(_ChunkSession session) async {
    final response = await _dio.get<List<int>>(
      session.upstreamUri.toString(),
      options: Options(
        responseType: ResponseType.bytes,
        headers: {...session.headers, HttpHeaders.rangeHeader: 'bytes=0-0'},
        receiveTimeout: const Duration(seconds: 30),
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
    final contentType = response.headers.value(HttpHeaders.contentTypeHeader);
    if (contentType != null && contentType.isNotEmpty) {
      session.contentType = contentType;
    }
    final contentRange = response.headers.value(HttpHeaders.contentRangeHeader);
    if (contentRange != null) {
      final slash = contentRange.lastIndexOf('/');
      if (slash >= 0) {
        final total = int.tryParse(contentRange.substring(slash + 1).trim());
        if (total != null && total > 0) return total;
      }
    }
    final contentLength = response.headers.value(
      HttpHeaders.contentLengthHeader,
    );
    final fallback = int.tryParse(contentLength ?? '');
    if (fallback != null && fallback > 0) return fallback;
    throw const HttpException('upstream stream length is unknown');
  }

  // ── TEMPORARY fetch probe ────────────────────────────────────────────────
  /// Records one player request at full fidelity: its range, the gap since the
  /// previous request, and how many times this exact start offset has been
  /// asked for before. Logged for every request (no throttling) because the
  /// gaps and the repeats are the measurement.
  void _traceRequest(int connectionId, int start, int length) {
    final now = DateTime.now();
    final gapMs = _previousRequestAt == null
        ? -1
        : now.difference(_previousRequestAt!).inMilliseconds;
    _previousRequestAt = now;
    _requestCount++;
    final repeats = (_requestCountsByStart[start] ?? 0) + 1;
    _requestCountsByStart[start] = repeats;

    AppTalker.info(
      'Player',
      'chunk trace #$_requestCount conn=$connectionId '
          'startMB=${(start / 1048576).round()} lenMB=${(length / 1048576).toStringAsFixed(1)} '
          'gapMs=$gapMs sameStartSeen=$repeats',
    );
  }

  /// Logs every range the player asks the proxy for, throttled to 8 log lines
  /// per second so the trace stays readable at full throughput.
  void _logIncomingRequest(
    int connectionId,
    _ChunkSession session,
    int start,
    int length,
    String? rangeHeader,
  ) {
    final now = DateTime.now();
    final last = _lastRequestLogAt;
    if (last != null && now.difference(last).inMilliseconds < 125) return;
    _lastRequestLogAt = now;
    AppTalker.info(
      'Player',
      'chunk probe conn=$connectionId open: raw=${rangeHeader ?? 'none'} '
          'start=$start len=$length '
          'startMB=${(start / 1048576).round()} '
          'lenMB=${(length / 1048576).toStringAsFixed(1)}',
    );
  }

  /// Logs how a player connection finished, with the windows it actually
  /// received, so a client that walked away early is visible in the trace.
  void _logConnectionClosed(
    int connectionId,
    String outcome,
    DateTime openedAt,
    int sentBytes,
    List<int> sentWindows,
  ) {
    final elapsed = DateTime.now().difference(openedAt).inMilliseconds;
    final first = sentWindows.isEmpty ? '-' : sentWindows.first.toString();
    final last = sentWindows.isEmpty ? '-' : sentWindows.last.toString();
    AppTalker.info(
      'Player',
      'chunk probe conn=$connectionId closed ($outcome): '
          'windows=${sentWindows.length} first=$first last=$last '
          'sentMB=${(sentBytes / 1048576).toStringAsFixed(1)} elapsedMs=$elapsed',
    );
  }

  /// Records one completed window fetch and periodically logs the pattern.
  ///
  /// Logs a summary every 64 fetches (about 512 MB) plus the most recent
  /// window indices, so the trace shows both the volume and whether the reads
  /// walk forward through the file or keep revisiting the same offsets.
  void _recordFetch(_ChunkSession session, int index, int byteCount) {
    session.fetchCount++;
    session.windowFetchCounts[index] =
        (session.windowFetchCounts[index] ?? 0) + 1;
    session.recentWindows.add(index);
    if (session.recentWindows.length > 40) session.recentWindows.removeAt(0);

    if (session.fetchCount % 64 != 0) return;
    final counts = session.windowFetchCounts.values;
    final distinct = session.windowFetchCounts.length;
    final maxRepeat = counts.isEmpty
        ? 0
        : counts.reduce((a, b) => a > b ? a : b);
    final total = session.totalBytes;
    AppTalker.info(
      'Player',
      'chunk probe: fetches=${session.fetchCount} '
          'distinct=$distinct '
          'maxRepeat=$maxRepeat '
          'cacheHits=${session.cacheHits} '
          'fetchedMB=${(session.fetchedBytes / 1048576).round()} '
          'fileMB=${total == null ? '?' : (total / 1048576).round()} '
          'active=${session.activeRequests} '
          'recent=${session.recentWindows.take(24).join(',')} '
          '(last=${byteCount}B)',
    );
  }

  /// Parses a single-range `bytes=` request against [total]. Multi-range
  /// requests are collapsed to their first range, which is what media players
  /// actually issue. Returns null when the range is malformed or falls outside
  /// the stream, which the caller reports as 416.
  ({int start, int end})? _parseRange(String? header, int total) {
    if (header == null) return null;
    final value = header.trim();
    const prefix = 'bytes=';
    if (!value.toLowerCase().startsWith(prefix)) return null;
    final first = value.substring(prefix.length).split(',').first.trim();
    final dash = first.indexOf('-');
    if (dash < 0) return null;
    final startText = first.substring(0, dash).trim();
    final endText = first.substring(dash + 1).trim();
    if (startText.isEmpty) {
      final suffixLength = int.tryParse(endText);
      if (suffixLength == null || suffixLength <= 0) return null;
      return (start: math.max(0, total - suffixLength), end: total - 1);
    }
    final start = int.tryParse(startText);
    if (start == null || start >= total) return null;
    var end = endText.isEmpty ? total - 1 : int.tryParse(endText) ?? total - 1;
    if (end > total - 1) end = total - 1;
    if (start > end) return null;
    return (start: start, end: end);
  }

  _ChunkSession? _sessionForPath(String path) {
    final index = path.indexOf(_proxyPathPrefix);
    if (index < 0) return null;
    final id = path.substring(index + _proxyPathPrefix.length);
    if (id.isEmpty) return null;
    return _sessions[id];
  }

  ContentType _parseContentType(String raw) {
    final parts = raw.split(';').first.trim().split('/');
    if (parts.length != 2) return ContentType.binary;
    return ContentType(parts[0].trim(), parts[1].trim());
  }

  void _evictExcessSessions() {
    while (_sessions.length > _maxSessions) {
      final oldest = _sessions.values.reduce(
        (left, right) =>
            left.lastAccess.isBefore(right.lastAccess) ? left : right,
      );
      _closeSession(oldest);
      _sessions.remove(oldest.id);
    }
  }

  void _dropIdleSessions() {
    final now = DateTime.now();
    final idle = _sessions.values
        .where(
          (session) => now.difference(session.lastAccess) > _sessionIdleTimeout,
        )
        .toList(growable: false);
    for (final session in idle) {
      _closeSession(session);
      _sessions.remove(session.id);
    }
  }

  /// Root directory for chunk caches, created on first use.
  ///
  /// Kept under the application support directory beside the logs so the cache
  /// lives on the same volume the app already owns, rather than a temp folder
  /// the OS may clear mid-playback.
  Directory _cacheRoot() {
    final existing = _cacheRootDirectory;
    if (existing != null) return existing;
    final base = _supportDirectoryProvider?.call();
    if (base == null) {
      // The provider resolves asynchronously in the app, so the very first
      // playback may see no answer yet. Use a throwaway temp directory for it
      // without caching the choice, so the next session picks up the real
      // support directory instead of being pinned to temp for the app's life.
      return Directory.systemTemp.createTempSync('fly_narwhal_chunks');
    }
    final root = Directory(base);
    try {
      root.createSync(recursive: true);
    } catch (_) {
      return Directory.systemTemp.createTempSync('fly_narwhal_chunks');
    }
    _cacheRootDirectory = root;
    return root;
  }

  String _newSessionId() {
    final random = math.Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < 16; i++) {
      buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Detects the connection reset that a player seek produces, so a normal
  /// abort is not reported as an error. Only the writes to the player can
  /// raise these; upstream failures are handled inside [_fetchWindow].
  bool _isClientDisconnect(Object error) {
    if (error is SocketException) return true;
    if (error is HttpException) return true;
    return false;
  }
}
