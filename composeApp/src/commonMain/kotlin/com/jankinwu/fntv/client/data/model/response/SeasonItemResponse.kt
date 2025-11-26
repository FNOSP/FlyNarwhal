package com.jankinwu.fntv.client.data.model.response

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class SeasonItemResponse(
    @param:JsonProperty("guid")
    val guid: String,

    @param:JsonProperty("lan")
    val lan: String,

    @param:JsonProperty("imdb_id")
    val imdbId: String?,

    @param:JsonProperty("trim_id")
    val trimId: String,

    @param:JsonProperty("tv_title")
    val tvTitle: String,

    @param:JsonProperty("parent_guid")
    val parentGuid: String,

    @param:JsonProperty("parent_title")
    val parentTitle: String,

    @param:JsonProperty("title")
    val title: String,

    @param:JsonProperty("type")
    val type: String,

    @param:JsonProperty("poster")
    val poster: String,

    @param:JsonProperty("poster_width")
    val posterWidth: Int,

    @param:JsonProperty("poster_height")
    val posterHeight: Int,

    @param:JsonProperty("is_favorite")
    val isFavorite: Int,

    @param:JsonProperty("watched")
    val watched: Int,

    @param:JsonProperty("watched_ts")
    val watchedTs: Int,

    @param:JsonProperty("vote_average")
    val voteAverage: String,

    @param:JsonProperty("media_stream")
    val mediaStream: MediaStream,

    @param:JsonProperty("season_number")
    val seasonNumber: Int,

    @param:JsonProperty("episode_number")
    val episodeNumber: Int,

    @param:JsonProperty("air_date")
    val airDate: String,

    @param:JsonProperty("number_of_seasons")
    val numberOfSeasons: Int,

    @param:JsonProperty("number_of_episodes")
    val numberOfEpisodes: Int,

    @param:JsonProperty("local_number_of_seasons")
    val localNumberOfSeasons: Int,

    @param:JsonProperty("local_number_of_episodes")
    val localNumberOfEpisodes: Int,

    @param:JsonProperty("status")
    val status: String,

    @param:JsonProperty("overview")
    val overview: String,

    @param:JsonProperty("ancestor_guid")
    val ancestorGuid: String,

    @param:JsonProperty("ancestor_name")
    val ancestorName: String,

    @param:JsonProperty("ancestor_category")
    val ancestorCategory: String,

    @param:JsonProperty("ts")
    val ts: Int,

    @param:JsonProperty("duration")
    val duration: Int,

    @param:JsonProperty("single_child_guid")
    val singleChildGuid: String,

    @param:JsonProperty("file_name")
    val fileName: String
)