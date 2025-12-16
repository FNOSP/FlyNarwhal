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
    val body: String,
    val prerelease: Boolean = false
)

data class GitHubAsset(
    val url: String,
    val name: String,
    @param:JsonProperty("browser_download_url")
    val browserDownloadUrl: String,
    val size: Long,
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
