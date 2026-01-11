package com.jankinwu.fntv.client.data.model.response

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class GenresResponse(
    @get:JsonProperty("id")
    @param:JsonProperty("id")
    val id: Int = 0,
    @get:JsonProperty("value")
    @param:JsonProperty("value")
    val value: String = "",
)
