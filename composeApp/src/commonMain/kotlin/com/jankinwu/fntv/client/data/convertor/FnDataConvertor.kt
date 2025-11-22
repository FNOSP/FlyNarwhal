package com.jankinwu.fntv.client.data.convertor

import com.jankinwu.fntv.client.data.model.ScrollRowItemData
import com.jankinwu.fntv.client.data.model.response.MediaDbListResponse
import com.jankinwu.fntv.client.data.model.response.MediaItem
import com.jankinwu.fntv.client.data.model.response.PersonList
import com.jankinwu.fntv.client.data.model.response.PlayDetailResponse
import com.jankinwu.fntv.client.data.model.response.SearchingSubtitleInfo
import com.jankinwu.fntv.client.enums.FnTvMediaType
import com.jankinwu.fntv.client.icons.Audio
import com.jankinwu.fntv.client.icons.Subtitle
import com.jankinwu.fntv.client.icons.Video
import com.jankinwu.fntv.client.ui.component.common.dialog.SubtitleItemData
import com.jankinwu.fntv.client.ui.component.detail.FileInfoData
import com.jankinwu.fntv.client.ui.component.detail.MediaDetails
import com.jankinwu.fntv.client.ui.component.detail.MediaTrackInfo
import com.jankinwu.fntv.client.ui.screen.CurrentStreamData
import com.jankinwu.fntv.client.ui.screen.IsoTagData
import java.util.concurrent.TimeUnit

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
fun convertToScrollRowItemData(item: MediaItem): ScrollRowItemData {
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

    val score = try {
        item.voteAverage?.toDoubleOrNull()?.toFloat()?.let { "%.1f".format(it) } ?: "0.0"
    } catch (_: Exception) {
        "0.0"
    }
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

/**
 * 将秒数格式化为 m 分钟 s 秒或 H 小时 m 分钟格式的字符串
 * 当时间不满一小时时，不显示小时位
 */
@Suppress("DefaultLocale")
fun formatSeconds(seconds: Int): String {
    val hours = TimeUnit.SECONDS.toHours(seconds.toLong())
    val minutes = TimeUnit.SECONDS.toMinutes(seconds.toLong()) % 60
    val remainingSeconds = seconds % 60
    return if (hours > 0) {
        String.format("%d 小时 %d 分钟", hours, minutes)
    } else {
        String.format("%d 分钟 %d 秒", minutes, remainingSeconds)
    }
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
            val languageName = when (it?.language?.length) {
                3 -> {
                    isoTagData.iso6392Map[it.language]?.value
                        ?: it.language
                }

                2 -> {
                    isoTagData.iso6391Map[it.language]?.value
                        ?: it.language
                }

                else -> {
                    it?.language ?: ""
                }
            }
            audioTrack.details =
                "$languageName ${it?.codecName?.uppercase()} ${it?.channelLayout} · ${it?.sampleRate} Hz"
        }

        val subtitleTrack = MediaTrackInfo(
            type = "字幕",
            details = "",
            icon = Subtitle
        )
        currentStreamData.subtitleStreamList.firstOrNull().let {
            val languageName = when (it?.language?.length) {
                3 -> {
                    isoTagData.iso6392Map[it.language]?.value
                        ?: it.language
                }

                2 -> {
                    isoTagData.iso6391Map[it.language]?.value
                        ?: it.language
                }

                else -> {
                    it?.language ?: ""
                }
            }
            subtitleTrack.details = "$languageName ${it?.codecName?.uppercase()}"
        }
        val imdbLink = if (!imdbId.isNullOrBlank()) "https://www.imdb.com/title/$imdbId/" else ""
        return MediaDetails(
            fileInfo,
            videoTrack,
            audioTrack,
            subtitleTrack,
            imdbLink
        )
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
    fun formatTimestampToDateTime(timestamp: Long): String {
        val date = java.util.Date(timestamp)
        val formatter =
            java.text.SimpleDateFormat("yyyy-MM-dd HH:mm", java.util.Locale.getDefault())
        return formatter.format(date)
    }
}