import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Parses MP4 moov/stbl to map playback time to byte offset (KMP [Mp4Parser] port).
class Mp4Parser {
  Mp4Parser(this._dio);

  final Dio _dio;

  static const int _rangeHeaderBytes = 5 * 1024 * 1024;

  /// Returns byte offset for [time] seconds, or 0 on failure.
  Future<int> getOffset(String fullUrl, double time) async {
    try {
      final response = await _dio.get<List<int>>(
        fullUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: <String, dynamic>{
            'Range': 'bytes=0-${_rangeHeaderBytes - 1}',
          },
        ),
      );
      final raw = response.data;
      if (raw == null || raw.isEmpty) {
        return 0;
      }
      final bytes = Uint8List.fromList(raw);
      final atoms = _parseAtoms(bytes, bytes.length);
      final moov = _atomByType(atoms, 'moov');
      if (moov == null) {
        debugPrint('[Mp4Parser] moov atom not found in first ${_rangeHeaderBytes}B');
        return 0;
      }
      final offset = _findOffsetInMoov(moov.data, time);
      debugPrint('[Mp4Parser] Calculated offset for time $time: $offset');
      return offset;
    } on DioException catch (e) {
      debugPrint('[Mp4Parser] DioException: ${e.message}');
      return 0;
    } catch (e, st) {
      debugPrint('[Mp4Parser] Failed to parse MP4: $e\n$st');
      return 0;
    }
  }

  int _findOffsetInMoov(Uint8List moovData, double time) {
    final atoms = _parseAtoms(moovData, moovData.length);
    for (final atom in atoms) {
      if (atom.type == 'trak') {
        final offset = _findOffsetInTrak(atom.data, time);
        if (offset != -1) {
          return offset;
        }
      }
    }
    return 0;
  }

  int _findOffsetInTrak(Uint8List trakData, double time) {
    final atoms = _parseAtoms(trakData, trakData.length);
    final mdia = _atomByType(atoms, 'mdia');
    if (mdia == null) {
      return -1;
    }
    final mdiaAtoms = _parseAtoms(mdia.data, mdia.data.length);

    final hdlr = _atomByType(mdiaAtoms, 'hdlr');
    if (hdlr != null && hdlr.data.length > 12) {
      final type = String.fromCharCodes(hdlr.data.sublist(8, 12));
      if (type != 'vide') {
        return -1;
      }
    }

    final minf = _atomByType(mdiaAtoms, 'minf');
    if (minf == null) {
      return -1;
    }
    final minfAtoms = _parseAtoms(minf.data, minf.data.length);
    final stbl = _atomByType(minfAtoms, 'stbl');
    if (stbl == null) {
      return -1;
    }
    final stblAtoms = _parseAtoms(stbl.data, stbl.data.length);

    final mdhd = _atomByType(mdiaAtoms, 'mdhd');
    if (mdhd == null) {
      return -1;
    }
    final timescale = _parseTimescale(mdhd.data);

    final stts = _atomByType(stblAtoms, 'stts');
    final stss = _atomByType(stblAtoms, 'stss');
    final stco = _atomByType(stblAtoms, 'stco');
    final co64 = _atomByType(stblAtoms, 'co64');
    final stsc = _atomByType(stblAtoms, 'stsc');

    if (stts != null && (stco != null || co64 != null) && stsc != null) {
      return _calculateOffset(
        time,
        timescale,
        stts.data,
        stss?.data,
        stsc.data,
        stco?.data,
        co64?.data,
      );
    }

    return -1;
  }

  int _parseTimescale(Uint8List data) {
    final bd = ByteData.sublistView(data);
    final version = bd.getUint8(0);
    if (version == 1) {
      return bd.getUint32(20, Endian.big);
    }
    return bd.getUint32(12, Endian.big);
  }

  int _calculateOffset(
    double time,
    int timescale,
    Uint8List sttsData,
    Uint8List? stssData,
    Uint8List stscData,
    Uint8List? stcoData,
    Uint8List? co64Data,
  ) {
    final targetTicks = (time * timescale).toInt();

    final sttsBd = ByteData.sublistView(sttsData);
    var sttsOff = 4;
    final sttsEntryCount = sttsBd.getUint32(sttsOff, Endian.big);
    sttsOff += 4;

    var currentSample = 0;
    var currentTicks = 0;
    var foundSample = -1;

    for (var i = 0; i < sttsEntryCount; i++) {
      final count = sttsBd.getUint32(sttsOff, Endian.big);
      sttsOff += 4;
      final delta = sttsBd.getUint32(sttsOff, Endian.big);
      sttsOff += 4;
      final duration = count * delta;

      if (currentTicks + duration >= targetTicks) {
        final diff = targetTicks - currentTicks;
        final samples = diff ~/ delta;
        foundSample = currentSample + samples;
        break;
      }
      currentTicks += duration;
      currentSample += count;
    }

    if (foundSample == -1) {
      foundSample = currentSample;
    }

    var targetSample = foundSample + 1;

    if (stssData != null) {
      final stssBd = ByteData.sublistView(stssData);
      var stssOff = 4;
      final stssEntryCount = stssBd.getUint32(stssOff, Endian.big);
      stssOff += 4;
      final syncSamples = List<int>.generate(stssEntryCount, (j) {
        final v = stssBd.getUint32(stssOff, Endian.big);
        stssOff += 4;
        return v;
      });
      if (syncSamples.isNotEmpty) {
        var bestSyncSample = syncSamples[0];
        for (final sample in syncSamples) {
          if (sample > targetSample) {
            break;
          }
          bestSyncSample = sample;
        }
        targetSample = bestSyncSample;
      }
    }

    final stscBd = ByteData.sublistView(stscData);
    var stscOff = 4;
    final stscEntryCount = stscBd.getUint32(stscOff, Endian.big);
    stscOff += 4;

    final stscEntries = <({int firstChunk, int samplesPerChunk, int id})>[];
    for (var i = 0; i < stscEntryCount; i++) {
      stscEntries.add((
        firstChunk: stscBd.getUint32(stscOff, Endian.big),
        samplesPerChunk: stscBd.getUint32(stscOff + 4, Endian.big),
        id: stscBd.getUint32(stscOff + 8, Endian.big),
      ));
      stscOff += 12;
    }

    var currentSampleIndex = 1;
    var foundChunkIndex = -1;

    for (var i = 0; i < stscEntryCount; i++) {
      final entry = stscEntries[i];
      final nextEntryStartChunk =
          i + 1 < stscEntryCount ? stscEntries[i + 1].firstChunk : 2147483647;

      final numChunks = nextEntryStartChunk - entry.firstChunk;
      final samplesInRun = numChunks * entry.samplesPerChunk;

      if (targetSample < currentSampleIndex + samplesInRun) {
        final samplesDiff = targetSample - currentSampleIndex;
        final chunksDiff = samplesDiff ~/ entry.samplesPerChunk;
        foundChunkIndex = entry.firstChunk + chunksDiff;
        break;
      }

      currentSampleIndex += samplesInRun;
    }

    if (foundChunkIndex == -1) {
      return 0;
    }

    if (stcoData != null) {
      final stcoBd = ByteData.sublistView(stcoData);
      var stcoOff = 4;
      final stcoCount = stcoBd.getUint32(stcoOff, Endian.big);
      stcoOff += 4;
      if (foundChunkIndex > stcoCount) {
        return 0;
      }
      stcoOff += (foundChunkIndex - 1) * 4;
      return stcoBd.getUint32(stcoOff, Endian.big);
    }
    if (co64Data != null) {
      final co64Bd = ByteData.sublistView(co64Data);
      var co64Off = 4;
      final co64Count = co64Bd.getUint32(co64Off, Endian.big);
      co64Off += 4;
      if (foundChunkIndex > co64Count) {
        return 0;
      }
      co64Off += (foundChunkIndex - 1) * 8;
      return co64Bd.getUint64(co64Off, Endian.big);
    }

    return 0;
  }

  List<_Atom> _parseAtoms(Uint8List packet, int totalSize) {
    final atoms = <_Atom>[];
    var readBytes = 0;
    var offset = 0;

    while (offset + 8 <= totalSize && readBytes < totalSize) {
      var atomSize = _readUint32BE(packet, offset);
      offset += 4;
      readBytes += 4;

      if (offset + 4 > totalSize) {
        break;
      }
      final type = String.fromCharCodes(packet.sublist(offset, offset + 4));
      offset += 4;
      readBytes += 4;

      var headerSize = 8;
      if (atomSize == 1) {
        if (offset + 8 > totalSize) {
          break;
        }
        atomSize = _readUint64BE(packet, offset);
        offset += 8;
        readBytes += 8;
        headerSize = 16;
      }

      if (atomSize < headerSize) {
        break;
      }
      final dataSize = atomSize - headerSize;
      if (dataSize > totalSize - offset || dataSize < 0) {
        break;
      }

      final data = packet.sublist(offset, offset + dataSize);
      offset += dataSize;
      readBytes += dataSize;

      atoms.add(_Atom(atomSize, type, data));
    }
    return atoms;
  }
}

class _Atom {
  _Atom(this.size, this.type, this.data);

  final int size;
  final String type;
  final Uint8List data;
}

int _readUint32BE(Uint8List bytes, int offset) {
  final bd = ByteData.sublistView(bytes, offset, offset + 4);
  return bd.getUint32(0, Endian.big);
}

int _readUint64BE(Uint8List bytes, int offset) {
  final bd = ByteData.sublistView(bytes, offset, offset + 8);
  return bd.getUint64(0, Endian.big);
}

_Atom? _atomByType(List<_Atom> atoms, String type) {
  for (final a in atoms) {
    if (a.type == type) {
      return a;
    }
  }
  return null;
}
