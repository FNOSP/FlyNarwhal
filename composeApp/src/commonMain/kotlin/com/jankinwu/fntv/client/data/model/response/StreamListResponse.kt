package com.jankinwu.fntv.client.data.model.response

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class StreamListResponse(
    @param:JsonProperty("files")
    val files: List<FileInfo>?,
    @param:JsonProperty("video_streams")
    val videoStreams: List<VideoStream>,
    @param:JsonProperty("audio_streams")
    val audioStreams: List<AudioStream>,
    @param:JsonProperty("subtitle_streams")
    val subtitleStreams: List<SubtitleStream>
)

@Immutable
data class FileInfo(
    @param:JsonProperty("guid")
    val guid: String,
    @param:JsonProperty("path")
    val path: String,
    @param:JsonProperty("file_name")
    val fileName: String,
    @param:JsonProperty("size")
    val size: Long,
    @param:JsonProperty("timestamp")
    val timestamp: Long,
    @param:JsonProperty("type")
    val type: Int,
    @param:JsonProperty("can_play")
    val canPlay: Int,
    @param:JsonProperty("play_error")
    val playError: String,
    @param:JsonProperty("create_time")
    val createTime: Long,
    @param:JsonProperty("update_time")
    val updateTime: Long,
    @param:JsonProperty("file_birth_time")
    val fileBirthTime: Long,
    @param:JsonProperty("progress_thumb_hash_dir")
    val progressThumbHashDir: String
)

@Immutable
data class VideoStream(
    @param:JsonProperty("media_guid")
    val mediaGuid: String,
    @param:JsonProperty("title")
    val title: String,
    @param:JsonProperty("guid")
    val guid: String,
    @param:JsonProperty("resolution_type")
    val resolutionType: String,
    @param:JsonProperty("color_range_type")
    val colorRangeType: String,
    @param:JsonProperty("codec_name")
    val codecName: String,
    @param:JsonProperty("codec_type")
    val codecType: String,
    @param:JsonProperty("color_range")
    val colorRange: String,
    @param:JsonProperty("profile")
    val profile: String,
    @param:JsonProperty("index")
    val index: Int,
    @param:JsonProperty("width")
    val width: Int,
    @param:JsonProperty("height")
    val height: Int,
    @param:JsonProperty("coded_width")
    val codedWidth: Int,
    @param:JsonProperty("coded_height")
    val codedHeight: Int,
    @param:JsonProperty("display_aspect_ratio")
    val displayAspectRatio: String,
    @param:JsonProperty("pix_fmt")
    val pixFmt: String,
    @param:JsonProperty("level")
    val level: String,
    @param:JsonProperty("color_space")
    val colorSpace: String,
    @param:JsonProperty("color_transfer")
    val colorTransfer: String,
    @param:JsonProperty("color_primaries")
    val colorPrimaries: String,
    @param:JsonProperty("duration")
    val duration: Int,
    @param:JsonProperty("dv_profile")
    val dvProfile: Int,
    @param:JsonProperty("refs")
    val refs: Int,
    @param:JsonProperty("r_frame_rate")
    val rFrameRate: String,
    @param:JsonProperty("avg_frame_rate")
    val avgFrameRate: String,
    @param:JsonProperty("bits_per_raw_sample")
    val bitsPerRawSample: String,
    @param:JsonProperty("bps")
    val bps: Int,
    @param:JsonProperty("progressive")
    val progressive: Int,
    @param:JsonProperty("bit_depth")
    val bitDepth: Int,
    @param:JsonProperty("wrapper")
    val wrapper: String,
    @param:JsonProperty("create_time")
    val createTime: Long,
    @param:JsonProperty("update_time")
    val updateTime: Long,
    @param:JsonProperty("rotation")
    val rotation: Int,
    @param:JsonProperty("ext1")
    val ext1: Int,
    @param:JsonProperty("is_bluray")
    val isBluray: Boolean
)

@Immutable
data class AudioStream(
    @param:JsonProperty("media_guid")
    val mediaGuid: String,
    @param:JsonProperty("title")
    val title: String,
    @param:JsonProperty("guid")
    val guid: String,
    @param:JsonProperty("audio_type")
    val audioType: String,
    @param:JsonProperty("codec_name")
    val codecName: String,
    @param:JsonProperty("codec_type")
    val codecType: String,
    @param:JsonProperty("language")
    val language: String,
    @param:JsonProperty("channels")
    val channels: Int,
    @param:JsonProperty("profile")
    val profile: String,
    @param:JsonProperty("sample_rate")
    val sampleRate: String,
    @param:JsonProperty("is_default")
    val isDefault: Int,
    @param:JsonProperty("channel_layout")
    val channelLayout: String,
    @param:JsonProperty("duration")
    val duration: Int,
    @param:JsonProperty("index")
    val index: Int,
    @param:JsonProperty("bits_per_raw_sample")
    val bitsPerRawSample: String,
    @param:JsonProperty("bps")
    val bps: Int,
    @param:JsonProperty("create_time")
    val createTime: Long,
    @param:JsonProperty("update_time")
    val updateTime: Long,
    @param:JsonProperty("is_fake")
    val isFake: Boolean
)

@Immutable
data class SubtitleStream(
    @param:JsonProperty("media_guid")
    val mediaGuid: String,
    @param:JsonProperty("title")
    val title: String,
    @param:JsonProperty("guid")
    val guid: String,
    @param:JsonProperty("codec_name")
    val codecName: String,
    @param:JsonProperty("codec_type")
    val codecType: String,
    @param:JsonProperty("language")
    val language: String,
    @param:JsonProperty("forced")
    val forced: Int,
    @param:JsonProperty("index")
    val index: Int,
    @param:JsonProperty("is_default")
    val isDefault: Int,
    @param:JsonProperty("is_external")
    val isExternal: Int,
    @param:JsonProperty("format")
    val format: String,
    @param:JsonProperty("trim_id")
    val trimId: String,
    @param:JsonProperty("source_id")
    val sourceId: String,
    @param:JsonProperty("Source")
    val source: String,
    @param:JsonProperty("create_time")
    val createTime: Long,
    @param:JsonProperty("update_time")
    val updateTime: Long,
    @param:JsonProperty("extra_file")
    val extraFile: Int,
    @param:JsonProperty("is_bitmap")
    val isBitmap: Int,
    @param:JsonProperty("file_size")
    val fileSize: Int
)