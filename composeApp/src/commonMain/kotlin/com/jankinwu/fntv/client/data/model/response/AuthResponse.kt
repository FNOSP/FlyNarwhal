package com.jankinwu.fntv.client.data.model.response

import com.fasterxml.jackson.annotation.JsonProperty
import kotlinx.serialization.Serializable

@Serializable
data class AuthResponse(

    @get:JsonProperty("token")
    @param:JsonProperty("token")
    val token: String
)
