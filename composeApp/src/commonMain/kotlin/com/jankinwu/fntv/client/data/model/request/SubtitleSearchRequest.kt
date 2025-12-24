package com.jankinwu.fntv.client.data.model.request

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class SubtitleSearchRequest(
    @get:JsonProperty("lan")
    @param:JsonProperty("lan")
    val lan: String,

    @get:JsonProperty("media_guid")
    @param:JsonProperty("media_guid")
    val mediaGuid: String
)