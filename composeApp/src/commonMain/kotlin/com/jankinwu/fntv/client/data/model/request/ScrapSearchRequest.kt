package com.jankinwu.fntv.client.data.model.request

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class ScrapSearchRequest(
    @get:JsonProperty("source")
    @param:JsonProperty("source")
    val source: String,

    @get:JsonProperty("source_keyword")
    @param:JsonProperty("source_keyword")
    val sourceKeyword: String,

    @get:JsonProperty("lan")
    @param:JsonProperty("lan")
    val lan: String,

    @get:JsonProperty("item_guid")
    @param:JsonProperty("item_guid")
    val itemGuid: String
)