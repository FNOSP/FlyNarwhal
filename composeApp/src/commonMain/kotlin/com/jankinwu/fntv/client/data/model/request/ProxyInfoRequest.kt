package com.jankinwu.fntv.client.data.model.request

import com.fasterxml.jackson.annotation.JsonProperty

data class ProxyInfoRequest (

    @param:JsonProperty("url")
    val url: String,

    @param:JsonProperty("cookie")
    val cookie: String
)