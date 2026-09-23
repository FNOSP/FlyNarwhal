import 'cdn_proxy_constants.dart';

const int _maxInt = 0x7fffffffffffffff;

/// An inclusive byte interval.
class CdnByteRange {
  const CdnByteRange({required this.start, required this.end});

  final int start;
  final int end;

  int get length {
    _validateRange(this);
    return end - start + 1;
  }
}

class ResolvedCdnRange {
  const ResolvedCdnRange({required this.range, required this.partial});

  /// Null only for an empty resource requested without a Range header.
  final CdnByteRange? range;
  final bool partial;
}

class CdnRangeNotSatisfiable implements Exception {
  const CdnRangeNotSatisfiable();

  @override
  String toString() => 'The requested CDN byte range is not satisfiable.';
}

/// Resolves one HTTP byte range against the actual CDN resource length.
///
/// Multiple ranges and malformed values are deliberately unsupported. BigInt
/// comparisons keep very large decimal header values from overflowing an int.
ResolvedCdnRange resolveCdnRange(String? rangeHeader, int totalLength) {
  if (totalLength < 0) {
    throw ArgumentError.value(
        totalLength, 'totalLength', 'Must not be negative');
  }
  if (rangeHeader == null) {
    return ResolvedCdnRange(
      range: totalLength == 0
          ? null
          : CdnByteRange(start: 0, end: totalLength - 1),
      partial: false,
    );
  }

  final match = RegExp(
    r'^bytes=([0-9]*)-([0-9]*)$',
    caseSensitive: false,
  ).firstMatch(rangeHeader.trim());
  if (match == null || totalLength == 0) {
    throw const CdnRangeNotSatisfiable();
  }
  final first = match.group(1)!;
  final last = match.group(2)!;
  if (first.isEmpty && last.isEmpty) {
    throw const CdnRangeNotSatisfiable();
  }

  final size = BigInt.from(totalLength);
  final eof = size - BigInt.one;
  late final int start;
  late final int end;
  if (first.isEmpty) {
    final suffix = BigInt.parse(last);
    if (suffix == BigInt.zero) {
      throw const CdnRangeNotSatisfiable();
    }
    start = suffix >= size ? 0 : totalLength - suffix.toInt();
    end = totalLength - 1;
  } else {
    final requestedStart = BigInt.parse(first);
    final requestedEnd = last.isEmpty ? eof : BigInt.parse(last);
    if (requestedStart >= size || requestedEnd < requestedStart) {
      throw const CdnRangeNotSatisfiable();
    }
    start = requestedStart.toInt();
    end = requestedEnd >= eof ? totalLength - 1 : requestedEnd.toInt();
  }
  return ResolvedCdnRange(
    range: CdnByteRange(start: start, end: end),
    partial: true,
  );
}

/// Lazily splits an interval without rounding a short final piece up.
Iterable<CdnByteRange> splitCdnRange(
  CdnByteRange range, {
  int chunkSize = CdnProxyDefaults.chunkSize,
}) sync* {
  _validateChunkSize(chunkSize);
  _validateRange(range);
  var start = range.start;
  while (true) {
    final remaining = range.end - start + 1;
    final length = remaining < chunkSize ? remaining : chunkSize;
    // Adding length - 1 avoids a transient overflow at the largest valid end.
    final end = start + (length - 1);
    yield CdnByteRange(start: start, end: end);
    if (end == range.end) return;
    start = end + 1;
  }
}

int cdnRangeConcurrency(
  int remainingBytes, {
  int chunkSize = CdnProxyDefaults.chunkSize,
}) {
  _validateChunkSize(chunkSize);
  if (remainingBytes < 0) {
    throw ArgumentError.value(
      remainingBytes,
      'remainingBytes',
      'Must not be negative',
    );
  }
  if (remainingBytes == 0) return 0;
  final pieces = (remainingBytes - 1) ~/ chunkSize + 1;
  return pieces < CdnProxyDefaults.maxConcurrent
      ? pieces
      : CdnProxyDefaults.maxConcurrent;
}

void _validateChunkSize(int chunkSize) {
  if (chunkSize <= 0) {
    throw ArgumentError.value(chunkSize, 'chunkSize', 'Must be positive');
  }
}

void _validateRange(CdnByteRange range) {
  if (range.start < 0 ||
      range.end < range.start ||
      range.end - range.start == _maxInt) {
    throw ArgumentError.value(
      range,
      'range',
      'Must have non-negative ordered endpoints and an int-sized length',
    );
  }
}
