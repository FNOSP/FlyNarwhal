package com.jankinwu.fntv.client.data.network.impl

import korlibs.crypto.MD5
import korlibs.crypto.SHA256
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class FnApiHelperTest {
    @Test
    fun genAuthxForFlyNarwhal_shouldReturnAuthxTriplet() {
        val authx = FnApiHelper.genAuthxForFlyNarwhal(url = "/api/danmu/ping")
        val map = authx.split("&")
            .mapNotNull {
                val kv = it.split("=", limit = 2)
                if (kv.size == 2) kv[0] to kv[1] else null
            }
            .toMap()

        assertTrue(map["nonce"].orEmpty().isNotBlank())
        assertTrue(map["timestamp"].orEmpty().isNotBlank())
        assertTrue(map["sign"].orEmpty().length == 32)
    }

    @Test
    fun genSignxForFlyNarwhal_shouldMatchExpectedSha256() {
        val url = "/api/danmu/ping"
        val authx = "nonce=123456&timestamp=1700000000000&sign=cafebabe"
        val publicKeyBase64 = "ZHVtbXktcHVia2V5"
        val dataJsonMd5 = MD5.digest("".encodeToByteArray()).hex

        val expected = SHA256.digest(
            "1700000000000_123456_cafebabe_${dataJsonMd5}_${url}_${publicKeyBase64}".encodeToByteArray()
        ).hex

        val actual = FnApiHelper.genSignxForFlyNarwhal(
            url = url,
            authx = authx,
            parameters = null,
            data = null,
            publicKeyBase64 = publicKeyBase64
        )
        assertEquals(expected, actual)
    }
}

