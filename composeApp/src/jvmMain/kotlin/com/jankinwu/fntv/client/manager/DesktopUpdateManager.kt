package com.jankinwu.fntv.client.manager

import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.BuildConfig
import com.jankinwu.fntv.client.utils.DesktopUpdateInstaller
import com.jankinwu.fntv.client.utils.ExecutableDirectoryDetector
import com.jankinwu.fntv.client.utils.InstallationResult
import com.jankinwu.fntv.client.utils.inSystem
import com.jankinwu.fntv.client.utils.toKtPath
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.engine.okhttp.OkHttp
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.get
import io.ktor.client.request.prepareGet
import io.ktor.client.statement.bodyAsChannel
import io.ktor.http.contentLength
import io.ktor.http.HttpStatusCode
import io.ktor.serialization.jackson.jackson
import io.ktor.utils.io.readAvailable
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import com.fasterxml.jackson.databind.DeserializationFeature
import java.io.File
import java.io.FileOutputStream
import java.util.Locale
import kotlin.math.max

class DesktopUpdateManager : UpdateManager {
    private val logger = Logger.withTag("DesktopUpdateManager")
    private val scope = CoroutineScope(Dispatchers.IO)
    private var downloadJob: Job? = null
    private val _status = MutableStateFlow<UpdateStatus>(UpdateStatus.Idle)
    override val status: StateFlow<UpdateStatus> = _status.asStateFlow()

    private val _latestVersion = MutableStateFlow<UpdateInfo?>(null)
    override val latestVersion: StateFlow<UpdateInfo?> = _latestVersion.asStateFlow()

    private val client = HttpClient(OkHttp) {
        install(ContentNegotiation) {
            jackson {
                configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false)
            }
        }
    }

    override fun checkUpdate(proxyUrl: String, includePrerelease: Boolean, isManual: Boolean, autoDownload: Boolean) {
        scope.launch {
            _status.value = UpdateStatus.Checking
            try {
                val releases = if (includePrerelease) {
                    val allReleases = mutableListOf<GitHubRelease>()
                    var page = 1
                    var shouldContinue = true
                    val currentVersion = BuildConfig.VERSION_NAME

                    while (shouldContinue && page <= 10) { // Safety limit of 10 pages
                        val targetUrl = "https://api.github.com/repos/FNOSP/fntv-client-multiplatform/releases?per_page=5&page=$page"
                        logger.i("Checking updates from: $targetUrl")
                        val response = client.get(targetUrl)
                        
                        if (response.status == HttpStatusCode.NotFound) {
                            shouldContinue = false
                        } else {
                            val pageReleases = response.body<List<GitHubRelease>>()
                            if (pageReleases.isEmpty()) {
                                shouldContinue = false
                            } else {
                                // Check if we should continue fetching based on version
                                for (release in pageReleases) {
                                    val releaseVersion = release.name.removePrefix("v").trim()
                                    // If we find a version <= current version, we can stop fetching further pages
                                    // because releases are typically ordered by date/version descending.
                                    // However, we still include this release in the list to be safe,
                                    // as it might be the current version itself which is useful for comparison.
                                    if (compareVersions(releaseVersion, currentVersion) <= 0) {
                                        shouldContinue = false
                                    }
                                    allReleases.add(release)
                                }
                                
                                // If we have found valid candidates in this page, we might stop?
                                // User requirement: "if validReleases is empty, then request second page"
                                // This implies we check validity per page.
                                val osName = getSystemOS()
                                val arch = getSystemArch()
                                val targetExtension = when {
                                    osName.equals("Windows", ignoreCase = true) -> ".exe"
                                    osName.equals("MacOS", ignoreCase = true) -> ".dmg"
                                    osName.equals("Linux", ignoreCase = true) -> getLinuxPackageExtension()
                                    else -> null
                                }
                                
                                val validInPage = pageReleases.any { release ->
                                     release.assets.any { asset ->
                                        asset.name.contains(osName, ignoreCase = true) &&
                                        asset.name.contains(arch, ignoreCase = true) &&
                                        (targetExtension == null || asset.name.endsWith(targetExtension, ignoreCase = true))
                                    }
                                }
                                
                                if (validInPage) {
                                    shouldContinue = false
                                }
                                
                                page++
                            }
                        }
                    }
                    allReleases
                } else {
                    val targetUrl = "https://api.github.com/repos/FNOSP/fntv-client-multiplatform/releases/latest"
                    logger.i("Checking update from: $targetUrl")
                    val response = client.get(targetUrl)
                    if (response.status == HttpStatusCode.NotFound) {
                        emptyList()
                    } else {
                        listOf(response.body<GitHubRelease>())
                    }
                }

                if (releases.isEmpty()) {
                    logger.i("No releases found")
                    _status.value = UpdateStatus.UpToDate
                    _latestVersion.value = null
                    return@launch
                }

                val currentVersion = BuildConfig.VERSION_NAME
                val arch = getSystemArch()
                val osName = getSystemOS()
                val targetExtension = when {
                    osName.equals("Windows", ignoreCase = true) -> ".exe"
                    osName.equals("MacOS", ignoreCase = true) -> ".dmg"
                    osName.equals("Linux", ignoreCase = true) -> getLinuxPackageExtension()
                    else -> null
                }

                val validReleases = releases.filter { release ->
                    release.assets.any { asset ->
                        asset.name.contains(osName, ignoreCase = true) &&
                        asset.name.contains(arch, ignoreCase = true) &&
                        (targetExtension == null || asset.name.endsWith(targetExtension, ignoreCase = true))
                    }
                }

                if (validReleases.isEmpty()) {
                    logger.i("No compatible releases found")
                    _status.value = UpdateStatus.UpToDate
                    _latestVersion.value = null
                    return@launch
                }

                val sortedReleases = validReleases.sortedWith { r1, r2 ->
                    val v1 = r1.name.removePrefix("v").trim()
                    val v2 = r2.name.removePrefix("v").trim()
                    compareVersions(v2, v1) // Descending
                }

                val bestRelease = sortedReleases.first()
                val remoteVersion = bestRelease.name.removePrefix("v").trim()

                logger.i("Current version: $currentVersion, Best remote version: $remoteVersion")

                if (compareVersions(remoteVersion, currentVersion) > 0) {
                    val asset = bestRelease.assets.find {
                        it.name.contains(osName, ignoreCase = true) &&
                        it.name.contains(arch, ignoreCase = true) &&
                        (targetExtension == null || it.name.endsWith(targetExtension, ignoreCase = true))
                    }

                    if (asset != null) {
                        val updateInfo = UpdateInfo(
                            version = remoteVersion,
                            releaseNotes = bestRelease.body,
                            downloadUrl = asset.browserDownloadUrl,
                            fileName = asset.name,
                            size = asset.size
                        )

                        _latestVersion.value = updateInfo

                        val file = findUpdateFile(asset.name)

                        if (file.exists() && file.length() == asset.size) {
                            _status.value = UpdateStatus.ReadyToInstall(updateInfo, file.absolutePath)
                        } else {
                            _status.value = UpdateStatus.Available(updateInfo)
                            if (!isManual && autoDownload) {
                                logger.i("Auto downloading update")
                                downloadUpdate(proxyUrl, updateInfo)
                            }
                        }
                    } else {
                        _status.value = UpdateStatus.UpToDate
                        _latestVersion.value = null
                    }
                } else {
                    _status.value = UpdateStatus.UpToDate
                    _latestVersion.value = null
                }
            } catch (e: Exception) {
                logger.e("Update check failed", e)
                _status.value = UpdateStatus.Error("Update check failed: ${e.message}")
            }
        }
    }

    private fun getUpdateDirectory(): File {
        val osName = System.getProperty("os.name").lowercase(Locale.getDefault())
        return if (osName.contains("win")) {
            // Windows: Use the executable directory (usually writable by user in AppData or Portable mode)
            ExecutableDirectoryDetector.INSTANCE.getExecutableDirectory()
        } else {
            // Linux/macOS: Use a user-writable directory
            val userHome = System.getProperty("user.home")
            val appDataDir = when {
                osName.contains("mac") -> File(userHome, "Library/Caches/FnMedia/updates")
                else -> File(userHome, ".cache/FnMedia/updates") // Linux/Unix
            }
            if (!appDataDir.exists()) {
                appDataDir.mkdirs()
            }
            appDataDir
        }
    }

    private fun findUpdateFile(fileName: String): File {
        val updateDir = getUpdateDirectory()
        val fileInUpdateDir = File(updateDir, fileName)
        if (fileInUpdateDir.exists()) return fileInUpdateDir
        
        // Fallback to executable dir for backward compatibility (mostly for Windows)
        val executableDir = ExecutableDirectoryDetector.INSTANCE.getExecutableDirectory()
        val fileInExeDir = File(executableDir, fileName)
        if (fileInExeDir.exists()) return fileInExeDir
        
        // Fallback to user.dir
        val workingDir = File(System.getProperty("user.dir"))
        val fileInWorkingDir = File(workingDir, fileName)
        if (fileInWorkingDir.exists()) return fileInWorkingDir
        
        return fileInUpdateDir // Default to update dir even if not exists
    }

    override fun downloadUpdate(proxyUrl: String, info: UpdateInfo) {
        downloadJob?.cancel()
        downloadJob = scope.launch {
            _status.value = UpdateStatus.Downloading(0f, 0, info.size)
            val updateDir = getUpdateDirectory()
            val file = File(updateDir, info.fileName)
            try {
                val baseUrl = if (proxyUrl.isNotBlank()) {
                    if (proxyUrl.endsWith("/")) proxyUrl else "$proxyUrl/"
                } else {
                    ""
                }
                val url = if (baseUrl.isNotBlank()) {
                    "$baseUrl${info.downloadUrl}"
                } else {
                    info.downloadUrl
                }
                
                logger.i("Downloading update from: $url")

                client.prepareGet(url).execute { httpResponse ->
                    val channel = httpResponse.bodyAsChannel()
                    val totalSize = httpResponse.contentLength() ?: info.size
                    
                    var downloadedSize = 0L
                    val buffer = ByteArray(1024 * 8)
                    val output = FileOutputStream(file)
                    
                    try {
                        while (!channel.isClosedForRead) {
                            val read = channel.readAvailable(buffer, 0, buffer.size)
                            if (read <= 0) break
                            output.write(buffer, 0, read)
                            downloadedSize += read
                            if (totalSize > 0) {
                                _status.value = UpdateStatus.Downloading(downloadedSize.toFloat() / totalSize, downloadedSize, totalSize)
                            }
                        }
                    } finally {
                        output.close()
                    }
                }
                _status.value = UpdateStatus.Downloaded(info, file.absolutePath)
            } catch (_: CancellationException) {
                logger.i("Download cancelled")
                if (file.exists()) {
                    file.delete()
                }
                _status.value = UpdateStatus.Idle
            } catch (e: Exception) {
                logger.e("Download failed", e)
                _status.value = UpdateStatus.Error("Download failed: ${e.message}")
                if (file.exists()) {
                    file.delete()
                }
            }
        }
    }
    
    override fun installUpdate(info: UpdateInfo) {
        val file = findUpdateFile(info.fileName)
        
        val systemPath = file.toKtPath().inSystem
        
        val installer = DesktopUpdateInstaller.currentOS()
        scope.launch {
            val result = installer.install(systemPath, null)
             if (result is InstallationResult.Failed) {
                 _status.value = UpdateStatus.Error("Installation failed: ${result.message}")
            }
        }
    }

    override fun cancelDownload() {
        if (downloadJob?.isActive == true) {
            downloadJob?.cancel()
        }
    }

    override fun clearStatus() {
        _status.value = UpdateStatus.Idle
    }

    private fun compareVersions(v1: String, v2: String): Int {
        // Split into base version and pre-release suffix
        val v1Parts = v1.split("-", limit = 2)
        val v2Parts = v2.split("-", limit = 2)

        val base1 = v1Parts[0]
        val base2 = v2Parts[0]

        val parts1 = base1.split(".").mapNotNull { it.toIntOrNull() }
        val parts2 = base2.split(".").mapNotNull { it.toIntOrNull() }
        val length = max(parts1.size, parts2.size)

        for (i in 0 until length) {
            val p1 = parts1.getOrElse(i) { 0 }
            val p2 = parts2.getOrElse(i) { 0 }
            if (p1 != p2) return p1 - p2
        }

        // Base versions are equal, check suffixes
        val suffix1 = if (v1Parts.size > 1) v1Parts[1] else ""
        val suffix2 = if (v2Parts.size > 1) v2Parts[1] else ""

        if (suffix1.isEmpty() && suffix2.isEmpty()) return 0
        if (suffix1.isEmpty()) return 1 // v1 is stable, v2 is pre-release -> v1 > v2
        if (suffix2.isEmpty()) return -1 // v1 is pre-release, v2 is stable -> v1 < v2

        // Both are pre-releases, compare lexicographically (alpha < beta)
        return suffix1.compareTo(suffix2, ignoreCase = true)
    }

    private fun getSystemArch(): String {
        val osArch = System.getProperty("os.arch").lowercase(Locale.getDefault())
        return when {
            osArch.contains("aarch64") || osArch.contains("arm64") -> "aarch64"
            osArch.contains("amd64") || osArch.contains("x86_64") -> "amd64"
            else -> "x86" 
        }
    }

    private fun getSystemOS(): String {
        val osName = System.getProperty("os.name").lowercase(Locale.getDefault())
        return when {
            osName.contains("win") -> "Windows"
            osName.contains("mac") -> "MacOS"
            osName.contains("nix") || osName.contains("nux") -> "Linux"
            else -> "Unknown"
        }
    }

    private fun getLinuxPackageExtension(): String {
        try {
            val process = ProcessBuilder("cat", "/etc/os-release").start()
            val output = process.inputStream.bufferedReader().readText().lowercase()

            return when {
                output.contains("debian") || output.contains("ubuntu") -> ".deb"
                output.contains("fedora") || output.contains("rhel") || output.contains("centos") || output.contains("suse") -> ".rpm"
                output.contains("arch") || output.contains("manjaro") -> ".pkg"
                else -> ".deb" // Default to deb if unknown, or maybe handle differently
            }
        } catch (_: Exception) {
            return ".deb" // Fallback
        }
    }
}
