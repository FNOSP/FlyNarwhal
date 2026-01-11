package com.jankinwu.fntv.client.data.model.request

import com.fasterxml.jackson.annotation.JsonProperty

data class SetFnBaseUrlRequest(
    @get:JsonProperty("base_url")
    @param:JsonProperty("base_url")
    val baseUrl: String
)