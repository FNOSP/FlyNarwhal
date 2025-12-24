package com.jankinwu.fntv.client.data.model.response

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class MediaDbListResponse (
    @param:JsonProperty("guid")
    val guid: String,
    @param:JsonProperty("title")
    val title: String,
    @param:JsonProperty("posters")
    val posters: List<String>,
    @param:JsonProperty("category")
    val category: String,
    @param:JsonProperty("view_type")
    val viewType: Int
)