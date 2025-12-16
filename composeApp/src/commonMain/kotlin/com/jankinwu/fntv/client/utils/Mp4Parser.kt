package com.jankinwu.fntv.client.utils

import co.touchlab.kermit.Logger
import io.ktor.client.HttpClient
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.statement.readBytes
import io.ktor.http.HttpHeaders
import kotlinx.io.Buffer
import kotlinx.io.readByteArray
import kotlinx.io.readString

class Mp4Parser(private val httpClient: HttpClient) {

    private val logger = Logger.withTag("Mp4Parser")

    suspend fun getOffset(url: String, time: Double): Long {
        try {
            // 1. Download header (first 5MB should be enough for moov if at start)
            val headerSize = 5 * 1024 * 1024 // 5MB
            val bytes = httpClient.get(url) {
                header(HttpHeaders.Range, "bytes=0-${headerSize - 1}")
            }.readBytes()

            val packet = Buffer().apply { write(bytes) }
            val atoms = parseAtoms(packet, bytes.size.toLong())
            
            val moov = atoms.find { it.type == "moov" } ?: run {
                // If moov not found, it might be at the end or larger than 5MB
                // For now, we assume it's within the first 5MB as per JS analysis
                logger.w { "moov atom not found in first 5MB" }
                return 0L
            }
            
            // Parse moov to find offsets
            val moovData = moov.data
            val offset = findOffsetInMoov(moovData, time)
            logger.i { "Calculated offset for time $time: $offset" }
            return offset
        } catch (e: Exception) {
            logger.e(e) { "Failed to parse MP4" }
            return 0L
        }
    }

    private fun findOffsetInMoov(moovData: ByteArray, time: Double): Long {
        val packet = Buffer().apply { write(moovData) }
        val atoms = parseAtoms(packet, moovData.size.toLong())
        
        // Find trak -> mdia -> minf -> stbl
        // We need to iterate over tracks to find the video track
        for (atom in atoms) {
            if (atom.type == "trak") {
                val offset = findOffsetInTrak(atom.data, time)
                if (offset != -1L) return offset
            }
        }
        return 0L
    }

    private fun findOffsetInTrak(trakData: ByteArray, time: Double): Long {
        val packet = Buffer().apply { write(trakData) }
        val atoms = parseAtoms(packet, trakData.size.toLong())
        
        val mdia = atoms.find { it.type == "mdia" } ?: return -1L
        val mdiaPacket = Buffer().apply { write(mdia.data) }
        val mdiaAtoms = parseAtoms(mdiaPacket, mdia.data.size.toLong())
        
        // Check handler type to ensure it's video ("vide")
        val hdlr = mdiaAtoms.find { it.type == "hdlr" }
        if (hdlr != null) {
            // hdlr structure: version(1) + flags(3) + pre_defined(4) + handler_type(4)
            if (hdlr.data.size > 12) {
                val type = hdlr.data.copyOfRange(8, 12).decodeToString()
                if (type != "vide") return -1L
            }
        }

        val minf = mdiaAtoms.find { it.type == "minf" } ?: return -1L
        val minfPacket = Buffer().apply { write(minf.data) }
        val minfAtoms = parseAtoms(minfPacket, minf.data.size.toLong())
        
        val stbl = minfAtoms.find { it.type == "stbl" } ?: return -1L
        val stblPacket = Buffer().apply { write(stbl.data) }
        val stblAtoms = parseAtoms(stblPacket, stbl.data.size.toLong())

        // Need mdhd for timescale
        val mdhd = mdiaAtoms.find { it.type == "mdhd" } ?: return -1L
        val timescale = parseTimescale(mdhd.data)

        val stts = stblAtoms.find { it.type == "stts" }
        val stss = stblAtoms.find { it.type == "stss" }
        val stco = stblAtoms.find { it.type == "stco" }
        val co64 = stblAtoms.find { it.type == "co64" }
        val stsc = stblAtoms.find { it.type == "stsc" }

        if (stts != null && (stco != null || co64 != null) && stsc != null) {
            return calculateOffset(
                time, timescale,
                stts.data,
                stss?.data,
                stsc.data,
                stco?.data,
                co64?.data
            )
        }

        return -1L
    }

    private fun parseTimescale(data: ByteArray): Long {
        val packet = Buffer().apply { write(data) }
        val version = packet.readByte().toInt()
        packet.readByteArray(3) // flags
        if (version == 1) {
            packet.readLong() // creation_time
            packet.readLong() // modification_time
            return packet.readInt().toLong() // timescale
        } else {
            packet.readInt() // creation_time
            packet.readInt() // modification_time
            return packet.readInt().toLong() // timescale
        }
    }

    private fun calculateOffset(
        time: Double,
        timescale: Long,
        sttsData: ByteArray,
        stssData: ByteArray?,
        stscData: ByteArray,
        stcoData: ByteArray?,
        co64Data: ByteArray?
    ): Long {
        val targetTicks = (time * timescale).toLong()
        
        // 1. Find sample index for time
        val sttsPacket = Buffer().apply { write(sttsData) }
        sttsPacket.readByteArray(4) // version + flags
        val sttsEntryCount = sttsPacket.readInt()
        
        var currentSample = 0
        var currentTicks = 0L
        var foundSample = -1

        for (i in 0 until sttsEntryCount) {
            val count = sttsPacket.readInt()
            val delta = sttsPacket.readInt()
            val duration = count.toLong() * delta
            
            if (currentTicks + duration >= targetTicks) {
                val diff = targetTicks - currentTicks
                val samples = diff / delta
                foundSample = currentSample + samples.toInt()
                break
            }
            currentTicks += duration
            currentSample += count
        }
        
        if (foundSample == -1) foundSample = currentSample // End of file

        // 2. Find nearest keyframe (Sync Sample)
        // Sample numbers are 1-based in MP4 specs
        var targetSample = foundSample + 1 
        
        if (stssData != null) {
            val stssPacket = Buffer().apply { write(stssData) }
            stssPacket.readByteArray(4) // version + flags
            val stssEntryCount = stssPacket.readInt()
            val syncSamples = IntArray(stssEntryCount)
            for (i in 0 until stssEntryCount) {
                syncSamples[i] = stssPacket.readInt()
            }
            
            // Find largest sync sample <= targetSample
            var bestSyncSample = syncSamples[0]
            for (sample in syncSamples) {
                if (sample > targetSample) break
                bestSyncSample = sample
            }
            targetSample = bestSyncSample
        }
        
        // 3. Find Chunk for Sample
        // 1-based sample index
        
        val stscPacket = Buffer().apply { write(stscData) }
        stscPacket.readByteArray(4) // version + flags
        val stscEntryCount = stscPacket.readInt()
        
        // stsc entries: first_chunk, samples_per_chunk, sample_description_index
        data class StscEntry(val firstChunk: Int, val samplesPerChunk: Int, val id: Int)
        val stscEntries = ArrayList<StscEntry>(stscEntryCount)
        for (i in 0 until stscEntryCount) {
            stscEntries.add(StscEntry(stscPacket.readInt(), stscPacket.readInt(), stscPacket.readInt()))
        }

        var chunkIndex = 0 // 1-based
        var sampleCount = 0
        
        // This mapping is tricky.
        // We need to find which chunk contains 'targetSample'.
        // Iterating chunks is easier.
        
        var currentChunkIndex = 1
        var currentSampleIndex = 1
        var foundChunkIndex = -1
        
        for (i in 0 until stscEntryCount) {
            val entry = stscEntries[i]
            val nextEntryStartChunk = if (i + 1 < stscEntryCount) stscEntries[i+1].firstChunk else Int.MAX_VALUE
            
            val numChunks = nextEntryStartChunk - entry.firstChunk
            val samplesInRun = numChunks.toLong() * entry.samplesPerChunk
            
            if (targetSample < currentSampleIndex + samplesInRun) {
                 // Target is in this run
                 val samplesDiff = targetSample - currentSampleIndex
                 val chunksDiff = samplesDiff / entry.samplesPerChunk
                 foundChunkIndex = entry.firstChunk + chunksDiff.toInt()
                 break
            }
            
            currentSampleIndex += samplesInRun.toInt()
            currentChunkIndex = nextEntryStartChunk
        }
        
        if (foundChunkIndex == -1) return 0L // Should not happen if targetSample is valid

        // 4. Get Chunk Offset
        if (stcoData != null) {
            val stcoPacket = Buffer().apply { write(stcoData) }
            stcoPacket.readByteArray(4)
            val stcoCount = stcoPacket.readInt()
            if (foundChunkIndex > stcoCount) return 0L
            
            // stco is table of 32-bit offsets
            stcoPacket.readByteArray((foundChunkIndex - 1) * 4)
            return stcoPacket.readInt().toLong()
        } else if (co64Data != null) {
            val co64Packet = Buffer().apply { write(co64Data) }
            co64Packet.readByteArray(4)
            val co64Count = co64Packet.readInt()
            if (foundChunkIndex > co64Count) return 0L
            
            // co64 is table of 64-bit offsets
            co64Packet.readByteArray((foundChunkIndex - 1) * 8)
            return co64Packet.readLong()
        }

        return 0L
    }

    private data class Atom(val size: Long, val type: String, val data: ByteArray)

    private fun parseAtoms(packet: Buffer, totalSize: Long): List<Atom> {
        val atoms = mutableListOf<Atom>()
        var readBytes = 0L
        while (packet.size > 0 && readBytes < totalSize) {
            if (packet.size < 8) break
            var size = packet.readInt().toLong()
            val type = packet.readString(4)
            readBytes += 8
            
            if (size == 1L) {
                 if (packet.size < 8) break
                 size = packet.readLong()
                 readBytes += 8
            }
            
            val dataSize = size - (if (size > Int.MAX_VALUE) 16 else 8)
            if (dataSize > packet.size) {
                // Incomplete atom, skip or handle?
                // For moov, we expect it to be fully in buffer.
                // If not, we might need to fetch more, but here we just stop.
                break
            }
            
            val data = packet.readByteArray(dataSize.toInt())
            atoms.add(Atom(size, type, data))
            readBytes += dataSize
        }
        return atoms
    }
}
