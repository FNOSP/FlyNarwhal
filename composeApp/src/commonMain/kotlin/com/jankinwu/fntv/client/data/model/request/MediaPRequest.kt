package com.jankinwu.fntv.client.data.model.request

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonInclude
import com.fasterxml.jackson.annotation.JsonProperty

@JsonInclude(JsonInclude.Include.NON_NULL)
@Immutable
data class MediaPRequest(
    @get:JsonProperty("req")
    @param:JsonProperty("req")
    var req: String? = null,

    @get:JsonProperty("reqid")
    @param:JsonProperty("reqid")
    var reqId: String? =  null,

    @get:JsonProperty("playLink")
    @param:JsonProperty("playLink")
    val playLink: String,

    @get:JsonProperty("quality")
    @param:JsonProperty("quality")
    val quality: Quality? = null,

    @get:JsonProperty("startTimestamp")
    @param:JsonProperty("startTimestamp")
    val startTimestamp: Int? = null,

    @get:JsonProperty("clearCache")
    @param:JsonProperty("clearCache")
    val clearCache: Boolean? = null,

    @get:JsonProperty("audioEncoder")
    @param:JsonProperty("audioEncoder")
    val audioEncoder: String? = null,

    @get:JsonProperty("channels")
    @param:JsonProperty("channels")
    val channels: Int? = null,

    @get:JsonProperty("audioIndex")
    @param:JsonProperty("audioIndex")
    val audioIndex: Int? = null,

    @get:JsonProperty("subtitleIndex")
    @param:JsonProperty("subtitleIndex")
    val subtitleIndex: Int? = null
) {
    @Immutable
    data class Quality(
        @get:JsonProperty("resolution")
        @param:JsonProperty("resolution")
        val resolution: String,

        @get:JsonProperty("bitrate")
        @param:JsonProperty("bitrate")
        val bitrate: Int
    )
}