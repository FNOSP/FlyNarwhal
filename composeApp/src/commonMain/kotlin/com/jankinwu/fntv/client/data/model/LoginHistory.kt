package com.jankinwu.fntv.client.data.model

import com.fasterxml.jackson.annotation.JsonProperty

data class LoginHistory(
    @get:JsonProperty("host")
    @param:JsonProperty("host")
    val host: String,
    
    @get:JsonProperty("port")
    @param:JsonProperty("port")
    val port: Int,
    
    @get:JsonProperty("username")
    @param:JsonProperty("username")
    val username: String,
    
    @get:JsonProperty("password")
    @param:JsonProperty("password")
    val password: String?,
    
    @get:JsonProperty("isHttps")
    @param:JsonProperty("isHttps")
    val isHttps: Boolean,
    
    @get:JsonProperty("rememberMe")
    @param:JsonProperty("rememberMe")
    val rememberMe: Boolean,
    
    @get:JsonProperty("lastLoginTimestamp")
    @param:JsonProperty("lastLoginTimestamp")
    val lastLoginTimestamp: Long = System.currentTimeMillis()
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is LoginHistory) return false
        
        return host == other.host && 
               port == other.port && 
               username == other.username
    }
    
    override fun hashCode(): Int {
        var result = host.hashCode()
        result = 31 * result + port
        result = 31 * result + username.hashCode()
        return result
    }
    
    fun getEndpoint(): String {
        return if (port != 0) {
            "$host:$port"
        } else {
            host
        }
    }
}