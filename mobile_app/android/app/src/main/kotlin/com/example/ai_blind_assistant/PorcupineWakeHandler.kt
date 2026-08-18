package com.example.ai_blind_assistant

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Lightweight optional bridge for Porcupine wake-word detector.
 *
 * This file is intentionally a stub that exposes a MethodChannel and the
 * expected lifecycle methods. To enable Porcupine, add the Picovoice
 * Android runtime dependency and implement the native listener where
 * indicated below. When Porcupine detects the configured keyword it
 * should call `channel.invokeMethod("onHandsFreeWake", null)` to reuse
 * the existing hands-free handling pipeline.
 *
 * The stub is safe when Porcupine is not present: start/stop methods
 * return `false` and the channel remains available for test wiring.
 */
class PorcupineWakeHandler(
    private val context: Context,
    private val channel: MethodChannel,
) : MethodChannel.MethodCallHandler {

    private val TAG = "PorcupineWakeHandler"
    private var running = false

    init {
        // Register this handler for method calls on the provided channel.
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startPorcupine" -> {
                val started = startPorcupine()
                result.success(started)
            }
            "stopPorcupine" -> {
                val stopped = stopPorcupine()
                result.success(stopped)
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        stopPorcupine()
        channel.setMethodCallHandler(null)
    }

    private fun startPorcupine(): Boolean {
        if (running) return true
        // TODO: Integrate Picovoice Porcupine here. Example steps:
        // 1. Add Porcupine native libs and dependency to build.gradle
        // 2. Load keyword file for "hi vision ai" and configure sensitivity
        // 3. Start a lightweight audio thread and register a callback that
        //    calls channel.invokeMethod("onHandsFreeWake", null) when
        //    keyword is detected.
        // Until Porcupine is integrated, return false to indicate not started.
        Log.w(TAG, "Porcupine start requested but Porcupine is not integrated.")
        running = false
        return false
    }

    private fun stopPorcupine(): Boolean {
        if (!running) return false
        // Stop and release Porcupine resources here.
        running = false
        return true
    }

    /** Helper to emit a wake event into the existing hands-free channel. */
    private fun emitWakeEvent() {
        try {
            channel.invokeMethod("onHandsFreeWake", null)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to invoke hands-free wake method: $e")
        }
    }
}
