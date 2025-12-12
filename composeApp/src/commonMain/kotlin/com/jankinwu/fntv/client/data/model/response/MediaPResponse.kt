package com.jankinwu.fntv.client.data.model.response

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class MediaTranscodeResponse(
    @param:JsonProperty("audio")
    val audio: Audio,

    @param:JsonProperty("bitrate")
    val bitrate: Int,

    @param:JsonProperty("reqid")
    val reqId: String,

    @param:JsonProperty("resolution")
    val resolution: String,

    @param:JsonProperty("result")
    val result: String,

    @param:JsonProperty("transcoded")
    val transcoded: Boolean,

    @param:JsonProperty("transcodingReason")
    val transcodingReason: List<Int>,

    @param:JsonProperty("video")
    val video: Video
) {
    @Immutable
    data class Audio(
        @param:JsonProperty("channels")
        val channels: Int,

        @param:JsonProperty("encoder")
        val encoder: String
    )

    @Immutable
    data class Video(
        @param:JsonProperty("corruptedFrames")
        val corruptedFrames: Int,

        @param:JsonProperty("decodeMethod")
        val decodeMethod: Int,

        @param:JsonProperty("droppedFrames")
        val droppedFrames: Int,

        @param:JsonProperty("dynamicRange")
        val dynamicRange: String,

        @param:JsonProperty("encodeMethod")
        val encodeMethod: Int,

        @param:JsonProperty("encoder")
        val encoder: String,

        @param:JsonProperty("selectedGpu")
        val selectedGpu: String,

        @param:JsonProperty("transcodingRate")
        val transcodingRate: String
    )
}

@Immutable
data class MediaResetQualityResponse(
    @param:JsonProperty("hlsTime")
    val hlsTime: Int,

    @param:JsonProperty("reqid")
    val reqId: String,

    @param:JsonProperty("result")
    val result: String,

    @param:JsonProperty("updateM3u8")
    val updateM3u8: Boolean
)
