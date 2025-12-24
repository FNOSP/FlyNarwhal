package com.jankinwu.fntv.client.data.model.response

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class QueryTagResponse(
    @get:JsonProperty("key")
    @param:JsonProperty("key")
    val key: String,
    @get:JsonProperty("value")
    @param:JsonProperty("value")
    val value: String
)
