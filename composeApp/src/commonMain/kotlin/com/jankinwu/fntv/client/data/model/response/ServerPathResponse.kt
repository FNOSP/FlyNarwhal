package com.jankinwu.fntv.client.data.model.response

import com.fasterxml.jackson.annotation.JsonProperty

data class ServerPathResponse(
    @param:JsonProperty("filename")
    val filename: String,

    @param:JsonProperty("is_dir")
    val isDir: Boolean,

    @param:JsonProperty("trim_name")
    val trimName: String,

    @param:JsonProperty("trim_id")
    val trimId: String
)