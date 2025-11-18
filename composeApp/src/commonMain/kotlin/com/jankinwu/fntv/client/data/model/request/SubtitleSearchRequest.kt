package com.jankinwu.fntv.client.data.model.request

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class SubtitleSearchRequest(
    @param:JsonProperty("lan")
    val lan: String,

    @param:JsonProperty("media_guid")
    val mediaGuid: String
)