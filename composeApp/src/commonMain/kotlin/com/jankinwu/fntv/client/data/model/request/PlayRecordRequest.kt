package com.jankinwu.fntv.client.data.model.request

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class PlayRecordRequest(
    @get:JsonProperty("item_guid")
    @param:JsonProperty("item_guid")
    val itemGuid: String,

    @get:JsonProperty("media_guid")
    @param:JsonProperty("media_guid")
    val mediaGuid: String,

    @get:JsonProperty("video_guid")
    @param:JsonProperty("video_guid")
    val videoGuid: String,

    @get:JsonProperty("audio_guid")
    @param:JsonProperty("audio_guid")
    val audioGuid: String,

    @get:JsonProperty("subtitle_guid")
    @param:JsonProperty("subtitle_guid")
    val subtitleGuid: String?,

    @get:JsonProperty("resolution")
    @param:JsonProperty("resolution")
    val resolution: String,

    @get:JsonProperty("bitrate")
    @param:JsonProperty("bitrate")
    val bitrate: Int,

    @get:JsonProperty("ts")
    @param:JsonProperty("ts")
    val ts: Int,

    @get:JsonProperty("duration")
    @param:JsonProperty("duration")
    val duration: Int,

    @get:JsonProperty("play_link")
    @param:JsonProperty("play_link")
    val playLink: String? = null
)