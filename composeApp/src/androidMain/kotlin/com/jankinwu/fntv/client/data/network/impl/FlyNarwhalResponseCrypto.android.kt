package com.jankinwu.fntv.client.data.network.impl

import java.io.ByteArrayOutputStream
import java.nio.charset.StandardCharsets
import java.security.KeyFactory
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.PrivateKey
import java.security.PublicKey
import java.security.interfaces.XECPublicKey
import java.security.spec.NamedParameterSpec
import java.security.spec.XECPublicKeySpec
import java.math.BigInteger
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.KeyAgreement
import javax.crypto.Mac
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

internal actual object FlyNarwhalResponseCrypto {
    private const val AES_TRANSFORM = "AES/GCM/NoPadding"
    private const val AES_KEY_LEN = 32
    private const val GCM_IV_LEN = 12
    private const val GCM_TAG_BITS = 128
    private const val AUTH_CODE_PREFIX = "FN1"
    private const val AUTH_CODE_PREFIX_DELIM = "_"
    private const val AUTH_CODE_PAYLOAD_LEN = 33
    private const val ENC_VERSION: Byte = 1

    private val x25519KeyPair: KeyPair by lazy {
        KeyPairGenerator.getInstance("X25519").generateKeyPair()
    }

    actual fun clientKeyxBase64Url(): String {
        val raw = x25519PublicKeyToRaw32(x25519KeyPair.public)
        return Base64.getUrlEncoder().withoutPadding().encodeToString(raw)
    }

    actual fun decryptAesGcmBase64Url(ciphertextBase64Url: String, authCode: String): String {
        val serverPubRaw = parseX25519PublicRawFromAuthCode(authCode)
        val serverPubKey = decodeX25519PublicKeyFromRaw32(serverPubRaw)
        val clientPubRaw = x25519PublicKeyToRaw32(x25519KeyPair.public)
        val sharedSecret = x25519SharedSecret(x25519KeyPair.private, serverPubKey)
        val info = concat("flynarwhal_resp_v1".toByteArray(StandardCharsets.UTF_8), serverPubRaw, clientPubRaw)
        val aesKey = hkdfSha256(sharedSecret, "flynarwhal".toByteArray(StandardCharsets.UTF_8), info, AES_KEY_LEN)

        val payload = base64UrlDecodeNoPadding(ciphertextBase64Url)
        if (payload.isEmpty() || payload[0] != ENC_VERSION) {
            throw IllegalArgumentException("Unsupported ciphertext version")
        }
        if (payload.size < 1 + GCM_IV_LEN + 1) {
            throw IllegalArgumentException("Invalid ciphertext length")
        }
        val iv = payload.copyOfRange(1, 1 + GCM_IV_LEN)
        val ct = payload.copyOfRange(1 + GCM_IV_LEN, payload.size)

        val cipher = Cipher.getInstance(AES_TRANSFORM)
        cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(aesKey, "AES"), GCMParameterSpec(GCM_TAG_BITS, iv))
        val pt = cipher.doFinal(ct)
        return String(pt, StandardCharsets.UTF_8)
    }

    private fun decodeX25519PublicKeyFromRaw32(raw32: ByteArray): PublicKey {
        if (raw32.size != 32) {
            throw IllegalArgumentException("Invalid X25519 public key length")
        }
        val be = raw32.reversedArray()
        val u = BigInteger(1, be)
        val spec = XECPublicKeySpec(NamedParameterSpec("X25519"), u)
        return KeyFactory.getInstance("X25519").generatePublic(spec)
    }

    private fun x25519SharedSecret(privateKey: PrivateKey, peerPublicKey: PublicKey): ByteArray {
        val ka = KeyAgreement.getInstance("X25519")
        ka.init(privateKey)
        ka.doPhase(peerPublicKey, true)
        return ka.generateSecret()
    }

    private fun parseX25519PublicRawFromAuthCode(authCode: String): ByteArray {
        val idx = authCode.indexOf(AUTH_CODE_PREFIX_DELIM)
        if (idx <= 0) {
            throw IllegalArgumentException("Invalid auth code format")
        }
        val prefix = authCode.substring(0, idx)
        if (prefix != AUTH_CODE_PREFIX) {
            throw IllegalArgumentException("Unsupported auth code prefix")
        }
        val payloadB64Url = authCode.substring(idx + 1)
        val payload = base64UrlDecodeNoPadding(payloadB64Url)
        if (payload.size != AUTH_CODE_PAYLOAD_LEN) {
            throw IllegalArgumentException("Invalid auth code payload length")
        }
        if (payload[0] != 1.toByte()) {
            throw IllegalArgumentException("Unsupported auth code version")
        }
        return payload.copyOfRange(1, 33)
    }

    private fun x25519PublicKeyToRaw32(publicKey: PublicKey): ByteArray {
        val xec = publicKey as? XECPublicKey ?: throw IllegalArgumentException("Not an X25519 public key")
        val be = bigIntToFixedLen(xec.u, 32)
        return be.reversedArray()
    }

    private fun bigIntToFixedLen(v: BigInteger, len: Int): ByteArray {
        val b = v.toByteArray()
        val offset = if (b.isNotEmpty() && b[0] == 0.toByte()) 1 else 0
        val effective = b.size - offset
        if (effective > len) {
            throw IllegalArgumentException("BigInteger too large")
        }
        val out = ByteArray(len)
        System.arraycopy(b, offset, out, len - effective, effective)
        return out
    }

    private fun hkdfSha256(ikm: ByteArray, salt: ByteArray, info: ByteArray, len: Int): ByteArray {
        val prk = hmacSha256(salt, ikm)
        var t = ByteArray(0)
        val out = ByteArrayOutputStream()
        var counter = 1
        while (out.size() < len) {
            val buf = ByteArrayOutputStream()
            buf.write(t)
            buf.write(info)
            buf.write(counter)
            t = hmacSha256(prk, buf.toByteArray())
            out.write(t)
            counter++
        }
        val okm = out.toByteArray()
        return okm.copyOf(len)
    }

    private fun hmacSha256(key: ByteArray, data: ByteArray): ByteArray {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(key, "HmacSHA256"))
        return mac.doFinal(data)
    }

    private fun base64UrlDecodeNoPadding(s: String): ByteArray {
        val mod = s.length % 4
        val padded = if (mod == 0) s else s + "====".substring(mod)
        return Base64.getUrlDecoder().decode(padded)
    }

    private fun concat(a: ByteArray, b: ByteArray, c: ByteArray): ByteArray {
        val out = ByteArray(a.size + b.size + c.size)
        System.arraycopy(a, 0, out, 0, a.size)
        System.arraycopy(b, 0, out, a.size, b.size)
        System.arraycopy(c, 0, out, a.size + b.size, c.size)
        return out
    }
}
