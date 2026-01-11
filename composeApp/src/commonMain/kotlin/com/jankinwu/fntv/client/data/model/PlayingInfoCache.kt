package com.jankinwu.fntv.client.data.model

import com.jankinwu.fntv.client.data.model.response.AudioStream
import com.jankinwu.fntv.client.data.model.response.FileInfo
import com.jankinwu.fntv.client.data.model.response.Item
import com.jankinwu.fntv.client.data.model.response.PlayConfig
import com.jankinwu.fntv.client.data.model.response.QualityResponse
import com.jankinwu.fntv.client.data.model.response.StreamResponse
import com.jankinwu.fntv.client.data.model.response.SubtitleStream
import com.jankinwu.fntv.client.data.model.response.VideoStream

/**
 * 播放信息缓存数据类
 * 用于缓存当前播放的视频流、音频流、字幕流等信息
 * 生命周期跟随播放器
 */
data class PlayingInfoCache(
    var streamInfo: StreamResponse,
    val playLink: String? = null,
    val currentFileStream: FileInfo,
    val currentVideoStream: VideoStream,
    var currentAudioStream: AudioStream? = null,
    var currentSubtitleStream: SubtitleStream? = null,
    val itemGuid: String,
    val parentGuid: String? = null,
    val parentTitle: String? = null,
    val currentQualities: List<QualityResponse>? = null,
    val currentQuality: QualityResponse? = null,
    val currentAudioStreamList: List<AudioStream>? = null,
    var currentSubtitleStreamList: List<SubtitleStream>? = null,
    var isUseDirectLink: Boolean = false,
    var isEpisode: Boolean = false,
    var previousSubtitle: SubtitleStream? = null,
    var playConfig: PlayConfig? = null,
    val item: Item? = null
)
