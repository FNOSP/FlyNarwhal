package com.jankinwu.fntv.client.data.model

import com.jankinwu.fntv.client.data.model.response.AudioStream
import com.jankinwu.fntv.client.data.model.response.FileInfo
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
    val streamInfo: StreamResponse,
    val playLink: String,
    val currentFileStream: FileInfo,
    val currentVideoStream: VideoStream,
    val currentAudioStream: AudioStream? = null,
    val currentSubtitleStream: SubtitleStream? = null,
    val itemGuid: String,
    val currentQualities: List<QualityResponse>? = null,
    val currentQuality: QualityResponse? = null
)