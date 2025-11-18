package com.jankinwu.fntv.client.data.model.response

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class SubtitleSearchResponse(
    @param:JsonProperty("lan")
    val lan: String,
    
    @param:JsonProperty("subtitles")
    val subtitles: List<SearchingSubtitleInfo>
)

@Immutable
data class SearchingSubtitleInfo(
    @param:JsonProperty("filename")
    val filename: String,

    @param:JsonProperty("download")
    val download: Int,

    @param:JsonProperty("source_id")
    val sourceId: String,

    @param:JsonProperty("source")
    val source: String,

    @param:JsonProperty("trim_id")
    val trimId: String,

    @param:JsonProperty("format")
    val format: String
)