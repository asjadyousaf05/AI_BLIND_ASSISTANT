package com.example.ai_blind_assistant

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Smart AI-only readiness feedback; no recorder, speech or network ownership. */
internal class SmartAiRecordingCueHandler(context: Context) : MethodChannel.MethodCallHandler {
    private val handler = Handler(Looper.getMainLooper())
    private val output = AndroidOutput(context)
    private var foreground = false
    private val cue = SmartAiCueSession(output) { delay, action ->
        handler.postDelayed({ action() }, delay)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "play" -> {
                if (!foreground) {
                    result.error("not_foreground", "Listening feedback requires the open app.", null)
                    return
                }
                val started = cue.play()
                result.success(mapOf(
                    "vibrationStarted" to started.vibration,
                    "chimeStarted" to started.chime,
                ))
            }
            "stop" -> {
                stop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun stop() {
        handler.removeCallbacksAndMessages(null)
        cue.stop()
    }

    fun setForeground(active: Boolean) {
        foreground = active
        if (!active) stop()
    }

    private class AndroidOutput(context: Context) : SmartAiCueSession.Output {
        @Suppress("DEPRECATION")
        private val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= 31) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
        private val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        private var tone: ToneGenerator? = null
        private var vibrating = false

        @Suppress("DEPRECATION")
        override fun vibrate(durationMs: Long): Boolean {
            val device = vibrator ?: return false
            if (!device.hasVibrator()) return false
            vibrating = true
            if (Build.VERSION.SDK_INT >= 26) {
                val amplitude = if (device.hasAmplitudeControl()) 255 else VibrationEffect.DEFAULT_AMPLITUDE
                val effect = VibrationEffect.createOneShot(durationMs, amplitude)
                if (Build.VERSION.SDK_INT >= 33) {
                    device.vibrate(effect, VibrationAttributes.Builder()
                        .setUsage(VibrationAttributes.USAGE_ACCESSIBILITY).build())
                } else {
                    device.vibrate(effect, accessibilityAttributes())
                }
            } else {
                device.vibrate(durationMs, accessibilityAttributes())
            }
            return true
        }

        private fun accessibilityAttributes() = AudioAttributes.Builder()
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_ACCESSIBILITY)
            .build()

        override fun chime(durationMs: Int): Boolean {
            // Use media volume without changing volume, routing, focus or DND.
            if ((audio?.getStreamVolume(AudioManager.STREAM_MUSIC) ?: 0) == 0) return false
            val player = ToneGenerator(AudioManager.STREAM_MUSIC, 65)
            tone = player
            return player.startTone(ToneGenerator.TONE_PROP_PROMPT, durationMs)
        }

        override fun stop() {
            val player = tone
            tone = null
            try {
                player?.stopTone()
            } finally {
                try {
                    player?.release()
                } finally {
                    if (vibrating) {
                        vibrating = false
                        vibrator?.cancel()
                    }
                }
            }
        }
    }
}
