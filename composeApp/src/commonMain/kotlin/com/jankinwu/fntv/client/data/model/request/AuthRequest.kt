package com.jankinwu.fntv.client.data.model.request

import com.fasterxml.jackson.annotation.JsonProperty
import kotlinx.serialization.Serializable

@Serializable
data class AuthRequest(
    @get:JsonProperty("source")
    @param:JsonProperty("source")
    val source: String,

    @get:JsonProperty("code")
    @param:JsonProperty("code")
    val code: String
)
