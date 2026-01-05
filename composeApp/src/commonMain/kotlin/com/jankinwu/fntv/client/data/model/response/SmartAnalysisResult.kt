package com.jankinwu.fntv.client.data.model.response

/**
 * Generic response wrapper for Smart Analysis API.
 */
data class SmartAnalysisResult<T>(
    val code: Int,
    val msg: String,
    val data: T?,
    val success: Boolean? = null
) {
    /**
     * Returns true if the request was successful.
     */
    fun isSuccess(): Boolean = success == true || code == 0 || code in 200..299
}
