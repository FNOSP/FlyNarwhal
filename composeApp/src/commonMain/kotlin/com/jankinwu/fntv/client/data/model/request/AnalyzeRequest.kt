package com.jankinwu.fntv.client.data.model.request

import com.fasterxml.jackson.annotation.JsonProperty

/**
 * Request model for starting a smart analysis of a TV season.
 */
data class AnalyzeRequest(
    @param:JsonProperty("season_guid")
    @get:JsonProperty("season_guid")
    val seasonGuid: String,

    @param:JsonProperty("season_path")
    @get:JsonProperty("season_path")
    val seasonPath: String,

    @param:JsonProperty("episodes")
    @get:JsonProperty("episodes")
    val episodes: List<QueuedEpisode>,

    @param:JsonProperty("tv_title")
    @get:JsonProperty("tv_title")
    val tvTitle: String,

    @param:JsonProperty("season_number")
    @get:JsonProperty("season_number")
    val seasonNumber: Int
)

/**
 * Model representing an episode queued for analysis.
 */
data class QueuedEpisode(
    @param:JsonProperty("guid")
    @get:JsonProperty("guid")
    val guid: String,
    @param:JsonProperty("file_path")
    @get:JsonProperty("file_path")
    val filePath: String,
    @param:JsonProperty("episode_number")
    @get:JsonProperty("episode_number")
    val episodeNumber: Int,

    @param:JsonProperty("season_number")
    @get:JsonProperty("season_number")
    val seasonNumber: Int
)

/**
 * Request model for updating analysis status for multiple seasons.
 */
data class UpdateSeasonStatusRequest(
    @param:JsonProperty("season_guids")
    @get:JsonProperty("season_guids")
    val seasonGuids: List<String>,
    @param:JsonProperty("status")
    @get:JsonProperty("status")
    val status: String
)
