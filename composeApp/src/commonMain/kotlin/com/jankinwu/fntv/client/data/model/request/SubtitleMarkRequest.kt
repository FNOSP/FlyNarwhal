package com.jankinwu.fntv.client.data.model.request

import com.fasterxml.jackson.annotation.JsonProperty

data class SubtitleMarkRequest(
    @param:JsonProperty("media_guid")
    val mediaGuid: String,

    @param:JsonProperty("filepaths")
    val filePaths: List<String>
)