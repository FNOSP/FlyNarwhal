package com.jankinwu.fntv.client.data.convertor

import com.jankinwu.fntv.client.data.model.ScrollRowItemData
import com.jankinwu.fntv.client.data.model.response.EpisodeListResponse
import com.jankinwu.fntv.client.data.model.response.MediaDbListResponse
import com.jankinwu.fntv.client.data.model.response.MediaItem
import com.jankinwu.fntv.client.data.model.response.PersonList
import com.jankinwu.fntv.client.data.model.response.PlayDetailResponse
import com.jankinwu.fntv.client.data.model.response.SearchingSubtitleInfo
import com.jankinwu.fntv.client.data.model.response.UserSource
import com.jankinwu.fntv.client.enums.FnTvMediaType
import com.jankinwu.fntv.client.icons.Audio
import com.jankinwu.fntv.client.icons.Subtitle
import com.jankinwu.fntv.client.icons.Video
import com.jankinwu.fntv.client.ui.component.common.dialog.SubtitleItemData
import com.jankinwu.fntv.client.ui.component.detail.FileInfoData
import com.jankinwu.fntv.client.ui.component.detail.MediaDetails
import com.jankinwu.fntv.client.ui.component.detail.MediaTrackInfo
import com.jankinwu.fntv.client.ui.providable.CurrentStreamData
import com.jankinwu.fntv.client.ui.providable.IsoTagData
import kotlinx.datetime.toLocalDateTime
import java.util.concurrent.TimeUnit
import kotlin.time.ExperimentalTime
import kotlin.time.Instant.Companion.fromEpochMilliseconds

fun convertMediaDbListResponseToScrollRowItem(item: MediaDbListResponse): ScrollRowItemData {
    return ScrollRowItemData(
        posters = item.posters,
        title = item.title,
        guid = item.guid,
    )
}

/**
 * 将 MediaItem 转换为 MediaData
 */
fun convertToScrollRowItemDataList(item: MediaItem): ScrollRowItemData {
    val subtitle = if (item.type == FnTvMediaType.TV.value) {
        if (!item.firstAirDate.isNullOrBlank() && !item.lastAirDate.isNullOrBlank()) {
            "共 ${item.numberOfSeasons} 季 · ${item.firstAirDate.take(4)}~${item.lastAirDate.take(4)}"
        } else if (item.numberOfSeasons == 1 && item.status == "Ended") {
            "共 ${item.numberOfEpisodes} 集${if (!item.releaseDate.isNullOrBlank()) " · " else ""}${
                item.releaseDate?.take(
                    4
                )
            }"
        } else if (item.numberOfSeasons != null && !item.releaseDate.isNullOrBlank()) {
            "第 ${item.seasonNumber} 季 · ${item.releaseDate.take(4)}"
        } else {
            item.releaseDate?.take(4)
        }
    } else if (item.releaseDate.isNullOrBlank() && !item.type.isNullOrBlank()) {
        FnTvMediaType.getByValue(item.type).description
    } else if (item.status == "1" && !item.type.isNullOrBlank() && item.type == FnTvMediaType.VIDEO.value) {
        ""
    } else {
        item.releaseDate?.take(4)
    }

    val score = FnDataConvertor.formatVoteAverage(item.voteAverage)
    val resolutions = item.mediaStream.resolutions?.filter { it != "Others" }?.distinct()

    return ScrollRowItemData(
        title = item.title,
        subtitle = subtitle,
        posterImg = item.poster,
        duration = item.duration,
        score = score,
        resolutions = resolutions,
        isFavourite = item.isFavorite == 1,
        isAlreadyWatched = item.watched == 1,
        guid = item.guid,
        posterWidth = item.posterWidth ?: 0,
        posterHeight = item.posterHeight ?: 0,
        status = item.status,
        type = item.type
    )
}

fun convertPlayDetailToScrollRowItemData(item: PlayDetailResponse): ScrollRowItemData {
    val subtitle = when (item.type) {
        "Episode" -> {
            "第 ${item.seasonNumber} 季 · 第 ${item.episodeNumber} 集"
        }

        "Video" -> {
            " "
        }

        else -> {
            FnTvMediaType.getDescByValue(item.type)
        }
    }
    val title = when (item.type) {
        "Episode" -> item.tvTitle ?: item.title
        else -> item.title
    }

    return ScrollRowItemData(
        title = title,
        subtitle = subtitle,
        posterImg = item.poster,
        duration = item.duration,
        resolutions = item.mediaStream.resolutions?.distinct(),
        isFavourite = item.isFavorite == 1,
        isAlreadyWatched = item.watched == 1,
        ts = item.ts,
        guid = item.guid,
        status = item.status,
        type = item.type,
        parentGuid = item.parentGuid,
    )
}

fun convertPersonToScrollRowItemData(personList: List<PersonList>): List<ScrollRowItemData> {
    // 按照指定的job顺序和order排序
    val sortedPersonList = personList.sortedWith(
        compareBy<PersonList> { person ->
            when (person.job) {
                "Director" -> 0
                "Actor" -> 1
                "Writer" -> 2
                else -> 3
            }
        }.thenBy { person ->
            person.order
        }
    )

    val scrollRowList = sortedPersonList.map {
        val description = when (it.job) {
            "Director" -> "导演"
            "Actor" -> {
                "饰演 ${it.role}"
            }

            "Writer" -> "编剧"
            else -> "其他"
        }
        ScrollRowItemData(
            title = it.name,
            subtitle = description,
            posterImg = it.profilePath,
            guid = it.personGuid,
        )
    }.filter { it.title.isNotBlank() }

    return scrollRowList
}

fun convertToSubtitleItemList(subtitles: List<SearchingSubtitleInfo>): List<SubtitleItemData> {
    return subtitles.map {
        SubtitleItemData(
            fileName = it.filename,
            download = it.download,
            trimId = it.trimId,
        )
    }
}

object FnDataConvertor {

    /**
     * 将秒数格式化为 m 分钟 s 秒或 H 小时 m 分钟格式的字符串
     * 当时间不满一小时时，不显示小时位
     */
    @Suppress("DefaultLocale")
    fun formatSecondsToCNDateTime(seconds: Int): String {
        val hours = TimeUnit.SECONDS.toHours(seconds.toLong())
        val minutes = TimeUnit.SECONDS.toMinutes(seconds.toLong()) % 60
        val remainingSeconds = seconds % 60
        return when {
            hours > 0 && minutes > 0 -> {
                String.format("%d 小时 %d 分钟", hours, minutes)
            }
            hours > 0 && minutes.toInt() == 0 -> {
                String.format("%d 小时", hours)
            }
            minutes > 0 && remainingSeconds > 0 -> {
                String.format("%d 分钟 %d 秒", minutes, remainingSeconds)
            }
            else -> {
                String.format("%d 分钟", minutes)
            }
        }
    }

    fun convertToMediaDetails(
        currentStreamData: CurrentStreamData,
        isoTagData: IsoTagData,
        imdbId: String?
    ): MediaDetails {
        val fileInfo = if (currentStreamData.fileInfo != null) FileInfoData(
            location = currentStreamData.fileInfo.path,
            size = formatFileSize(currentStreamData.fileInfo.size),
            createdDate = formatTimestampToDateTime(currentStreamData.fileInfo.updateTime),
            addedDate = formatTimestampToDateTime(currentStreamData.fileInfo.updateTime)
        ) else FileInfoData()
        val videoTrack = MediaTrackInfo(
            type = "视频",
            details = "",
            icon = Video
        )
        currentStreamData.videoStream?.let {
            videoTrack.details =
                "${currentStreamData.videoStream.resolutionType} ${currentStreamData.videoStream.codecName.uppercase()} ${
                    formatBitrate(currentStreamData.videoStream.bps)} · ${currentStreamData.videoStream.bitDepth} bit"
        }

        val audioTrack = MediaTrackInfo(
            type = "音频",
            details = "",
            icon = Audio
        )
        currentStreamData.audioStreamList.firstOrNull().let {
            val languageName = getLanguageName(it?.language, isoTagData)
            audioTrack.details =
                "$languageName ${it?.codecName?.uppercase()} ${it?.channelLayout} · ${it?.sampleRate} Hz"
        }

        val subtitleTrack = MediaTrackInfo(
            type = "字幕",
            details = "",
            icon = Subtitle
        )
        currentStreamData.subtitleStreamList.firstOrNull().let {
            val languageName = getLanguageName(it?.language, isoTagData)
            subtitleTrack.details = "$languageName ${it?.codecName?.uppercase()}"
        }
        val imdbLink = getImdbLink(imdbId)
        return MediaDetails(
            fileInfo,
            videoTrack,
            audioTrack,
            subtitleTrack,
            imdbLink
        )
    }

    fun getImdbLink(imdbId: String?): String {
        return if (!imdbId.isNullOrBlank()) {
            "https://www.imdb.com/title/$imdbId/"
        } else {
            ""
        }
    }

    fun getLanguageName(language: String?, isoTagData: IsoTagData): String {
        return when {
            language == null -> {
                "无"
            }
            language in listOf("", "und", "zxx", "qaa-qtz", "zz-unknow") -> {
                "未知"
            }
            language.length == 2 -> {
                isoTagData.iso6391Map[language]?.value ?: language
            }
            language.length == 3 -> {
                isoTagData.iso6392Map[language]?.value ?: language
            }
            else -> {
                language
            }
        }
    }

    /**
     * 将字节大小转换为易读的格式
     * @param bytes 字节数
     * @return 格式化后的字符串，如 "1.25 KB", "3.50 MB" 等
     */
    fun formatFileSize(bytes: Long): String {
        if (bytes < 0) return "0 B"

        val units = arrayOf("B", "KB", "MB", "GB", "TB")
        var size = bytes.toDouble()
        var unitIndex = 0

        while (size >= 1024 && unitIndex < units.size - 1) {
            size /= 1024
            unitIndex++
        }

        // 四舍五入保留两位小数
        return "${String.format(java.util.Locale.ROOT, "%.2f", size)} ${units[unitIndex]}"
    }

    /**
     * 将比特率(bps)转换为易读的格式
     * @param bps 比特率(bits per second)
     * @return 格式化后的字符串，如 "5.65 Mbps", "1.20 Gbps" 等
     */
    fun formatBitrate(bps: Int): String {
        if (bps < 0) return "0 bps"

        val units = arrayOf("bps", "Kbps", "Mbps", "Gbps")
        var bitrate = bps.toDouble()
        var unitIndex = 0

        while (bitrate >= 1000 && unitIndex < units.size - 1) {
            bitrate /= 1000
            unitIndex++
        }

        // 保留两位小数
        return "${String.format(java.util.Locale.ROOT, "%.2f", bitrate)} ${units[unitIndex]}"
    }

    /**
     * 将时间戳转换为 "YYYY-MM-dd HH:mm" 格式
     * @param timestamp 时间戳（毫秒）
     * @return 格式化后的时间字符串
     */
//    fun formatTimestampToDateTime(timestamp: Long): String {
//        val date = java.util.Date(timestamp)
//        val formatter =
//            java.text.SimpleDateFormat("yyyy-MM-dd HH:mm", java.util.Locale.getDefault())
//        return formatter.format(date)
//    }

    @OptIn(ExperimentalTime::class)
    fun formatTimestampToDateTime(timestamp: Long): String {
        val instant = fromEpochMilliseconds(timestamp)
        val localDateTime = instant.toLocalDateTime(kotlinx.datetime.TimeZone.currentSystemDefault())
        return "${localDateTime.date} ${localDateTime.time.toString().take(5)}"
    }

    fun humanizedFilePath(path: String, userSources: List<UserSource>): String {
        if (path.startsWith("/vol") && path.length >= 5) {
            // 查找第一个非数字字符的位置，用来提取完整的卷号
            var volEndIndex = 4
            while (volEndIndex < path.length && path[volEndIndex].isDigit()) {
                volEndIndex++
            }

            if (volEndIndex > 4) { // 确保至少有一位数字
                val volNumber = path.substring(4, volEndIndex)

                // 查找匹配的用户源
                val pathParts = path.split("/")
                if (pathParts.size >= 3) {
                    val sourceId = pathParts[2] // 提取source_id (例如: 1000)
                    val matchedSource = userSources.find { it.sourceId == sourceId }

                    // 构建人性化路径
                    val storageTitle = "存储空间$volNumber"
                    val userName = matchedSource?.sourceName ?: sourceId
                    val remainingPath = path.substring(volEndIndex + sourceId.length + 1) // 去除/vol{number}/{sourceId}部分

                    return "$storageTitle/$userName 的文件$remainingPath"
                }
            }
        }
        return path
    }

    fun getVolumeCNName(path: String, hasSpace:  Boolean = false): String {
        if (path.startsWith("/vol") && path.length >= 5) {
            // 查找第一个非数字字符的位置，用来提取完整的卷号
            var volEndIndex = 4
            while (volEndIndex < path.length && path[volEndIndex].isDigit()) {
                volEndIndex++
            }

            if (volEndIndex > 4) { // 确保至少有一位数字
                val volNumber = path.substring(4, volEndIndex)
                return if (hasSpace) "存储空间 $volNumber" else "存储空间$volNumber"
            }
        }
        return "未知存储空间"
    }

    /**
     * 将评分转换为格式化的字符串，保留一位小数
     * @param voteAverage 评分值
     * @return 格式化后的评分字符串，如 "8.7"
     */
    fun formatVoteAverage(voteAverage: String?): String {
        return try {
            voteAverage?.toDoubleOrNull()?.toFloat()?.let { "%.1f".format(it) } ?: "0.0"
        } catch (_: Exception) {
            "0.0"
        }
    }

    fun convertToScrollRowItemDataList(episodes: List<EpisodeListResponse>): List<ScrollRowItemData> {
        return episodes.map { episode ->
            ScrollRowItemData(
                title = "第 ${episode.episodeNumber} 集 ${episode.title}",
                subtitle = episode.overview,
                resolutions = episode.mediaStream.resolutions,
                posterImg = episode.poster,
                isFavourite = episode.isFavorite == 1,
                isAlreadyWatched = episode.watched == 1,
                duration = episode.duration,
                ts = episode.ts.toLong(),
                guid = episode.guid
            )
        }
    }

    fun formatToMb(bytes: Long): String {
        val mb = bytes.toDouble() / (1024 * 1024)
        return ((mb * 100).toLong() / 100.0).toString()
    }
}