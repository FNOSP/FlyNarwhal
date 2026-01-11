package com.jankinwu.fntv.client.data.model.request

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class SetConfigByItemRequest(
    @get:JsonProperty("guid")
    @param:JsonProperty("guid")
    val guid: String,

    @get:JsonProperty("skip_opening")
    @param:JsonProperty("skip_opening")
    val skipOpening: Int,

    @get:JsonProperty("skip_ending")
    @param:JsonProperty("skip_ending")
    val skipEnding: Int
)
