package com.jankinwu.fntv.client.data.model.request

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class ScrapRescrapRequest(
    @get:JsonProperty("item_guid")
    @param:JsonProperty("item_guid")
    val itemGuid: String,

    @get:JsonProperty("source_id")
    @param:JsonProperty("source_id")
    val sourceId: String,

    @get:JsonProperty("source")
    @param:JsonProperty("source")
    val source: String,

    @get:JsonProperty("type")
    @param:JsonProperty("type")
    val type: String,

    @get:JsonProperty("media_guids")
    @param:JsonProperty("media_guids")
    val mediaGuids: List<String>
)