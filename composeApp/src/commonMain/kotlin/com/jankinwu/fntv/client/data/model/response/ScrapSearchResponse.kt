package com.jankinwu.fntv.client.data.model.response

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class ScrapSearchResponse(
    @param:JsonProperty("source")
    val source: String,

    @param:JsonProperty("source_id")
    val sourceId: String,

    @param:JsonProperty("title")
    val title: String,

    @param:JsonProperty("type")
    val type: String,

    @param:JsonProperty("poster_link")
    val posterLink: String,

    @param:JsonProperty("first_air_date")
    val firstAirDate: String,

    @param:JsonProperty("last_air_date")
    val lastAirDate: String? = null,

    @param:JsonProperty("number_of_seasons")
    val numberOfSeasons: Int,

    @param:JsonProperty("genres")
    val genres: List<Int>,

    @param:JsonProperty("production_countries")
    val productionCountries: List<String>
)