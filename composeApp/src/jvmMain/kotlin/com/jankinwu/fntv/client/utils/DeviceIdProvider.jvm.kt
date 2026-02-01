package com.jankinwu.fntv.client.utils

import oshi.SystemInfo
import com.russhwolf.settings.Settings
import java.util.UUID

actual fun getDeviceId(context: Context): DeviceId {
    return try {
        val systemInfo = SystemInfo()
        val hardware = systemInfo.hardware
        val computerSystem = hardware.computerSystem
        
        // List of common placeholder values to ignore
        val invalidValues = setOf(
            "unknown", "none", "default string", "to be filled by o.e.m.", 
            "00000000-0000-0000-0000-000000000000", "not available",
            "system serial number", "chassis serial number", "to be filled by oem",
            "system product name", "to be filled by o.e.m.", "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF",
            "03000200-0400-0500-0006-000700080009", "5EKPM18320000397", "FEFEFEFE-FEFE-FEFE-FEFE-FEFEFEFEFEFE",
            "Not Applicable", "Not Applicable", "Standard"
        )
        
        fun String?.isValidId(): Boolean {
            if (this.isNullOrBlank()) return false
            val lower = this.lowercase().trim()
            // Check if it's one of the known invalid strings or just a bunch of zeros/ones/Xs
            if (lower in invalidValues) return false
            if (lower.all { it == '0' || it == '1' || it == 'x' || it == '-' }) return false
            return lower.length > 3 // Too short is probably invalid
        }

        // Try to get serial number, if not available use hardware UUID, then fallback to baseboard serial
        val hardwareSerial = computerSystem.serialNumber.takeIf { it.isValidId() }
        if (hardwareSerial != null) return DeviceId(hardwareSerial, "hardware_serial")

        val hardwareUuid = computerSystem.hardwareUUID.takeIf { it.isValidId() }
        if (hardwareUuid != null) return DeviceId(hardwareUuid, "hardware_uuid")

        val baseboardSerial = computerSystem.baseboard.serialNumber.takeIf { it.isValidId() }
        if (baseboardSerial != null) return DeviceId(baseboardSerial, "baseboard_serial")
            
        // Fallback to persisted UUID if hardware fails
        val settings = Settings()
        val savedId = settings.getString("fallback_device_id", "")
        if (savedId.isNotEmpty()) {
            return DeviceId(savedId, "persisted_uuid")
        }

        // Generate and persist a new UUID if none exists
        val newId = "jvm_${UUID.randomUUID()}"
        settings.putString("fallback_device_id", newId)
        DeviceId(newId, "generated_uuid")
    } catch (_: Exception) {
        DeviceId("error_jvm", "error")
    }
}
