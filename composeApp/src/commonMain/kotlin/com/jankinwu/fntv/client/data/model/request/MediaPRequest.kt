package com.jankinwu.fntv.client.data.model.request

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class MediaPRequest(
    @param:JsonProperty("req")
    var req: String?,

    @param:JsonProperty("reqid")
    var reqId: String?,

    @param:JsonProperty("playLink")
    val playLink: String,

    @param:JsonProperty("quality")
    val quality: Quality? = null,

    @param:JsonProperty("startTimestamp")
    val startTimestamp: Int?,

    @param:JsonProperty("clearCache")
    val clearCache: Boolean? = null,

    @param:JsonProperty("audioEncoder")
    val audioEncoder: String? = null,

    @param:JsonProperty("channels")
    val channels: Int? = null,

    @param:JsonProperty("audioIndex")
    val audioIndex: Int? = null,

    @param:JsonProperty("subtitleIndex")
    val subtitleIndex: Int? = null
) {
    @Immutable
    data class Quality(
        @param:JsonProperty("resolution")
        val resolution: String,

        @param:JsonProperty("bitrate")
        val bitrate: Int
    )
}