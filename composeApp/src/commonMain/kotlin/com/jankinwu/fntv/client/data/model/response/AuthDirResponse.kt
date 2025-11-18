package com.jankinwu.fntv.client.data.model.response

import com.fasterxml.jackson.annotation.JsonProperty

data class AuthDirResponse(
    @param:JsonProperty("isFnOS")
    val isFnOS: Boolean,
    
    @param:JsonProperty("authDirList")
    val authDirList: List<AuthDir>
)

data class AuthDir(
    @param:JsonProperty("path")
    val path: String,
    
    @param:JsonProperty("storageType")
    val storageType: Int,
    
    @param:JsonProperty("uname")
    val uname: String,
    
    @param:JsonProperty("address")
    val address: String,
    
    @param:JsonProperty("comment")
    val comment: String,
    
    @param:JsonProperty("type")
    val type: Int,
    
    @param:JsonProperty("proto")
    val proto: String,
    
    @param:JsonProperty("username")
    val username: String,
    
    @param:JsonProperty("port")
    val port: Int,
    
    @param:JsonProperty("cloudStorageType")
    val cloudStorageType: Int
)