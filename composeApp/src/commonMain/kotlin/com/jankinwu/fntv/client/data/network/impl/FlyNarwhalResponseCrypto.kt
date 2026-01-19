package com.jankinwu.fntv.client.data.network.impl

internal expect object FlyNarwhalResponseCrypto {
    fun clientKeyxBase64Url(): String
    fun decryptAesGcmBase64Url(ciphertextBase64Url: String, authCode: String): String
}
