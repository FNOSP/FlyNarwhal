package com.jankinwu.fntv.client.manager

import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.BuildConfig
import com.jankinwu.fntv.client.data.store.AppSettingsStore
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
import java.security.SecureRandom
import java.security.cert.X509Certificate
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager
import kotlin.math.max

import java.util.concurrent.atomic.AtomicBoolean

import kotlinx.coroutines.delay

class DesktopUpdateManager : UpdateManager {
    private val logger = Logger.withTag("DesktopUpdateManager")
    private val scope = CoroutineScope(Dispatchers.IO)
    private var downloadJob: Job? = null
    private val _status = MutableStateFlow<UpdateStatus>(UpdateStatus.Idle)
    override val status: StateFlow<UpdateStatus> = _status.asStateFlow()

    private val _latestVersion = MutableStateFlow<UpdateInfo?>(null)
    override val latestVersion: StateFlow<UpdateInfo?> = _latestVersion.asStateFlow()

    private val suppressStatusUpdates = AtomicBoolean(false)
    private val isUserInitiatedDownload = AtomicBoolean(false)
    private var currentDownloadInfo: UpdateInfo? = null
    private var lastDownloadStatus: UpdateStatus.Downloading? = null

    private val client = HttpClient(OkHttp) {
        engine {
            config {
                val trustAllCerts = arrayOf<TrustManager>(@Suppress("CustomX509TrustManager")
                object : X509TrustManager {
                    @Suppress("TrustAllX509TrustManager")
                    override fun checkClientTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
                    @Suppress("TrustAllX509TrustManager")
                    override fun checkServerTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
                    override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
                })

                val sslContext = SSLContext.getInstance("SSL")
                sslContext.init(null, trustAllCerts, SecureRandom())

                sslSocketFactory(sslContext.socketFactory, trustAllCerts[0] as X509TrustManager)
                hostnameVerifier { _, _ -> true }
            }
        }
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
                val releases = fetchReleases()
                
                if (releases.isEmpty()) {
                    handleNoReleasesFound()
                    return@launch
                }

                val bestReleaseInfo = findBestRelease(releases, includePrerelease)
                if (bestReleaseInfo != null) {
                    processUpdateInfo(bestReleaseInfo, isManual, autoDownload, proxyUrl)
                } else {
                    handleNoCompatibleReleasesFound()
                }
            } catch (e: Exception) {
                logger.e("Update check failed", e)
                _status.value = UpdateStatus.Error("Update check failed: ${e.message}")
            }
        }
    }

    private suspend fun fetchReleases(): List<GitHubRelease> {
        return fetchReleasesWithPagination()
    }

    private suspend fun fetchReleasesWithPagination(): List<GitHubRelease> {
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
                    if (shouldStopFetching(pageReleases, currentVersion)) {
                        shouldContinue = false
                    }
                    allReleases.addAll(pageReleases)
                    page++
                }
            }
        }
        return allReleases
    }

    private fun shouldStopFetching(pageReleases: List<GitHubRelease>, currentVersion: String): Boolean {
        // Check if we should continue fetching based on version
        for (release in pageReleases) {
            val releaseVersion = release.name.removePrefix("v").trim()
            if (compareVersions(releaseVersion, currentVersion) <= 0) {
                return true
            }
        }
        
        // Also check if we found valid candidates in this page
        val osName = getSystemOS()
        val arch = getSystemArch()
        val targetExtension = getTargetExtension(osName)
        
        return pageReleases.any { release ->
            release.assets.any { asset ->
                asset.name.contains(osName, ignoreCase = true) &&
                asset.name.contains(arch, ignoreCase = true) &&
                (targetExtension == null || asset.name.endsWith(targetExtension, ignoreCase = true))
            }
        }
    }

    private fun handleNoReleasesFound() {
        logger.i("No releases found")
        _status.value = UpdateStatus.UpToDate
        _latestVersion.value = null
    }

    private fun handleNoCompatibleReleasesFound() {
        logger.i("No compatible releases found")
        _status.value = UpdateStatus.UpToDate
        _latestVersion.value = null
    }

    private fun findBestRelease(releases: List<GitHubRelease>, includePrerelease: Boolean): UpdateInfo? {
        val currentVersion = BuildConfig.VERSION_NAME
        val arch = getSystemArch()
        val osName = getSystemOS()
        val targetExtension = getTargetExtension(osName)

        val validReleases = releases.filter { release ->
            release.assets.any { asset ->
                asset.name.contains(osName, ignoreCase = true) &&
                asset.name.contains(arch, ignoreCase = true) &&
                (targetExtension == null || asset.name.endsWith(targetExtension, ignoreCase = true))
            }
        }.sortedWith { r1, r2 ->
            val v1 = r1.name.removePrefix("v").trim()
            val v2 = r2.name.removePrefix("v").trim()
            compareVersions(v2, v1) // Descending
        }

        if (validReleases.isEmpty()) return null

        val skippedVersions = AppSettingsStore.skippedVersions
        var targetRelease: GitHubRelease? = null
        var targetVersionString = ""

        for (release in validReleases) {
            val v = release.name.removePrefix("v").trim()
            
            if (skippedVersions.contains(v)) {
                logger.i("Skipping version: $v")
                continue
            }
            
            if (compareVersions(v, currentVersion) <= 0) {
                break
            }

            if (!includePrerelease && release.prerelease) {
                continue
            }

            targetRelease = release
            targetVersionString = v
            break
        }

        if (targetRelease == null) return null

        val notesBuilder = StringBuilder()
        var addedCount = 0
        for (release in validReleases) {
            val v = release.name.removePrefix("v").trim()
            if (compareVersions(v, targetVersionString) <= 0 && compareVersions(v, currentVersion) > 0) {
                if (addedCount > 0) {
                    notesBuilder.append("\n\n")
                }
                notesBuilder.append("#### ${release.name}\n")
                notesBuilder.append(release.body)
                addedCount++
            }
        }

        return targetRelease.let { release ->
            logger.i("Current version: $currentVersion, Target version: $targetVersionString")
            val asset = release.assets.find {
                it.name.contains(osName, ignoreCase = true) &&
                it.name.contains(arch, ignoreCase = true) &&
                (targetExtension == null || it.name.endsWith(targetExtension, ignoreCase = true))
            }
            asset?.let {
                UpdateInfo(
                    version = targetVersionString,
                    releaseNotes = notesBuilder.toString(),
                    downloadUrl = it.browserDownloadUrl,
                    hash = it.digest?.removePrefix("sha256:"),
                    fileName = it.name,
                    size = it.size
                )
            }
        }
    }

    private fun getTargetExtension(osName: String): String? {
        return when {
            osName.equals("Windows", ignoreCase = true) -> ".exe"
            osName.equals("MacOS", ignoreCase = true) -> ".dmg"
            osName.equals("Linux", ignoreCase = true) -> getLinuxPackageExtension()
            else -> null
        }
    }

    private fun processUpdateInfo(updateInfo: UpdateInfo, isManual: Boolean, autoDownload: Boolean, proxyUrl: String) {
        _latestVersion.value = updateInfo
        val file = findUpdateFile(updateInfo.fileName)

        if (file.exists() && file.length() == updateInfo.size) {
            _status.value = UpdateStatus.ReadyToInstall(updateInfo, file.absolutePath)
        } else {
            handleDownloadStatus(updateInfo, isManual, autoDownload, proxyUrl)
        }
    }

    private fun handleDownloadStatus(updateInfo: UpdateInfo, isManual: Boolean, autoDownload: Boolean, proxyUrl: String) {
        if (downloadJob?.isActive == true && currentDownloadInfo?.version == updateInfo.version) {
            if (isManual) {
                if (isUserInitiatedDownload.get()) {
                    suppressStatusUpdates.set(false)
                    lastDownloadStatus?.let { _status.value = it }
                } else {
                    logger.i("Download already in progress, showing available status")
                    suppressStatusUpdates.set(true)
                    _status.value = UpdateStatus.Available(updateInfo)
                }
            } else {
                _status.value = UpdateStatus.Available(updateInfo)
            }
        } else {
            _status.value = UpdateStatus.Available(updateInfo)
            if (!isManual && autoDownload) {
                logger.i("Auto downloading update")
                startDownload(proxyUrl, updateInfo, isBackground = true)
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

    override fun downloadUpdate(proxyUrl: String, info: UpdateInfo, force: Boolean) {
        startDownload(proxyUrl, info, isBackground = false, force = force)
    }

    private fun startDownload(proxyUrl: String, info: UpdateInfo, isBackground: Boolean, force: Boolean = false) {
        if (!force) {
            if (handleExistingDownload(info, isBackground)) return
            if (checkFileExists(info)) return
        }

        downloadJob?.cancel()
        currentDownloadInfo = info
        isUserInitiatedDownload.set(!isBackground)
        suppressStatusUpdates.set(isBackground)
        lastDownloadStatus = null
        
        launchDownloadJob(proxyUrl, info, isBackground)
    }

    private fun handleExistingDownload(info: UpdateInfo, isBackground: Boolean): Boolean {
        if (downloadJob?.isActive == true && currentDownloadInfo?.version == info.version) {
            logger.i("Joining existing download for version ${info.version}")
            isUserInitiatedDownload.set(!isBackground)
            suppressStatusUpdates.set(isBackground)
            // Force an update to current status so UI refreshes immediately
            if (!isBackground) {
                lastDownloadStatus?.let { _status.value = it }
            }
            return true
        }
        return false
    }

    private fun checkFileExists(info: UpdateInfo): Boolean {
        val existingFile = findUpdateFile(info.fileName)
        if (existingFile.exists() && existingFile.length() == info.size) {
            logger.i("Update file already exists and matches size. Skipping download.")
            _status.value = UpdateStatus.ReadyToInstall(info, existingFile.absolutePath)
            return true
        }
        return false
    }

    private fun launchDownloadJob(proxyUrl: String, info: UpdateInfo, isBackground: Boolean) {
        downloadJob = scope.launch {
            if (!isBackground) {
                _status.value = UpdateStatus.Downloading(0f, 0, info.size)
            }
            val updateDir = getUpdateDirectory()
            val file = File(updateDir, info.fileName)
            try {
                val url = prepareDownloadUrl(proxyUrl, info.downloadUrl)
                logger.i("Downloading update from: $url")
                
                downloadFile(url, file, info)
                
                if (!suppressStatusUpdates.get()) {
                    _status.value = UpdateStatus.Downloaded(info, file.absolutePath)
                }
            } catch (_: CancellationException) {
                handleDownloadCancellation(file)
            } catch (e: Exception) {
                handleDownloadError(e, file)
            }
        }
    }

    private fun prepareDownloadUrl(proxyUrl: String, downloadUrl: String): String {
        val baseUrl = if (proxyUrl.isNotBlank()) {
            if (proxyUrl.endsWith("/")) proxyUrl else "$proxyUrl/"
        } else {
            ""
        }
        return if (baseUrl.isNotBlank()) {
            "$baseUrl${downloadUrl}"
        } else {
            downloadUrl
        }
    }

    private suspend fun downloadFile(url: String, file: File, info: UpdateInfo) {
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
                        updateDownloadProgress(downloadedSize, totalSize)
                    }
                }
            } finally {
                output.close()
            }
        }
    }

    private fun updateDownloadProgress(downloadedSize: Long, totalSize: Long) {
        val status = UpdateStatus.Downloading(downloadedSize.toFloat() / totalSize, downloadedSize, totalSize)
        lastDownloadStatus = status
        if (!suppressStatusUpdates.get()) {
            _status.value = status
        }
    }

    private fun handleDownloadCancellation(file: File) {
        logger.i("Download cancelled")
        if (file.exists()) {
            file.delete()
        }
        _status.value = UpdateStatus.Idle
        currentDownloadInfo = null
        lastDownloadStatus = null
    }

    private fun handleDownloadError(e: Exception, file: File) {
        logger.e("Download failed", e)
        _status.value = UpdateStatus.Error("Download failed: ${e.message}")
        if (file.exists()) {
            file.delete()
        }
        currentDownloadInfo = null
        lastDownloadStatus = null
    }
    
    override fun installUpdate(info: UpdateInfo) {
        val file = findUpdateFile(info.fileName)
        
        scope.launch {
            if (info.hash != null) {
                _status.value = UpdateStatus.Verifying
                val isVerified = verifyHash(file, info.hash)
                 if (!isVerified) {
                     _status.value = UpdateStatus.VerificationFailed(info)
                     return@launch
                 }
                 _status.value = UpdateStatus.VerificationSuccess
                 delay(1000)
            }

            val systemPath = file.toKtPath().inSystem
            val installer = DesktopUpdateInstaller.currentOS()
            val result = installer.install(systemPath, null)
             if (result is InstallationResult.Failed) {
                 _status.value = UpdateStatus.Error("Installation failed: ${result.message}")
            }
        }
    }

    override fun deleteUpdate(info: UpdateInfo) {
        val file = findUpdateFile(info.fileName)
        if (file.exists()) {
            file.delete()
        }
        // If we are deleting the currently tracked update, clear status
        if (currentDownloadInfo?.version == info.version) {
            _status.value = UpdateStatus.Idle
            currentDownloadInfo = null
            lastDownloadStatus = null
        } else if (_status.value is UpdateStatus.VerificationFailed && (_status.value as UpdateStatus.VerificationFailed).info.version == info.version) {
            _status.value = UpdateStatus.Idle
        }
    }

    private fun verifyHash(updateFile: File, expectedHash: String): Boolean {
        try {
            val actualHash = calculateSha256(updateFile)
            
            logger.i("Hash verification - Expected: $expectedHash, Actual: $actualHash")
            
            return expectedHash.equals(actualHash, ignoreCase = true)
        } catch (e: Exception) {
            logger.e("Verification failed", e)
            return false
        }
    }

    private fun calculateSha256(file: File): String {
        val digest = java.security.MessageDigest.getInstance("SHA-256")
        val buffer = ByteArray(8192)
        val fis = java.io.FileInputStream(file)
        var bytesRead: Int
        while (fis.read(buffer).also { bytesRead = it } != -1) {
            digest.update(buffer, 0, bytesRead)
        }
        fis.close()
        val hash = digest.digest()
        return hash.joinToString("") { "%02x".format(it) }
    }

    override fun cancelDownload() {
        if (downloadJob?.isActive == true) {
            downloadJob?.cancel()
        }
    }

    override fun clearStatus() {
        _status.value = UpdateStatus.Idle
    }

    override fun skipVersion(version: String) {
        val skipped = AppSettingsStore.skippedVersions
        if (!skipped.contains(version)) {
            AppSettingsStore.skippedVersions = skipped + version
        }

        if (currentDownloadInfo?.version == version) {
            cancelDownload()
        }

        if (_latestVersion.value?.version == version) {
            _latestVersion.value = null
            val currentStatus = _status.value
            if (currentStatus is UpdateStatus.Available ||
                currentStatus is UpdateStatus.Downloading ||
                currentStatus is UpdateStatus.ReadyToInstall ||
                currentStatus is UpdateStatus.Downloaded) {
                _status.value = UpdateStatus.Idle
            }
        }
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
