package com.jankinwu.fntv.client.data.network.impl

import co.touchlab.kermit.Logger
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.jankinwu.fntv.client.BuildConfig
import com.jankinwu.fntv.client.utils.Context
import com.jankinwu.fntv.client.utils.PlatformInfo
import com.jankinwu.fntv.client.utils.getDeviceId
import com.russhwolf.settings.Settings
import com.russhwolf.settings.set
import io.ktor.client.HttpClient
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import io.ktor.serialization.jackson.jackson
import korlibs.crypto.MD5
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime
import kotlin.time.ExperimentalTime

/**
 * Service for reporting app launch/installation statistics to a backend.
 * Uses a unique device ID and request signing to prevent malicious abuse.
 */
class ReportingService(private val context: Context) {
    private val logger = Logger.withTag("ReportingService")
    private val settings = Settings()
    private val lastReportInfoKey = "last_report_info"

    // Values injected during build from GitHub Secrets or environment variables
    private val apiSecret = BuildConfig.REPORT_API_SECRET
    private val reportUrl = BuildConfig.REPORT_URL

    private val client = HttpClient {
        install(ContentNegotiation) {
            jackson()
        }
    }

    /**
     * Reports the app launch to the backend.
     * Ensures reporting happens only once per day for the same version to avoid redundant traffic.
     */
    @OptIn(ExperimentalTime::class)
    suspend fun reportLaunch() {
        val currentVersion = BuildConfig.VERSION_NAME
        val today = kotlin.time.Clock.System.now().toLocalDateTime(TimeZone.currentSystemDefault()).date.toString()
        val currentReportInfo = "$currentVersion|$today"

        val lastReportInfo = settings.getString(lastReportInfoKey, "")

        if (apiSecret.isBlank() || reportUrl.isBlank()) {
            // This is expected in development environments where secrets are not configured.
            logger.i { "Reporting skipped: apiSecret or reportUrl is not configured (normal in dev environment)" }
            return
        }

        if (lastReportInfo == currentReportInfo) {
            logger.i { "Already reported for version $currentVersion today ($today)" }
            return
        }

        withContext(Dispatchers.Default) {
            try {
                val deviceIdResult = getDeviceId(context)
                val deviceId = deviceIdResult.id
                val deviceIdType = deviceIdResult.type
                val timestamp = kotlin.time.Clock.System.now().toEpochMilliseconds()

                val bodyMap = mapOf<String, Any>(
                    "deviceId" to deviceId,
                    "deviceIdType" to deviceIdType,
                    "osName" to PlatformInfo.osName,
                    "osArch" to PlatformInfo.osArch,
                    "cpuModel" to PlatformInfo.cpuModel,
                    "gpuModel" to PlatformInfo.gpuModel,
                    "gpuType" to PlatformInfo.gpuType,
                    "version" to currentVersion,
                    "timestamp" to timestamp
                )

                // Sort keys to ensure consistent JSON string
                val sortedKeys = bodyMap.keys.sorted()
                val sortedBody = sortedKeys.associateWith { bodyMap[it]!! }

                val signature = generateSignature(sortedBody)

                logger.i { "Reporting launch: deviceId=$deviceId, version=$currentVersion" }

                val response = client.post(reportUrl) {
                    contentType(ContentType.Application.Json)
                    setBody(sortedBody + ("signature" to signature))
                }
                logger.i("Reporting request body: $sortedBody")
                if (response.status.isSuccess()) {
                    settings[lastReportInfoKey] = currentReportInfo
                    logger.i { "Successfully reported launch for version $currentVersion on $today" }
                } else {
                    logger.e { "Failed to report launch: ${response.status}" }
                }

            } catch (_: CancellationException) {
                logger.i { "Reporting launch cancelled" }
            } catch (e: Exception) {
                logger.e(e) { "Error reporting launch" }
            }
        }
    }

    private val objectMapper = jacksonObjectMapper()

    /**
     * Generates a MD5 signature to verify the request integrity.
     * The signature is a hash of (compressed JSON body + secret).
     */
    private fun generateSignature(bodyMap: Map<String, Any>): String {
        // Sort keys to ensure consistent JSON string
        val sortedKeys = bodyMap.keys.sorted()
        val sortedBody = sortedKeys.associateWith { bodyMap[it]!! }

        // Generate signature using compressed JSON string (matching backend Jackson logic)
        val jsonString = objectMapper.writeValueAsString(sortedBody)
        val compressedJson = jsonString.replace("\\s".toRegex(), "")

        return MD5.digest((compressedJson + apiSecret).encodeToByteArray()).hex
    }
}
