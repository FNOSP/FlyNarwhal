package com.jankinwu.fntv.client.data.model.request

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonInclude
import com.fasterxml.jackson.annotation.JsonProperty

@JsonInclude(JsonInclude.Include.NON_NULL)
@Immutable
data class PlayInfoRequest(
    @get:JsonProperty("item_guid")
    @param:JsonProperty("item_guid")
    val itemGuid: String,

    @get:JsonProperty("media_guid")
    @param:JsonProperty("media_guid")
    val mediaGuid: String?
)