package com.jankinwu.fntv.client.data.model.response

import com.fasterxml.jackson.annotation.JsonProperty

/**
 * Generic response wrapper for Smart Analysis API.
 */
data class SmartAnalysisResult<T>(
    @get:JsonProperty("code")
    @param:JsonProperty("code")
    val code: Int = 0,
    @get:JsonProperty("msg")
    @param:JsonProperty("msg")
    val msg: String = "",
    @get:JsonProperty("data")
    @param:JsonProperty("data")
    val data: T? = null,
    @get:JsonProperty("success")
    @param:JsonProperty("success")
    val success: Boolean? = null
) {
    /**
     * Returns true if the request was successful.
     */
    fun isSuccess(): Boolean = success == true || code == 0 || code in 200..299
}
