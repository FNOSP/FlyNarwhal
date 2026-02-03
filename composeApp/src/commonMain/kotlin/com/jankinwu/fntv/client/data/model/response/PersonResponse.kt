package com.jankinwu.fntv.client.data.model.response

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class PersonResponse(
    @param:JsonProperty("guid")
    val guid: String,

    @param:JsonProperty("name")
    val name: String,

    @param:JsonProperty("imdb_id")
    val imdbId: String?,

    @param:JsonProperty("original_name")
    val originalName: String?,

    @param:JsonProperty("profile")
    val profile: String?,

    @param:JsonProperty("biography")
    val biography: String?,

    @param:JsonProperty("is_favorite")
    val isFavorite: Int
)
