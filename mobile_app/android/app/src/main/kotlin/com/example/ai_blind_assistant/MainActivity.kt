package com.example.ai_blind_assistant

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "ai_blind_assistant/permissions"
    private val CAMERA_REQUEST_CODE = 1001
    private val MICROPHONE_CHANNEL = "ai_blind_assistant/assistant_microphone"
    private val AUDIO_RECORDER_CHANNEL = "ai_blind_assistant/assistant_audio_recorder"
    private val ON_DEVICE_SPEECH_CHANNEL = "ai_blind_assistant/on_device_speech_recognizer"
    private val MICROPHONE_REQUEST_CODE = 1002
    private var pendingCameraResult: MethodChannel.Result? = null
    private var pendingMicrophoneResult: MethodChannel.Result? = null
    private var inferenceHandler: InferenceHandler? = null
    private var wearablePlatformHandler: WearablePlatformHandler? = null
    private var assistantAudioRecorderHandler: AssistantAudioRecorderHandler? = null
    private var onDeviceSpeechRecognizerHandler: OnDeviceSpeechRecognizerHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Hands-free assistance is useful only while this foreground activity
        // stays available. Android automatically ignores this window flag once
        // the app is backgrounded, so it does not create a background service.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkCamera" -> {
                        val status = checkCameraPermission()
                        result.success(status)
                    }
                    "requestCamera" -> {
                        pendingCameraResult = result
                        requestCameraPermission()
                    }
                    "openSettings" -> {
                        openAppSettings()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MICROPHONE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkPermission" -> result.success(checkMicrophonePermission())
                    "requestPermission" -> {
                        if (pendingMicrophoneResult != null) {
                            result.error(
                                "permission_request_in_progress",
                                "A microphone permission request is already in progress.",
                                null,
                            )
                        } else {
                            pendingMicrophoneResult = result
                            requestMicrophonePermission()
                        }
                    }
                    "openAppSettings" -> {
                        openAppSettings()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        assistantAudioRecorderHandler = AssistantAudioRecorderHandler(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_RECORDER_CHANNEL)
            .setMethodCallHandler(assistantAudioRecorderHandler)

        val onDeviceSpeechChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ON_DEVICE_SPEECH_CHANNEL)
        onDeviceSpeechRecognizerHandler =
            OnDeviceSpeechRecognizerHandler(applicationContext, onDeviceSpeechChannel)
        onDeviceSpeechChannel.setMethodCallHandler(onDeviceSpeechRecognizerHandler)

        // Register inference method channel
        inferenceHandler = InferenceHandler(assets)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ai_blind_assistant/inference")
            .setMethodCallHandler(inferenceHandler)

        wearablePlatformHandler = WearablePlatformHandler(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ai_blind_assistant/wearable")
            .setMethodCallHandler(wearablePlatformHandler)

        // Optional Porcupine wake-word bridge. Safe no-op until Porcupine
        // native libraries are integrated. Uses the same on-device recognizer
        // channel so wake events flow into the existing hands-free pipeline.
        val porcupineChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ai_blind_assistant/porcupine")
        val porcupineHandler = PorcupineWakeHandler(applicationContext, porcupineChannel)

        // Keep a reference so it can be disposed in onDestroy.
        // Note: porcupineHandler is intentionally left reachable by a field
        // if later lifecycle management is required.
    }

    override fun onDestroy() {
        inferenceHandler?.close()
        inferenceHandler = null
        wearablePlatformHandler?.dispose()
        wearablePlatformHandler = null
        assistantAudioRecorderHandler?.dispose()
        assistantAudioRecorderHandler = null
        onDeviceSpeechRecognizerHandler?.dispose()
        onDeviceSpeechRecognizerHandler = null
        pendingCameraResult = null
        pendingMicrophoneResult = null
        super.onDestroy()
    }

    private fun checkCameraPermission(): String {
        return when {
            ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) ==
                PackageManager.PERMISSION_GRANTED -> "granted"
            !ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.CAMERA) &&
                getSharedPreferences("permissions", MODE_PRIVATE)
                    .getBoolean("camera_requested", false) -> "permanentlyDenied"
            else -> "denied"
        }
    }

    private fun requestCameraPermission() {
        getSharedPreferences("permissions", MODE_PRIVATE)
            .edit()
            .putBoolean("camera_requested", true)
            .apply()

        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.CAMERA),
            CAMERA_REQUEST_CODE
        )
    }

    private fun checkMicrophonePermission(): String {
        return when {
            ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED -> "granted"
            !ActivityCompat.shouldShowRequestPermissionRationale(
                this,
                Manifest.permission.RECORD_AUDIO,
            ) && getSharedPreferences("permissions", MODE_PRIVATE)
                .getBoolean("microphone_requested", false) -> "permanentlyDenied"
            else -> "denied"
        }
    }

    private fun requestMicrophonePermission() {
        getSharedPreferences("permissions", MODE_PRIVATE)
            .edit()
            .putBoolean("microphone_requested", true)
            .apply()

        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            MICROPHONE_REQUEST_CODE,
        )
    }

    private fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", packageName, null)
        }
        startActivity(intent)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == CAMERA_REQUEST_CODE) {
            val status = if (grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                "granted"
            } else if (!ActivityCompat.shouldShowRequestPermissionRationale(
                    this, Manifest.permission.CAMERA)) {
                "permanentlyDenied"
            } else {
                "denied"
            }
            pendingCameraResult?.success(status)
            pendingCameraResult = null
        } else if (requestCode == MICROPHONE_REQUEST_CODE) {
            val status = if (grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                "granted"
            } else if (!ActivityCompat.shouldShowRequestPermissionRationale(
                    this,
                    Manifest.permission.RECORD_AUDIO,
                )) {
                "permanentlyDenied"
            } else {
                "denied"
            }
            pendingMicrophoneResult?.success(status)
            pendingMicrophoneResult = null
        }
    }
}
