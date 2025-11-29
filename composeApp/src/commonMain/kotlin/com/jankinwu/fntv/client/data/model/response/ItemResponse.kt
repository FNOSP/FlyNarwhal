package com.jankinwu.fntv.client.data.model.response

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class ItemResponse(
    @param:JsonProperty("guid")
    val guid: String,

    @param:JsonProperty("imdb_id")
    val imdbId: String?,

    @param:JsonProperty("trim_id")
    val trimId: String,

    @param:JsonProperty("tv_title")
    val tvTitle: String,

    @param:JsonProperty("parent_title")
    val parentTitle: String,

    @param:JsonProperty("title")
    val title: String,

    @param:JsonProperty("original_title")
    val originalTitle: String?,

    @param:JsonProperty("backdrops")
    val backdrops: String?,

    @param:JsonProperty("posters")
    val posters: String,

    @param:JsonProperty("poster_width")
    val posterWidth: Int,

    @param:JsonProperty("poster_height")
    val posterHeight: Int,

    @param:JsonProperty("vote_average")
    val voteAverage: String,

    @param:JsonProperty("genres")
    val genres: List<Int>?,

    @param:JsonProperty("content_ratings")
    val contentRatings: String?,

    @param:JsonProperty("release_date")
    val releaseDate: String?,

    @param:JsonProperty("production_countries")
    val productionCountries: List<String>?,

    @param:JsonProperty("overview")
    val overview: String?,

    @param:JsonProperty("is_favorite")
    val isFavorite: Int,

    @param:JsonProperty("is_watched")
    val isWatched: Int,

    @param:JsonProperty("watched_ts")
    val watchedTs: Int,

    @param:JsonProperty("season_number")
    val seasonNumber: Int,

    @param:JsonProperty("number_of_seasons")
    val numberOfSeasons: Int,

    @param:JsonProperty("number_of_episodes")
    val numberOfEpisodes: Int,

    @param:JsonProperty("local_number_of_episodes")
    val localNumberOfEpisodes: Int,

    @param:JsonProperty("local_number_of_seasons")
    val localNumberOfSeasons: Int,

    @param:JsonProperty("can_play")
    val canPlay: Int,

    @param:JsonProperty("type")
    val type: String,

    @param:JsonProperty("play_error")
    val playError: String,

    @param:JsonProperty("parent_guid")
    val parentGuid: String,

    @param:JsonProperty("ancestor_name")
    val ancestorName: String,

    @param:JsonProperty("play_item_guid")
    val playItemGuid: String,

    @param:JsonProperty("duration")
    val duration: Int,

    @param:JsonProperty("logic_type")
    val logicType: Int,

    @param:JsonProperty("logos")
    val logos: String?,

    @param:JsonProperty("air_date")
    val airDate: String?,
)
