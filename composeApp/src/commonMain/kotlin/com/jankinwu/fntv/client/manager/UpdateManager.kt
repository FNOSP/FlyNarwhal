package com.jankinwu.fntv.client.manager

import com.fasterxml.jackson.annotation.JsonProperty
import kotlinx.coroutines.flow.StateFlow

data class GitHubRelease(
    val url: String,
    @param:JsonProperty("assets_url")
    val assetsUrl: String,
    @param:JsonProperty("html_url")
    val htmlUrl: String,
    @param:JsonProperty("tag_name")
    val tagName: String,
    val name: String,
    val assets: List<GitHubAsset>,
    val body: String
)

data class GitHubAsset(
    val url: String,
    val name: String,
    @param:JsonProperty("browser_download_url")
    val browserDownloadUrl: String,
    val size: Long
)

data class UpdateInfo(
    val version: String,
    val releaseNotes: String,
    val downloadUrl: String,
    val fileName: String,
    val size: Long
)

sealed class UpdateStatus {
    object Idle : UpdateStatus()
    object Checking : UpdateStatus()
    data class Available(val info: UpdateInfo) : UpdateStatus()
    object UpToDate : UpdateStatus()
    data class Error(val message: String) : UpdateStatus()
    data class Downloading(val progress: Float, val currentBytes: Long, val totalBytes: Long) : UpdateStatus()
    data class Downloaded(val info: UpdateInfo, val filePath: String) : UpdateStatus()
}

interface UpdateManager {
    val status: StateFlow<UpdateStatus>
    fun checkUpdate(proxyUrl: String)
    fun downloadUpdate(proxyUrl: String, info: UpdateInfo)
    fun installUpdate(info: UpdateInfo)
    fun cancelDownload()
    fun clearStatus()
}
