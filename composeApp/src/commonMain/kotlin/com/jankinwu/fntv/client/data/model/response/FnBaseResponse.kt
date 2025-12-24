package com.jankinwu.fntv.client.data.model.response

import com.fasterxml.jackson.annotation.JsonProperty
import kotlinx.serialization.Serializable

@Serializable
data class FnBaseResponse<T>(
    @get:JsonProperty("code")
    @param:JsonProperty("code")
    var code: Int = 0,
    @get:JsonProperty("msg")
    @param:JsonProperty("msg")
    var msg: String = "",
    @get:JsonProperty("data")
    @param:JsonProperty("data")
    var data: T? = null
)