package com.jankinwu.fntv.client.data.network.impl

import java.io.ByteArrayOutputStream
import java.nio.charset.StandardCharsets
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.SecureRandom
import java.security.interfaces.XECPublicKey
import java.security.spec.NamedParameterSpec
import java.security.spec.XECPublicKeySpec
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.KeyAgreement
import javax.crypto.Mac
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec
import kotlin.test.Test
import kotlin.test.assertEquals

class FlyNarwhalResponseCryptoJvmTest {
    @Test
    fun decryptAesGcmBase64Url_shouldWorkWithInternalCrypto() {
        val plaintext = """{"ok":true}"""
        val clientKeyx = FlyNarwhalResponseCrypto.clientKeyxBase64Url()
        val clientPubRaw = base64UrlDecodeNoPadding(clientKeyx)
        val clientPubKey = decodeX25519PublicKeyFromRaw32(clientPubRaw)

        val serverPair = KeyPairGenerator.getInstance("X25519").generateKeyPair()
        val serverPubRaw = x25519PublicKeyToRaw32(serverPair.public as XECPublicKey)

        val authCodePayload = ByteArrayOutputStream().apply {
            write(1)
            write(serverPubRaw)
        }.toByteArray()
        val authCode = "FN1_" + Base64.getUrlEncoder().withoutPadding().encodeToString(authCodePayload)

        val sharedSecret = x25519SharedSecret(serverPair.private, clientPubKey)
        val info = concat("flynarwhal_resp_v1".toByteArray(StandardCharsets.UTF_8), serverPubRaw, clientPubRaw)
        val aesKey = hkdfSha256(sharedSecret, "flynarwhal".toByteArray(StandardCharsets.UTF_8), info, 32)

        val iv = ByteArray(12).also { SecureRandom().nextBytes(it) }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(aesKey, "AES"), GCMParameterSpec(128, iv))
        val ct = cipher.doFinal(plaintext.toByteArray(StandardCharsets.UTF_8))

        val ciphertextPayload = ByteArrayOutputStream().apply {
            write(1)
            write(iv)
            write(ct)
        }.toByteArray()
        val ciphertextBase64Url = Base64.getUrlEncoder().withoutPadding().encodeToString(ciphertextPayload)

        val out = FlyNarwhalResponseCrypto.decryptAesGcmBase64Url(ciphertextBase64Url, authCode)
        assertEquals(plaintext, out)
    }

    private fun base64UrlDecodeNoPadding(s: String): ByteArray {
        val padLen = (4 - (s.length % 4)) % 4
        val padded = s + "=".repeat(padLen)
        return Base64.getUrlDecoder().decode(padded)
    }

    private fun decodeX25519PublicKeyFromRaw32(raw32: ByteArray): java.security.PublicKey {
        val uBe = raw32.reversedArray()
        val u = java.math.BigInteger(1, uBe)
        val spec = XECPublicKeySpec(NamedParameterSpec("X25519"), u)
        return KeyFactory.getInstance("X25519").generatePublic(spec)
    }

    private fun x25519PublicKeyToRaw32(pub: XECPublicKey): ByteArray {
        val be = pub.u.toByteArray()
        val raw = ByteArray(32)
        val src = if (be.size > 32) be.copyOfRange(be.size - 32, be.size) else be
        val offset = 32 - src.size
        for (i in src.indices) {
            raw[offset + i] = src[i]
        }
        return raw.reversedArray()
    }

    private fun x25519SharedSecret(privateKey: java.security.PrivateKey, peerPublicKey: java.security.PublicKey): ByteArray {
        val ka = KeyAgreement.getInstance("X25519")
        ka.init(privateKey)
        ka.doPhase(peerPublicKey, true)
        return ka.generateSecret()
    }

    private fun hkdfSha256(ikm: ByteArray, salt: ByteArray, info: ByteArray, outLen: Int): ByteArray {
        val prk = hmacSha256(salt, ikm)
        val okm = ByteArray(outLen)
        var t = ByteArray(0)
        var produced = 0
        var counter = 1
        while (produced < outLen) {
            val data = concat(t, info, byteArrayOf(counter.toByte()))
            t = hmacSha256(prk, data)
            val take = minOf(t.size, outLen - produced)
            System.arraycopy(t, 0, okm, produced, take)
            produced += take
            counter++
        }
        return okm
    }

    private fun hmacSha256(key: ByteArray, data: ByteArray): ByteArray {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(key, "HmacSHA256"))
        return mac.doFinal(data)
    }

    private fun concat(vararg parts: ByteArray): ByteArray {
        val total = parts.sumOf { it.size }
        val out = ByteArray(total)
        var pos = 0
        for (p in parts) {
            System.arraycopy(p, 0, out, pos, p.size)
            pos += p.size
        }
        return out
    }
}
