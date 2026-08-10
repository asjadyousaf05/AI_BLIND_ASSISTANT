package com.example.ai_blind_assistant

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Handler
import android.os.Looper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import java.net.InetAddress
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import org.json.JSONObject

/**
 * Android-only facilities that shouldn't be emulated with ordinary
 * SharedPreferences: Keystore-backed credential storage and bounded NSD/mDNS
 * discovery. Values and pairing material are never logged.
 */
class WearablePlatformHandler(
    private val context: Context,
) : MethodChannel.MethodCallHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val nsdManager = context.getSystemService(Context.NSD_SERVICE) as NsdManager
    private val securePreferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    private var discoveryListener: NsdManager.DiscoveryListener? = null
    private var discoveryResult: MethodChannel.Result? = null
    private val discoveredServices = linkedMapOf<String, Map<String, Any>>()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "secureWrite" -> secureWrite(call, result)
            "secureRead" -> secureRead(call, result)
            "secureDelete" -> secureDelete(call, result)
            "secureClear" -> secureClear(result)
            "discover" -> discover(call, result)
            "getOrCreateWearableClientId" -> getOrCreateClientId(result)
            "writeWearableCredential" -> writeWearableCredential(call, result)
            "readWearableCredential" -> readWearableCredential(call, result)
            "readLastWearableCredential" -> readLastWearableCredential(result)
            "deleteWearableCredential" -> deleteWearableCredential(call, result)
            "discoverWearableDevices" -> discover(call, result)
            "resolveWearableDevice" -> resolveWearableDevice(call, result)
            "stopDiscovery" -> {
                finishDiscovery()
                result.success(true)
            }
            "stopWearableDiscovery" -> {
                finishDiscovery()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        finishDiscovery()
    }

    private fun secureWrite(call: MethodCall, result: MethodChannel.Result) {
        val key = call.argument<String>("key")
        val value = call.argument<String>("value")
        if (!validStorageKey(key) || value == null) {
            result.error("invalid_arguments", "A valid key and value are required.", null)
            return
        }

        try {
            val record = encrypt(value)
            val saved = securePreferences.edit().putString(key, record).commit()
            if (saved) result.success(true) else result.error(
                "secure_storage_write_failed",
                "The paired-device credential could not be stored.",
                null,
            )
        } catch (_: Exception) {
            result.error(
                "secure_storage_write_failed",
                "The Android secure store is unavailable.",
                null,
            )
        }
    }

    private fun secureRead(call: MethodCall, result: MethodChannel.Result) {
        val key = call.argument<String>("key")
        if (!validStorageKey(key)) {
            result.error("invalid_arguments", "A valid key is required.", null)
            return
        }

        val record = securePreferences.getString(key, null)
        if (record == null) {
            result.success(null)
            return
        }

        try {
            result.success(decrypt(record))
        } catch (_: Exception) {
            // A restored or corrupt ciphertext must not be treated as a valid
            // credential. Remove it and require explicit re-pairing.
            securePreferences.edit().remove(key).commit()
            result.error(
                "secure_storage_read_failed",
                "The paired-device credential is unavailable. Forget and pair the device again.",
                null,
            )
        }
    }

    private fun secureDelete(call: MethodCall, result: MethodChannel.Result) {
        val key = call.argument<String>("key")
        if (!validStorageKey(key)) {
            result.error("invalid_arguments", "A valid key is required.", null)
            return
        }
        result.success(securePreferences.edit().remove(key).commit())
    }

    private fun secureClear(result: MethodChannel.Result) {
        try {
            securePreferences.edit().clear().commit()
            val keyStore = keyStore()
            if (keyStore.containsAlias(KEY_ALIAS)) keyStore.deleteEntry(KEY_ALIAS)
            result.success(true)
        } catch (_: Exception) {
            result.error(
                "secure_storage_clear_failed",
                "The paired-device credential could not be cleared.",
                null,
            )
        }
    }

    private fun getOrCreateClientId(result: MethodChannel.Result) {
        val existing = securePreferences.getString(CLIENT_ID_KEY, null)
        if (!existing.isNullOrBlank()) {
            result.success(existing)
            return
        }
        val created = UUID.randomUUID().toString()
        if (securePreferences.edit().putString(CLIENT_ID_KEY, created).commit()) {
            result.success(created)
        } else {
            result.error(
                "client_id_unavailable",
                "The local wearable client identifier could not be stored.",
                null,
            )
        }
    }

    private fun writeWearableCredential(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *>
        val deviceId = arguments?.get("deviceId") as? String
        val deviceName = arguments?.get("deviceName") as? String
        val host = arguments?.get("host") as? String
        val port = arguments?.get("port") as? Number
        val serviceName = arguments?.get("serviceName") as? String
        val clientId = arguments?.get("clientId") as? String
        val credentialId = arguments?.get("credentialId") as? String
        val secret = arguments?.get("secret") as? String
        val createdAt = arguments?.get("createdAt") as? String
        if (!validIdentifier(deviceId) ||
            deviceName.isNullOrBlank() ||
            deviceName.length > 128 ||
            host.isNullOrBlank() ||
            host.length > 253 ||
            host.any { it.isWhitespace() } ||
            port == null ||
            port.toInt() !in 1..65535 ||
            serviceName.isNullOrBlank() ||
            serviceName.length > 128 ||
            !validIdentifier(clientId) ||
            !validIdentifier(credentialId) ||
            secret.isNullOrBlank() ||
            secret.length > 1024 ||
            createdAt.isNullOrBlank()
        ) {
            result.error("invalid_credential", "The wearable credential is invalid.", null)
            return
        }
        try {
            val value = JSONObject()
                .put("deviceId", deviceId)
                .put("deviceName", deviceName)
                .put("host", host)
                .put("port", port.toInt())
                .put("serviceName", serviceName)
                .put("clientId", clientId)
                .put("credentialId", credentialId)
                .put("secret", secret)
                .put("createdAt", createdAt)
                .toString()
            val stored = securePreferences.edit()
                .putString(credentialStorageKey(deviceId!!), encrypt(value))
                .putString(LAST_DEVICE_ID_KEY, deviceId)
                .commit()
            if (stored) result.success(null) else result.error(
                "secure_storage_write_failed",
                "The wearable credential could not be stored.",
                null,
            )
        } catch (_: Exception) {
            result.error(
                "secure_storage_write_failed",
                "The Android secure store is unavailable.",
                null,
            )
        }
    }

    private fun readWearableCredential(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.argument<String>("deviceId")
        if (!validIdentifier(deviceId)) {
            result.error("invalid_credential", "The wearable device identifier is invalid.", null)
            return
        }
        try {
            result.success(readCredential(deviceId!!))
        } catch (_: Exception) {
            securePreferences.edit().remove(credentialStorageKey(deviceId!!)).commit()
            result.error(
                "secure_storage_read_failed",
                "The paired-device credential is unavailable. Forget and pair again.",
                null,
            )
        }
    }

    private fun readLastWearableCredential(result: MethodChannel.Result) {
        val deviceId = securePreferences.getString(LAST_DEVICE_ID_KEY, null)
        if (deviceId == null) {
            result.success(null)
            return
        }
        try {
            result.success(readCredential(deviceId))
        } catch (_: Exception) {
            securePreferences.edit()
                .remove(LAST_DEVICE_ID_KEY)
                .remove(credentialStorageKey(deviceId))
                .commit()
            result.error(
                "secure_storage_read_failed",
                "The saved wearable credential is unavailable. Pair again.",
                null,
            )
        }
    }

    private fun deleteWearableCredential(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.argument<String>("deviceId")
        if (!validIdentifier(deviceId)) {
            result.error("invalid_credential", "The wearable device identifier is invalid.", null)
            return
        }
        val editor = securePreferences.edit().remove(credentialStorageKey(deviceId!!))
        if (securePreferences.getString(LAST_DEVICE_ID_KEY, null) == deviceId) {
            editor.remove(LAST_DEVICE_ID_KEY)
        }
        editor.commit()
        result.success(null)
    }

    private fun readCredential(deviceId: String): Map<String, Any>? {
        val record = securePreferences.getString(credentialStorageKey(deviceId), null)
            ?: return null
        val value = JSONObject(decrypt(record))
        return mapOf(
            "deviceId" to value.getString("deviceId"),
            "deviceName" to value.getString("deviceName"),
            "host" to value.getString("host"),
            "port" to value.getInt("port"),
            "serviceName" to value.getString("serviceName"),
            "clientId" to value.getString("clientId"),
            "credentialId" to value.getString("credentialId"),
            "secret" to value.getString("secret"),
            "createdAt" to value.getString("createdAt"),
        )
    }

    private fun discover(call: MethodCall, result: MethodChannel.Result) {
        if (discoveryResult != null) {
            result.error("discovery_busy", "Device discovery is already running.", null)
            return
        }

        val requestedType = call.argument<String>("serviceType") ?: DEFAULT_SERVICE_TYPE
        val serviceType = if (requestedType.endsWith(".")) requestedType else "$requestedType."
        val timeoutMs = (call.argument<Number>("timeoutMs")?.toLong() ?: 5000L)
            .coerceIn(1000L, 15000L)
        discoveredServices.clear()
        discoveryResult = result

        val listener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(regType: String) = Unit

            override fun onServiceFound(service: NsdServiceInfo) {
                if (!service.serviceType.equals(serviceType, ignoreCase = true)) return
                @Suppress("DEPRECATION")
                nsdManager.resolveService(
                    service,
                    object : NsdManager.ResolveListener {
                        override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) = Unit

                        override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
                            val resolvedHost = serviceInfo.host ?: return
                            if (!isPrivateOrLocal(resolvedHost)) return
                            val address = resolvedHost.hostAddress ?: return
                            val attributes = serviceInfo.attributes
                            val advertisedDeviceId = attributes["deviceId"]
                                ?.toString(StandardCharsets.UTF_8)
                                ?.takeIf(::validIdentifier)
                            val advertisedName = attributes["deviceName"]
                                ?.toString(StandardCharsets.UTF_8)
                                ?.takeIf { it.isNotBlank() && it.length <= 128 }
                            val deviceId = advertisedDeviceId ?: "mdns:${serviceInfo.serviceName}"
                            val key = "$deviceId:$address:${serviceInfo.port}"
                            discoveredServices[key] = mapOf(
                                "id" to deviceId,
                                "name" to (advertisedName ?: serviceInfo.serviceName),
                                "host" to address,
                                "port" to serviceInfo.port,
                                "source" to "discovered",
                                "serviceName" to serviceInfo.serviceType,
                                "serviceType" to serviceInfo.serviceType,
                            )
                        }
                    },
                )
            }

            override fun onServiceLost(service: NsdServiceInfo) = Unit

            override fun onDiscoveryStopped(serviceType: String) = Unit

            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                failDiscovery("Device discovery could not start (code $errorCode).")
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                finishDiscovery()
            }
        }
        discoveryListener = listener

        try {
            nsdManager.discoverServices(serviceType, NsdManager.PROTOCOL_DNS_SD, listener)
            mainHandler.postDelayed({ finishDiscovery() }, timeoutMs)
        } catch (_: Exception) {
            failDiscovery("Device discovery is unavailable on this network.")
        }
    }

    private fun resolveWearableDevice(call: MethodCall, result: MethodChannel.Result) {
        val target = call.argument<String>("hostOrServiceName")?.trim()
        if (target.isNullOrEmpty() || target.length > 253 || target.any { it.isWhitespace() }) {
            result.error("invalid_host", "Enter a valid local hostname or address.", null)
            return
        }
        Thread {
            try {
                val resolved = InetAddress.getAllByName(target)
                    .firstOrNull(::isPrivateOrLocal)
                mainHandler.post {
                    if (resolved == null) {
                        result.success(null)
                    } else {
                        result.success(
                            mapOf(
                                "id" to "manual:$target",
                                "name" to target,
                                "host" to resolved.hostAddress,
                                "port" to DEFAULT_PORT,
                                "source" to "manual",
                                "serviceName" to DEFAULT_SERVICE_TYPE.removeSuffix("."),
                            ),
                        )
                    }
                }
            } catch (_: Exception) {
                mainHandler.post {
                    result.error(
                        "resolve_failed",
                        "The local wearable hostname could not be resolved.",
                        null,
                    )
                }
            }
        }.apply {
            name = "aiba-wearable-resolver"
            isDaemon = true
            start()
        }
    }

    private fun finishDiscovery() {
        val listener = discoveryListener
        discoveryListener = null
        if (listener != null) {
            try {
                nsdManager.stopServiceDiscovery(listener)
            } catch (_: Exception) {
                // The framework throws when discovery already stopped. State is
                // still cleared and the bounded request is completed below.
            }
        }
        mainHandler.removeCallbacksAndMessages(null)
        val pending = discoveryResult
        discoveryResult = null
        pending?.success(discoveredServices.values.toList())
        discoveredServices.clear()
    }

    private fun failDiscovery(message: String) {
        val pending = discoveryResult
        discoveryResult = null
        discoveryListener = null
        mainHandler.removeCallbacksAndMessages(null)
        discoveredServices.clear()
        pending?.error("discovery_failed", message, null)
    }

    private fun validStorageKey(key: String?): Boolean =
        key != null && key.matches(Regex("[a-zA-Z0-9_.-]{1,80}"))

    private fun validIdentifier(value: String?): Boolean =
        value != null && value.matches(Regex("[A-Za-z0-9_.:-]{1,128}"))

    private fun isPrivateOrLocal(address: InetAddress): Boolean {
        if (address.isLoopbackAddress || address.isLinkLocalAddress || address.isSiteLocalAddress) {
            return true
        }
        val bytes = address.address
        return bytes.size == 16 && (bytes[0].toInt() and 0xfe) == 0xfc
    }

    private fun credentialStorageKey(deviceId: String) = "credential.$deviceId"

    private fun encrypt(value: String): String {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
        val ciphertext = cipher.doFinal(value.toByteArray(StandardCharsets.UTF_8))
        return listOf(
            RECORD_VERSION,
            Base64.encodeToString(cipher.iv, Base64.NO_WRAP),
            Base64.encodeToString(ciphertext, Base64.NO_WRAP),
        ).joinToString(":")
    }

    private fun decrypt(record: String): String {
        val parts = record.split(":", limit = 3)
        if (parts.size != 3 || parts[0] != RECORD_VERSION) {
            throw IllegalStateException("Unsupported secure record")
        }
        val cipher = Cipher.getInstance(TRANSFORMATION)
        val iv = Base64.decode(parts[1], Base64.NO_WRAP)
        val ciphertext = Base64.decode(parts[2], Base64.NO_WRAP)
        cipher.init(Cipher.DECRYPT_MODE, existingKey(), GCMParameterSpec(128, iv))
        return String(cipher.doFinal(ciphertext), StandardCharsets.UTF_8)
    }

    private fun keyStore(): KeyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    private fun existingKey(): SecretKey {
        val key = keyStore().getKey(KEY_ALIAS, null)
        return key as? SecretKey ?: throw IllegalStateException("Secure key is unavailable")
    }

    private fun getOrCreateKey(): SecretKey {
        try {
            return existingKey()
        } catch (_: Exception) {
            val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
            val specification = KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .build()
            generator.init(specification)
            return generator.generateKey()
        }
    }

    companion object {
        private const val PREFERENCES_NAME = "aiba_wearable_secure"
        private const val CLIENT_ID_KEY = "client_id"
        private const val LAST_DEVICE_ID_KEY = "last_device_id"
        private const val KEY_ALIAS = "aiba_wearable_pairing_key_v1"
        private const val RECORD_VERSION = "v1"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val DEFAULT_SERVICE_TYPE = "_aiba-wearable._tcp."
        private const val DEFAULT_PORT = 8765
    }
}
