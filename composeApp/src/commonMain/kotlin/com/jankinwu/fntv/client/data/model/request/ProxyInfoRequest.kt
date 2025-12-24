package com.jankinwu.fntv.client.data.model.request

import com.fasterxml.jackson.annotation.JsonProperty

data class ProxyInfoRequest (

    @get:JsonProperty("url")
    @param:JsonProperty("url")
    val url: String,

    @get:JsonProperty("cookie")
    @param:JsonProperty("cookie")
    val cookie: String
)