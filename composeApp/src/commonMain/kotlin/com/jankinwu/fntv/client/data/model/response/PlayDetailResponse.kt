package com.jankinwu.fntv.client.data.model.response

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class PlayDetailResponse(
    @get:JsonProperty("guid")
    @param:JsonProperty("guid")
    val guid: String,
    @get:JsonProperty("lan")
    @param:JsonProperty("lan")
    val lan: String?,
    @get:JsonProperty("douban_id")
    @param:JsonProperty("douban_id")
    val douBanId: Int?,
    @get:JsonProperty("imdb_id")
    @param:JsonProperty("imdb_id")
    val imdbId: String?,
    @get:JsonProperty("tv_title")
    @param:JsonProperty("tv_title")
    val tvTitle: String?,
    @get:JsonProperty("parent_guid")
    @param:JsonProperty("parent_guid")
    val parentGuid: String?,
    @get:JsonProperty("parent_title")
    @param:JsonProperty("parent_title")
    val parentTitle: String?,
    @get:JsonProperty("title")
    @param:JsonProperty("title")
    val title: String,
    @get:JsonProperty("type")
    @param:JsonProperty("type")
    val type: String,
    @get:JsonProperty("poster")
    @param:JsonProperty("poster")
    val poster: String?,
    @get:JsonProperty("poster_width")
    @param:JsonProperty("poster_width")
    val posterWidth: Int?,
    @get:JsonProperty("poster_height")
    @param:JsonProperty("poster_height")
    val posterHeight: Int?,
    @get:JsonProperty("runtime")
    @param:JsonProperty("runtime")
    val runtime: Int?,
    @get:JsonProperty("is_favorite")
    @param:JsonProperty("is_favorite")
    val isFavorite: Int,
    @get:JsonProperty("watched")
    @param:JsonProperty("watched")
    val watched: Int,
    @get:JsonProperty("watched_ts")
    @param:JsonProperty("watched_ts")
    val watchedTs: Int,
    @get:JsonProperty("media_stream")
    @param:JsonProperty("media_stream")
    val mediaStream: MediaStream,
    @get:JsonProperty("season_number")
    @param:JsonProperty("season_number")
    val seasonNumber: Int?,
    @get:JsonProperty("episode_number")
    @param:JsonProperty("episode_number")
    val episodeNumber: Int,
    @get:JsonProperty("number_of_seasons")
    @param:JsonProperty("number_of_seasons")
    val numberOfSeasons: Int?,
    @get:JsonProperty("number_of_episodes")
    @param:JsonProperty("number_of_episodes")
    val numberOfEpisodes: Int?,
    @get:JsonProperty("local_number_of_seasons")
    @param:JsonProperty("local_number_of_seasons")
    val localNumberOfSeasons: Int?,
    @get:JsonProperty("local_number_of_episodes")
    @param:JsonProperty("local_number_of_episodes")
    val localNumberOfEpisodes: Int?,
    @get:JsonProperty("status")
    @param:JsonProperty("status")
    val status: String?,
    @get:JsonProperty("overview")
    @param:JsonProperty("overview")
    val overview: String? = null,
    @get:JsonProperty("ancestor_guid")
    @param:JsonProperty("ancestor_guid")
    val ancestorGuid: String?,
    @get:JsonProperty("ancestor_name")
    @param:JsonProperty("ancestor_name")
    val ancestorName: String?,
    @get:JsonProperty("ancestor_category")
    @param:JsonProperty("ancestor_category")
    val ancestorCategory: String?,
    @get:JsonProperty("ts")
    @param:JsonProperty("ts")
    val ts: Long,
    @get:JsonProperty("duration")
    @param:JsonProperty("duration")
    val duration: Int,
    @get:JsonProperty("single_child_guid")
    @param:JsonProperty("single_child_guid")
    val singleChildGuid: String?,
    @get:JsonProperty("media_guid")
    @param:JsonProperty("media_guid")
    val mediaGuid: String?,
    @get:JsonProperty("audio_guid")
    @param:JsonProperty("audio_guid")
    val audioGuid: String?,
    @get:JsonProperty("video_guid")
    @param:JsonProperty("video_guid")
    val videoGuid: String?,
    @get:JsonProperty("subtitle_guid")
    @param:JsonProperty("subtitle_guid")
    val subtitleGuid: String?,
    @get:JsonProperty("file_name")
    @param:JsonProperty("file_name")
    val fileName: String?
)
