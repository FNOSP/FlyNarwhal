package com.jankinwu.fntv.client.data.model.response

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class MediaItemResponse(
    @get:JsonProperty("media_guid")
    @param:JsonProperty("media_guid")
    val mediaGuid: String,

    @get:JsonProperty("item_guid")
    @param:JsonProperty("item_guid")
    val itemGuid: String,

    @get:JsonProperty("filename")
    @param:JsonProperty("filename")
    val filename: String,

    @get:JsonProperty("file_path")
    @param:JsonProperty("file_path")
    val filePath: String,

    @get:JsonProperty("duration")
    @param:JsonProperty("duration")
    val duration: Int,

    @get:JsonProperty("create_time")
    @param:JsonProperty("create_time")
    val createTime: Long,

    @get:JsonProperty("media_stream")
    @param:JsonProperty("media_stream")
    val mediaStream: MediaStreamResponse?,
)

@Immutable
data class MediaStreamResponse(
    @get:JsonProperty("resolutions")
    @param:JsonProperty("resolutions")
    val resolutions: List<String>?,

    @get:JsonProperty("audio_type")
    @param:JsonProperty("audio_type")
    val audioType: List<String>?,

    @get:JsonProperty("color_range_type")
    @param:JsonProperty("color_range_type")
    val colorRangeType: List<String>?,
)