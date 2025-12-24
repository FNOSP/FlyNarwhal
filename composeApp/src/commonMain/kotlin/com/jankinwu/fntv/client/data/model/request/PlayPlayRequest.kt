package com.jankinwu.fntv.client.data.model.request

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class PlayPlayRequest(
    @get:JsonProperty("media_guid")
    @param:JsonProperty("media_guid")
    val mediaGuid: String,

    @get:JsonProperty("video_guid")
    @param:JsonProperty("video_guid")
    val videoGuid: String,

    @get:JsonProperty("video_encoder")
    @param:JsonProperty("video_encoder")
    val videoEncoder: String,

    @get:JsonProperty("resolution")
    @param:JsonProperty("resolution")
    val resolution: String,

    @get:JsonProperty("bitrate")
    @param:JsonProperty("bitrate")
    val bitrate: Int,

    @get:JsonProperty("startTimestamp")
    @param:JsonProperty("startTimestamp")
    val startTimestamp: Int,

    @get:JsonProperty("audio_encoder")
    @param:JsonProperty("audio_encoder")
    val audioEncoder: String,

    @get:JsonProperty("audio_guid")
    @param:JsonProperty("audio_guid")
    val audioGuid: String,

    @get:JsonProperty("subtitle_guid")
    @param:JsonProperty("subtitle_guid")
    val subtitleGuid: String,

    @get:JsonProperty("channels")
    @param:JsonProperty("channels")
    val channels: Int,

    @get:JsonProperty("forced_sdr")
    @param:JsonProperty("forced_sdr")
    val forcedSdr: Int
)
