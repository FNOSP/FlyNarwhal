package com.jankinwu.fntv.client.data.model.request

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class ScrapRescrapRequest(
    @param:JsonProperty("item_guid")
    val itemGuid: String,

    @param:JsonProperty("source_id")
    val sourceId: String,

    @param:JsonProperty("source")
    val source: String,

    @param:JsonProperty("type")
    val type: String,

    @param:JsonProperty("media_guids")
    val mediaGuids: List<String>
)