package com.jankinwu.fntv.client.data.model.request

import com.fasterxml.jackson.annotation.JsonProperty

data class SubtitleMarkRequest(
    @get:JsonProperty("media_guid")
    @param:JsonProperty("media_guid")
    val mediaGuid: String,

    @get:JsonProperty("filepaths")
    @param:JsonProperty("filepaths")
    val filePaths: List<String>
)