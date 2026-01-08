package com.jankinwu.fntv.client.data.model.response

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class Danmaku(
    @param:JsonProperty("text")
    val text: String,
    @param:JsonProperty("time")
    val time: Double,
    @param:JsonProperty("color")
    val color: String,
    @param:JsonProperty("border")
    val border: Boolean = false,
    @param:JsonProperty("mode")
    val mode: Int = 0
)
