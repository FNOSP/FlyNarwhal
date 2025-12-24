package com.jankinwu.fntv.client.data.model.request

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class StreamRequest(
    @get:JsonProperty("media_guid")
    @param:JsonProperty("media_guid")
    val mediaGuid: String,
    
    @get:JsonProperty("ip")
    @param:JsonProperty("ip")
    val ip: String,
    
    @get:JsonProperty("header")
    @param:JsonProperty("header")
    val header: Header,
    
    @get:JsonProperty("level")
    @param:JsonProperty("level")
    val level: Int  = 1
) {
    data class Header(
        @get:JsonProperty("User-Agent")
        @param:JsonProperty("User-Agent")
        val userAgent: List<String>
    )
}