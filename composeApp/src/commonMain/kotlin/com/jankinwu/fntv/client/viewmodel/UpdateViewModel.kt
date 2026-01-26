package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.BuildConfig
import com.jankinwu.fntv.client.data.network.FlyNarwhalApi
import com.jankinwu.fntv.client.data.store.AppSettingsStore
import com.jankinwu.fntv.client.data.store.UserInfoMemoryCache
import com.jankinwu.fntv.client.manager.GitHubRelease
import com.jankinwu.fntv.client.manager.UpdateInfo
import com.jankinwu.fntv.client.manager.UpdateManager
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.get
import io.ktor.http.Url
import io.ktor.serialization.jackson.jackson
import com.fasterxml.jackson.databind.DeserializationFeature
import kotlinx.coroutines.Job
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime
import org.koin.java.KoinJavaComponent.inject
import kotlin.time.ExperimentalTime

class UpdateViewModel : BaseViewModel() {
    private val updateManager: UpdateManager by inject(UpdateManager::class.java)
    private val flyNarwhalApi: FlyNarwhalApi by inject(FlyNarwhalApi::class.java)
    
    val status = updateManager.status
    val latestVersion = updateManager.latestVersion
    
    private val _serverUpdateStatus = MutableStateFlow<String?>(null)
    val serverUpdateStatus = _serverUpdateStatus.asStateFlow()
    
    private val _flyNarwhalServerTestState = MutableStateFlow<UiState<String>>(UiState.Initial)
    val flyNarwhalServerTestState = _flyNarwhalServerTestState.asStateFlow()
    
    private val logger = Logger.withTag("UpdateViewModel")

    private var lastCheckTime = 0L
    private var scheduledCheckJob: Job? = null
    private val checkInterval = 5 * 60 * 1000L // 5 minutes (for prerelease toggle)
    private val periodicCheckInterval = 1 * 60 * 60 * 1000L // 4 hours
    private val serverCheckMutex = Mutex()
    private val serverUpdateMutex = Mutex()
    private var lastServerCheckTime = 0L
    private var lastServerUpdateRequestTime = 0L
    private val serverCheckCooldownMs = 10_000L
    private val serverUpdateCooldownMs = 60_000L

    private val githubClient = HttpClient {
        install(ContentNegotiation) {
            jackson {
                disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
            }
        }
    }

    init {
        startPeriodicCheck()
        startObservingUserScopedServerSettings()
        // Check server update on init if enabled
//        if (AppSettingsStore.flyNarwhalServerEnabled) {
//            checkServerUpdate()
//        }
    }

    private fun startObservingUserScopedServerSettings() {
        viewModelScope.launch {
            UserInfoMemoryCache.userInfo
                .map { it?.guid }
                .distinctUntilChanged()
                .collect {
                    if (AppSettingsStore.flyNarwhalServerEnabled) {
                        checkServerUpdate()
                    }
                }
        }
    }

    private fun startPeriodicCheck() {
        viewModelScope.launch {
            while (true) {
                // Check every 4 hours
                delay(periodicCheckInterval)
                
                // If not checked today, trigger an automatic check
                if (!isCheckedToday()) {
                    checkUpdate(isManual = false)
                }
            }
        }
    }

    @OptIn(ExperimentalTime::class)
    private fun isCheckedToday(): Boolean {
        logger.i("Checking if checked today...")
        val lastCheck = AppSettingsStore.lastUpdateCheckTime
        if (lastCheck == 0L) return false

        val currentInstant = kotlin.time.Clock.System.now()
        val lastCheckInstant = kotlin.time.Instant.fromEpochMilliseconds(lastCheck)
        
        val timeZone = TimeZone.currentSystemDefault()
        val currentDateTime = currentInstant.toLocalDateTime(timeZone)
        val lastCheckDateTime = lastCheckInstant.toLocalDateTime(timeZone)

        return currentDateTime.date == lastCheckDateTime.date
    }

    @OptIn(ExperimentalTime::class)
    fun checkUpdate(isManual: Boolean = true) {
        logger.i("Checking for updates...")
        val currentTime = kotlin.time.Clock.System.now().toEpochMilliseconds()
        lastCheckTime = currentTime
        AppSettingsStore.lastUpdateCheckTime = currentTime
        
        val proxyUrl = AppSettingsStore.githubResourceProxyUrl
        val includePrerelease = AppSettingsStore.includePrerelease
        val autoDownload = AppSettingsStore.autoDownloadUpdates
        updateManager.checkUpdate(proxyUrl, includePrerelease, isManual, autoDownload)
        
        if (AppSettingsStore.flyNarwhalServerEnabled) {
            checkServerUpdate()
        }
    }

    fun testFlyNarwhalServerConnection(baseUrl: String) {
        viewModelScope.launch {
            _flyNarwhalServerTestState.value = UiState.Loading
            try {
                val trimmed = baseUrl.trim()
                if (trimmed.isBlank()) {
                    throw IllegalArgumentException("服务端 URL 不能为空")
                }

                val parsed = try {
                    Url(trimmed)
                } catch (_: Exception) {
                    throw IllegalArgumentException("服务端 URL 不合法，请填写完整的 URL")
                }

                val protocol = parsed.protocol.name.lowercase()
                if (protocol != "http" && protocol != "https") {
                    throw IllegalArgumentException("服务端 URL 协议不合法，仅支持 http/https")
                }
                if (parsed.host.isBlank()) {
                    throw IllegalArgumentException("服务端 URL 不合法，缺少 host")
                }

                AppSettingsStore.flyNarwhalServerBaseUrl = trimmed
                val result = flyNarwhalApi.getVersion()
                if (!result.isSuccess()) {
                    throw IllegalStateException(result.msg.ifBlank { "请求失败" })
                }
                val version = result.data?.trim().orEmpty()
                if (version.isBlank()) {
                    throw IllegalStateException("服务端版本号为空")
                }

                val displayVersion = version.removeSuffix("-fnapp")
                _flyNarwhalServerTestState.value = UiState.Success(displayVersion)
            } catch (e: CancellationException) {
                throw e
            } catch (t: Throwable) {
                _flyNarwhalServerTestState.value = UiState.Error(t.message ?: "未知错误", exception = t)
            }
        }
    }

    fun clearFlyNarwhalServerTestState() {
        _flyNarwhalServerTestState.value = UiState.Initial
    }
    
    @OptIn(ExperimentalTime::class)
    fun checkServerUpdate() {
        if (!AppSettingsStore.flyNarwhalServerEnabled) return
        
        viewModelScope.launch {
            if (!serverCheckMutex.tryLock()) return@launch
            try {
                val now = kotlin.time.Clock.System.now().toEpochMilliseconds()
                if (now - lastServerCheckTime < serverCheckCooldownMs) return@launch

                lastServerCheckTime = now
                if (!AppSettingsStore.flyNarwhalServerEnabled) return@launch

                logger.i("Checking server version...")
                val result = flyNarwhalApi.getVersion()
                if (!result.isSuccess()) {
                    logger.e("Failed to get server version: ${result.msg}")
                    return@launch
                }
                
                val currentServerVersion = result.data
                if (currentServerVersion.isNullOrBlank()) {
                    logger.e("Server version is null or blank")
                    return@launch
                }
                val targetVersion = BuildConfig.FLY_NARWHAL_SERVER_VERSION
                
                logger.i("Server version: $currentServerVersion, Target: $targetVersion")
                
                if (compareVersions(currentServerVersion, targetVersion) < 0) {
                    logger.i("Server update needed. Fetching release info...")
                    _serverUpdateStatus.value = "Checking server update..."
                    val preferFnAppJar = currentServerVersion.endsWith("-fnapp")
                    performServerUpdate(targetVersion, preferFnAppJar)
                } else {
                    logger.i("Server is up to date.")
                }
                
            } catch (e: Exception) {
                logger.e("Error checking server update", e)
            } finally {
                serverCheckMutex.unlock()
            }
        }
    }

    @OptIn(ExperimentalTime::class)
    private suspend fun performServerUpdate(targetVersion: String, preferFnAppJar: Boolean) {
        if (!AppSettingsStore.flyNarwhalServerEnabled) return

        if (!serverUpdateMutex.tryLock()) return
        try {
            val now = kotlin.time.Clock.System.now().toEpochMilliseconds()
            if (now - lastServerUpdateRequestTime < serverUpdateCooldownMs) return
            lastServerUpdateRequestTime = now

            // 1. Fetch GitHub Release
            val release = fetchServerRelease(targetVersion)
            if (release == null) {
                logger.e("Target server version $targetVersion not found on GitHub")
                _serverUpdateStatus.value = "Server update not found"
                return
            }

            // 2. Find Jar Asset
            val targetSuffix = if (preferFnAppJar) ".jar.fnapp" else ".jar"
            val primaryAsset = release.assets.find { it.name.endsWith(targetSuffix) && !it.name.contains("sources") && !it.name.contains("javadoc") }
            val selectedAsset = primaryAsset ?: if (preferFnAppJar) {
                release.assets.find { it.name.endsWith(".jar") && !it.name.contains("sources") && !it.name.contains("javadoc") }
            } else {
                null
            }
            if (selectedAsset == null) {
                logger.e("Jar asset not found for version $targetVersion")
                _serverUpdateStatus.value = "Server update asset missing"
                return
            }

            // 3. Start Update on Server
            val downloadUrl = selectedAsset.browserDownloadUrl
            val hash = selectedAsset.digest
            val proxyUrl = AppSettingsStore.githubResourceProxyUrl
            
            logger.i("Starting server update: $downloadUrl")
            _serverUpdateStatus.value = "Starting server update..."
            
            flyNarwhalApi.startUpdate(downloadUrl, hash, proxyUrl).collect { status ->
                logger.i("Server update status: $status")
                _serverUpdateStatus.value = status
                
                if (status.contains("started") || status.contains("restart")) {
                    // Update started, poll for reconnection
                    pollForServerRecovery()
                }
            }
            
        } catch (e: Exception) {
            logger.e("Server update failed", e)
            _serverUpdateStatus.value = "Server update failed: ${e.message}"
        } finally {
            serverUpdateMutex.unlock()
        }
    }
    
    private suspend fun fetchServerRelease(version: String): GitHubRelease? {
        // We only look for the specific version tag
        val tagName = "v$version"
        val url = "https://api.github.com/repos/FNOSP/fly-narwhal-server/releases/tags/$tagName"
        
        return try {
            githubClient.get(url).body()
        } catch (e: Exception) {
            logger.e("Failed to fetch server release", e)
            null
        }
    }
    
    private fun pollForServerRecovery() {
        viewModelScope.launch {
            _serverUpdateStatus.value = "Waiting for server to restart..."
            val timeout = 5 * 60 * 1000L // 5 mins
            val startTime = System.currentTimeMillis()
            var connected = false
            
            while (System.currentTimeMillis() - startTime < timeout) {
                delay(5000)
                try {
                    val result = flyNarwhalApi.getVersion()
                    if (result.isSuccess()) {
                        connected = true
                        _serverUpdateStatus.value = "Server updated successfully to ${result.data}"
                        logger.i("Server recovered. New version: ${result.data}")
                        // Show toast or success message
                        // Since we don't have direct UI access, status flow update is key
                        break
                    }
                } catch (_: Exception) {
                    // Ignore connection errors
                }
            }
            
            if (!connected) {
                _serverUpdateStatus.value = "Server update timeout. Please check server logs."
                logger.e("Server recovery timeout")
                // Emit toast event?
            }
            
            delay(5000)
            _serverUpdateStatus.value = null // Clear status
        }
    }

    @OptIn(ExperimentalTime::class)
    fun onIncludePrereleaseChanged() {
        val currentTime = kotlin.time.Clock.System.now().toEpochMilliseconds()
        if (currentTime - lastCheckTime >= checkInterval) {
            // No restriction, check immediately
            checkUpdate(isManual = false)
            scheduledCheckJob?.cancel()
        } else {
            // Restricted, schedule a check if not already scheduled
            if (scheduledCheckJob?.isActive != true) {
                val delayTime = checkInterval - (currentTime - lastCheckTime)
                scheduledCheckJob = viewModelScope.launch {
                    delay(delayTime)
                    // Double check if we still need to run (in case a manual check happened)
                    if (kotlin.time.Clock.System.now().toEpochMilliseconds() - lastCheckTime >= checkInterval) {
                        checkUpdate(isManual = false)
                    }
                }
            }
        }
    }
    
    fun onFlyNarwhalServerEnabledChanged() {
        if (AppSettingsStore.flyNarwhalServerEnabled) {
            checkServerUpdate()
        }
    }

    fun downloadUpdate(info: UpdateInfo, force: Boolean = false) {
        val proxyUrl = AppSettingsStore.githubResourceProxyUrl
        updateManager.downloadUpdate(proxyUrl, info, force)
    }
    
    fun installUpdate(info: UpdateInfo) {
        updateManager.installUpdate(info)
    }

    fun deleteUpdate(info: UpdateInfo) {
        updateManager.deleteUpdate(info)
    }

    fun cancelDownload() {
        updateManager.cancelDownload()
    }
    
    fun clearStatus() {
        updateManager.clearStatus()
    }

    fun skipVersion(version: String) {
        updateManager.skipVersion(version)
    }
    
    private fun compareVersions(v1: String, v2: String): Int {
        val v1Parts = v1.split("-", limit = 2)
        val v2Parts = v2.split("-", limit = 2)
        val base1 = v1Parts[0]
        val base2 = v2Parts[0]
        val parts1 = base1.split(".").mapNotNull { it.toIntOrNull() }
        val parts2 = base2.split(".").mapNotNull { it.toIntOrNull() }
        val length = kotlin.math.max(parts1.size, parts2.size)

        for (i in 0 until length) {
            val p1 = parts1.getOrElse(i) { 0 }
            val p2 = parts2.getOrElse(i) { 0 }
            if (p1 != p2) return p1 - p2
        }
        
        // Suffix handling simplified
        return 0
    }
}
