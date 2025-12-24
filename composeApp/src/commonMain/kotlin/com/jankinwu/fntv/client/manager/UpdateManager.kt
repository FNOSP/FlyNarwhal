package com.jankinwu.fntv.client.manager

import com.fasterxml.jackson.annotation.JsonProperty
import kotlinx.coroutines.flow.StateFlow

data class GitHubRelease(
    @get:JsonProperty("url")
    @param:JsonProperty("url")
    val url: String,
    @get:JsonProperty("assets_url")
    @param:JsonProperty("assets_url")
    val assetsUrl: String,
    @get:JsonProperty("html_url")
    @param:JsonProperty("html_url")
    val htmlUrl: String,
    @get:JsonProperty("tag_name")
    @param:JsonProperty("tag_name")
    val tagName: String,
    @get:JsonProperty("name")
    @param:JsonProperty("name")
    val name: String,
    @get:JsonProperty("assets")
    @param:JsonProperty("assets")
    val assets: List<GitHubAsset>,
    @get:JsonProperty("body")
    @param:JsonProperty("body")
    val body: String,
    @get:JsonProperty("prerelease")
    @param:JsonProperty("prerelease")
    val prerelease: Boolean = false
)

data class GitHubAsset(
    @get:JsonProperty("url")
    @param:JsonProperty("url")
    val url: String,
    @get:JsonProperty("name")
    @param:JsonProperty("name")
    val name: String,
    @get:JsonProperty("browser_download_url")
    @param:JsonProperty("browser_download_url")
    val browserDownloadUrl: String,
    @get:JsonProperty("size")
    @param:JsonProperty("size")
    val size: Long,
    @get:JsonProperty("digest")
    @param:JsonProperty("digest")
    val digest: String? = null
)

data class UpdateInfo(
    val version: String,
    val releaseNotes: String,
    val downloadUrl: String,
    val hash: String? = null,
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
    data class ReadyToInstall(val info: UpdateInfo, val filePath: String) : UpdateStatus()
    object Verifying : UpdateStatus()
    object VerificationSuccess : UpdateStatus()
    data class VerificationFailed(val info: UpdateInfo) : UpdateStatus()
}

interface UpdateManager {
    val status: StateFlow<UpdateStatus>
    val latestVersion: StateFlow<UpdateInfo?>
    fun checkUpdate(proxyUrl: String, includePrerelease: Boolean, isManual: Boolean = true, autoDownload: Boolean = false)
    fun downloadUpdate(proxyUrl: String, info: UpdateInfo, force: Boolean = false)
    fun installUpdate(info: UpdateInfo)
    fun deleteUpdate(info: UpdateInfo)
    fun cancelDownload()
    fun clearStatus()
    fun skipVersion(version: String)
}
