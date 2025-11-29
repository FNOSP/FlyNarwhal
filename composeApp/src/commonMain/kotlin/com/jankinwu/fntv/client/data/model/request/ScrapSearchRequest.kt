package com.jankinwu.fntv.client.data.model.request

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class ScrapSearchRequest(
    @param:JsonProperty("source")
    val source: String,

    @param:JsonProperty("source_keyword")
    val sourceKeyword: String,

    @param:JsonProperty("lan")
    val lan: String,

    @param:JsonProperty("item_guid")
    val itemGuid: String
)