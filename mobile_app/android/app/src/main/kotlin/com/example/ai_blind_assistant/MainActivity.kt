package com.example.ai_blind_assistant

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "ai_blind_assistant/permissions"
    private val CAMERA_REQUEST_CODE = 1001
    private var pendingResult: MethodChannel.Result? = null
    private var inferenceHandler: InferenceHandler? = null
    private var wearablePlatformHandler: WearablePlatformHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkCamera" -> {
                        val status = checkCameraPermission()
                        result.success(status)
                    }
                    "requestCamera" -> {
                        pendingResult = result
                        requestCameraPermission()
                    }
                    "openSettings" -> {
                        openAppSettings()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // Register inference method channel
        inferenceHandler = InferenceHandler(assets)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ai_blind_assistant/inference")
            .setMethodCallHandler(inferenceHandler)

        wearablePlatformHandler = WearablePlatformHandler(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ai_blind_assistant/wearable")
            .setMethodCallHandler(wearablePlatformHandler)
    }

    override fun onDestroy() {
        inferenceHandler?.close()
        inferenceHandler = null
        wearablePlatformHandler?.dispose()
        wearablePlatformHandler = null
        pendingResult = null
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
            pendingResult?.success(status)
            pendingResult = null
        }
    }
}
