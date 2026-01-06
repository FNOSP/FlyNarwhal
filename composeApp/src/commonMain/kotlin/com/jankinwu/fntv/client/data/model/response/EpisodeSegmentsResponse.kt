package com.jankinwu.fntv.client.data.model.response

import com.fasterxml.jackson.annotation.JsonProperty
import kotlinx.serialization.Serializable
import java.math.BigDecimal

/**
 * Response model containing episode segments (intro/outro timestamps).
 */
@Serializable
data class EpisodeSegmentsResponse(
    @get:JsonProperty("intro")
    @param:JsonProperty("intro")
    val intro: EpisodeSegment?,

    @get:JsonProperty("credits")
    @param:JsonProperty("credits")
    val credits: EpisodeSegment?
)

/**
 * Model representing a segment of an episode.
 */
@Serializable
data class EpisodeSegment(
    @get:JsonProperty("start")
    @param:JsonProperty("start")
    val start: BigDecimal,

    @get:JsonProperty("end")
    @param:JsonProperty("end")
    val end: BigDecimal,

    @get:JsonProperty("valid")
    @param:JsonProperty("valid")
    val valid: Boolean
)

/**
 * Status of the smart analysis process.
 */
@Serializable
enum class AnalysisStatus(val description: String) {
    @JsonProperty("PREPARING")
    PREPARING("准备中"),
    @JsonProperty("PENDING")
    PENDING("等待中"),
    @JsonProperty("IN_PROGRESS")
    IN_PROGRESS("正在分析中"),
    @JsonProperty("PARTIAL_SUCCESS")
    PARTIAL_SUCCESS("部分成功"),
    @JsonProperty("COMPLETED")
    COMPLETED("已完成"),
    @JsonProperty("FAILED")
    FAILED("分析失败")
}
