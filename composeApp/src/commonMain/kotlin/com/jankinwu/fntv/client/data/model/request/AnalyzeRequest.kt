package com.jankinwu.fntv.client.data.model.request

import com.fasterxml.jackson.annotation.JsonProperty

/**
 * Request model for starting a smart analysis of a TV season.
 */
data class AnalyzeRequest(
    @param:JsonProperty("season_guid")
    val seasonGuid: String,

    @param:JsonProperty("season_path")
    val seasonPath: String,

    @param:JsonProperty("episodes")
    val episodes: List<QueuedEpisode>,

    @param:JsonProperty("tv_title")
    val tvTitle: String,

    @param:JsonProperty("season_number")
    val seasonNumber: Int
)

/**
 * Model representing an episode queued for analysis.
 */
data class QueuedEpisode(
    @param:JsonProperty("guid")
    val guid: String,
    @param:JsonProperty("file_path")
    val filePath: String,
    @param:JsonProperty("episode_number")
    val episodeNumber: Int,

    @param:JsonProperty("season_number")
    val seasonNumber: Int
)
