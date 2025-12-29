package com.jankinwu.fntv.client.utils

import androidx.compose.ui.text.AnnotatedString
import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.data.model.response.SubtitleStream
import com.jankinwu.fntv.client.data.store.AccountDataCache
import io.ktor.client.HttpClient
import io.ktor.client.request.get
import io.ktor.client.statement.bodyAsText
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlin.coroutines.cancellation.CancellationException
import kotlin.math.abs


data class SubtitleSegment(
    val index: Int,
    val uri: String,
    val durationSec: Double,
    val startTimeSec: Double,
    val endTimeSec: Double
)

class HlsSubtitleUtil(
    private val client: HttpClient,
    private val playLink: String,
    private val subtitleStream: SubtitleStream
) {
    private val logger = Logger.withTag("HlsSubtitleUtil")
    
    private val segments = mutableListOf<SubtitleSegment>()
    private val cues = mutableListOf<SubtitleCue>()
    private val fetchedSegmentIndices = mutableSetOf<Int>()
    private val mutex = Mutex()
    
    private var baseUrl: String = ""
    private var subtitleBaseUrl: String = ""
    private var isInitialized = false
    private var lastUpdateCheckTime = 0L
    private val UPDATE_INTERVAL_MS = 10000L // Check for new segments every 10s (increased from 5s)
    private var lastProcessedPositionSec = -1.0
    private val SEEK_THRESHOLD_SEC = 2.0 // Threshold to detect seek

    companion object {
        suspend fun fetchContent(client: HttpClient, url: String): String {
            val fullUrl = if (url.startsWith("http")) url else {
                val host = if (AccountDataCache.cookieState.isNotBlank()) {
                    AccountDataCache.getProxyBaseUrl()
                } else {
                    AccountDataCache.getFnOfficialBaseUrl()
                }
                if (url.startsWith("/")) "$host$url" else "$host/$url"
            }
            
            return client.get(fullUrl) {
//                if (AccountDataCache.cookieState.isNotBlank()) {
//                    header("cookie", AccountDataCache.cookieState)
//                    header("Authorization", AccountDataCache.authorization)
//                }
            }.bodyAsText()
        }

        fun extractVideoStreamUrl(m3u8Content: String, presetUrl: String): String? {
            // Find #EXT-X-STREAM-INF
            val lines = m3u8Content.lines()
            for (i in lines.indices) {
                if (lines[i].startsWith("#EXT-X-STREAM-INF")) {
                    if (i + 1 < lines.size) {
                        val videoUri = lines[i + 1].trim()
                        if (videoUri.isNotBlank()) {
                            // Resolve relative URL
                            if (videoUri.startsWith("http")) return videoUri
                            
                            val baseUrl = presetUrl.substringBeforeLast("/")
                            val host = if (AccountDataCache.cookieState.isNotBlank()) {
                                AccountDataCache.getProxyBaseUrl()
                            } else {
                                AccountDataCache.getFnOfficialBaseUrl()
                            }
                            
                            if (videoUri.startsWith("/")) return "$host$videoUri"
                            
                            // Check if presetUrl is absolute
                            if (presetUrl.startsWith("http")) {
                                return "$baseUrl/$videoUri"
                            }
                            
                            return "$host$baseUrl/$videoUri"
                        }
                    }
                }
            }
            return null
        }
    }

    suspend fun initialize(startPositionMs: Long) {
        mutex.withLock {
            if (isInitialized) return
        }
        withContext(Dispatchers.IO) {
            try {
                baseUrl = playLink.substringBeforeLast("/")
                val fullPlayLink = constructFullUrl(playLink)
                
                // 1. Fetch preset.m3u8
                val m3u8Content = fetchWithAuth(fullPlayLink)
                
                // 2. Find subtitle URI matching the stream
                val subtitleUri = findSubtitleUri(m3u8Content, subtitleStream)
                if (subtitleUri == null) {
                    logger.w { "No matching subtitle URI found in preset.m3u8" }
                    return@withContext
                }
                
                val subtitlePlaylistUrl = resolveUrl(baseUrl, subtitleUri)
                subtitleBaseUrl = subtitlePlaylistUrl.substringBeforeLast("/")
                
                // 3. Fetch subtitle playlist
                val playlistContent = fetchWithAuth(subtitlePlaylistUrl)
                
                // 4. Parse segments with duration
                mutex.withLock {
                    parseSegments(playlistContent)
                    isInitialized = true
                }
                logger.i { "Initialized HLS subtitle util with ${segments.size} segments" }
                
                // 5. Immediately update for the current position
                update(startPositionMs)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                logger.e(e) { "Failed to initialize HlsSubtitleUtil" }
            }
        }
    }

    suspend fun reload(startPositionMs: Long = 0L) {
        mutex.withLock {
            segments.clear()
            cues.clear()
            fetchedSegmentIndices.clear()
            isInitialized = false
            lastUpdateCheckTime = 0L
            lastProcessedPositionSec = -1.0
        }
        initialize(startPositionMs)
    }

    suspend fun update(currentPositionMs: Long) = withContext(Dispatchers.IO) {
        if (!isInitialized) return@withContext
        
        val currentTime = System.currentTimeMillis()
        val currentSec = currentPositionMs / 1000.0
        
        // Detect seek or first run
        val isSeek = lastProcessedPositionSec < 0 || abs(currentSec - lastProcessedPositionSec) > SEEK_THRESHOLD_SEC + (currentTime - lastUpdateCheckTime) / 1000.0
        lastProcessedPositionSec = currentSec

        // If not a seek and within interval, skip
        if (!isSeek && currentTime - lastUpdateCheckTime < UPDATE_INTERVAL_MS) {
            return@withContext
        }
        lastUpdateCheckTime = currentTime

        val targetEndSec = currentSec + 30.0 // Fetch next 30 seconds
        
        // Find segments that overlap with [currentSec, targetEndSec]
        val segmentsToFetch = segments.filter { segment ->
            segment.startTimeSec < targetEndSec && segment.endTimeSec > currentSec
        }.filter { !fetchedSegmentIndices.contains(it.index) }
        
        if (segmentsToFetch.isEmpty()) return@withContext
        
        segmentsToFetch.forEach { segment ->
            fetchAndParseSegment(segment)
        }
    }
    
    suspend fun getCurrentSubtitle(currentPositionMs: Long): List<SubtitleCue> {
        mutex.withLock {
            if (cues.isEmpty()) return emptyList()

            var low = 0
            var high = cues.size - 1
            var index = -1

            while (low <= high) {
                val mid = (low + high) / 2
                if (cues[mid].startTime <= currentPositionMs) {
                    index = mid
                    low = mid + 1
                } else {
                    high = mid - 1
                }
            }

            if (index == -1) return emptyList()

            val result = mutableListOf<SubtitleCue>()
            for (i in index downTo 0) {
                val cue = cues[i]
                if (currentPositionMs < cue.endTime) {
                    result.add(cue)
                }
                if (currentPositionMs - cue.startTime > 300000) {
                    break
                }
            }
            return result.reversed()
        }
    }
    
    private suspend fun fetchAndParseSegment(segment: SubtitleSegment) {
        var attempt = 0
        while (attempt < 3) {
            try {
                // If this is the first attempt, mark as fetched to prevent other threads from picking it up
                // If it fails, we remove it from fetchedSegmentIndices in catch block ONLY if all retries fail
                if (attempt == 0) {
                     fetchedSegmentIndices.add(segment.index)
                }
                
                val url = resolveUrl(subtitleBaseUrl, segment.uri)
                val content = fetchWithAuth(url)
                val newCues = parseVtt(content)
                
                mutex.withLock {
                    cues.addAll(newCues)
                    cues.sortBy { it.startTime }
                }
                return // Success
            } catch (e: Exception) {
                attempt++
                logger.w { "Failed to fetch segment ${segment.index}, attempt $attempt/3: ${e.message}" }
                if (attempt >= 3) {
                    logger.e(e) { "Permanently failed to fetch segment ${segment.index}" }
                    fetchedSegmentIndices.remove(segment.index) // Allow retry in next update cycle if needed
                } else {
                    delay(1000L * attempt) // Exponential backoff-ish
                }
            }
        }
    }

    private fun parseSegments(content: String) {
        val lines = content.lines()
        var currentTime = 0.0
        var index = 0
        
        var currentDuration = 0.0
        
        for (line in lines) {
            val trimmed = line.trim()
            if (trimmed.startsWith("#EXTINF:")) {
                // #EXTINF:4.004,
                val durationStr = trimmed.removePrefix("#EXTINF:").substringBefore(",")
                currentDuration = durationStr.toDoubleOrNull() ?: 0.0
            } else if (trimmed.isNotBlank() && !trimmed.startsWith("#")) {
                val segment = SubtitleSegment(
                    index = index++,
                    uri = trimmed,
                    durationSec = currentDuration,
                    startTimeSec = currentTime,
                    endTimeSec = currentTime + currentDuration
                )
                segments.add(segment)
                currentTime += currentDuration
            }
        }
    }
    
    private fun parseVtt(content: String): List<SubtitleCue> {
        val cues = mutableListOf<SubtitleCue>()
        val lines = content.lines()
        
        var i = 0
        while (i < lines.size) {
            val line = lines[i].trim()
            if (line.contains("-->")) {
                // Found timestamp line
                try {
                    val parts = line.split("-->")
                    val startStr = parts[0].trim()
                    val endStr = parts[1].trim()
                    val startMs = parseTime(startStr)
                    val endMs = parseTime(endStr)
                    
                    // Collect text
                    val textBuilder = StringBuilder()
                    i++
                    while (i < lines.size && lines[i].trim().isNotBlank()) {
                        textBuilder.append(lines[i].trim()).append("\n")
                        i++
                    }
                    val text = textBuilder.toString().trim()
                    
                    if (text.isNotEmpty()) {
                        cues.add(
                            SubtitleCue(
                                startTime = startMs,
                                endTime = endMs,
                                text = AnnotatedString(text),
                                assProps = null
                            )
                        )
                    }
                } catch (e: Exception) {
                    // Ignore malformed
                }
            }
            i++
        }
        return cues
    }

    private fun parseTime(timeStr: String): Long {
        // 00:00:01.000 or 00:01.000
        val parts = timeStr.split(":")
        var hours = 0L
        var minutes = 0L
        var seconds = 0.0
        
        if (parts.size == 3) {
            hours = parts[0].toLong()
            minutes = parts[1].toLong()
            seconds = parts[2].toDouble()
        } else if (parts.size == 2) {
            minutes = parts[0].toLong()
            seconds = parts[1].toDouble()
        }
        
        return (hours * 3600000 + minutes * 60000 + (seconds * 1000)).toLong()
    }
    
    private fun constructFullUrl(url: String): String {
        if (url.startsWith("http")) return url
        val host = if (AccountDataCache.cookieState.isNotBlank()) {
            AccountDataCache.getProxyBaseUrl()
        } else {
            AccountDataCache.getFnOfficialBaseUrl()
        }
        return if (url.startsWith("/")) "$host$url" else "$host/$url"
    }

    private fun resolveUrl(base: String, relative: String): String {
        if (relative.startsWith("http")) return relative
        if (relative.startsWith("/")) {
             val host = if (AccountDataCache.cookieState.isNotBlank()) {
                AccountDataCache.getProxyBaseUrl()
            } else {
                AccountDataCache.getFnOfficialBaseUrl()
            }
            return "$host$relative"
        }
        val fullBase = constructFullUrl(base)
        return if (fullBase.endsWith("/")) "$fullBase$relative" else "$fullBase/$relative"
    }

    private suspend fun fetchWithAuth(url: String): String {
        return client.get(url) {
//            if (AccountDataCache.cookieState.isNotBlank()) {
//                 header("cookie", AccountDataCache.cookieState)
//                 header("Authorization", AccountDataCache.authorization)
//            }
        }.bodyAsText()
    }

    private fun findSubtitleUri(m3u8Content: String, subtitleStream: SubtitleStream): String? {
        val regex = Regex("""#EXT-X-MEDIA:TYPE=SUBTITLES(.*)""")
        val matches = regex.findAll(m3u8Content)
        val targetLang = subtitleStream.language 
        var bestMatchUri: String? = null
        
        for (match in matches) {
            val attributes = match.groupValues[1]
            val uriMatch = Regex("""URI="(.*?)"""").find(attributes)
            val langMatch = Regex("""LANGUAGE="(.*?)"""").find(attributes)
            
            if (uriMatch != null) {
                val uri = uriMatch.groupValues[1]
                val lang = langMatch?.groupValues?.get(1)
                if (lang == targetLang) return uri 
                if (bestMatchUri == null) bestMatchUri = uri
            }
        }
        return bestMatchUri
    }
}
