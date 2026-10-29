package com.example.ai_blind_assistant

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/** Foreground Vision AI cue. It changes no volume, audio focus or user setting. */
internal class VisionAiListeningCue(context: Context) : VisionAiReadyCueSession.Output {
    private val handler = Handler(Looper.getMainLooper())
    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
    @Suppress("DEPRECATION")
    private val vibrator = if (Build.VERSION.SDK_INT >= 31) {
        (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
    } else context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
    private var tone: ToneGenerator? = null
    private var vibrating = false
    private val session = VisionAiReadyCueSession(this) { delay, action ->
        handler.postDelayed({ action() }, delay)
    }

    fun play() = session.play()

    fun cancel() {
        handler.removeCallbacksAndMessages(null)
        session.stop()
    }

    @Suppress("DEPRECATION")
    override fun vibrate(durationMs: Long) {
        val device = vibrator ?: return
        if (!device.hasVibrator()) return
        vibrating = true
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_ACCESSIBILITY)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
        if (Build.VERSION.SDK_INT >= 26) {
            device.vibrate(VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE), attributes)
        } else device.vibrate(durationMs, attributes)
    }

    override fun chime(durationMs: Int) {
        if ((audio?.getStreamVolume(AudioManager.STREAM_MUSIC) ?: 0) == 0) return
        val player = ToneGenerator(AudioManager.STREAM_MUSIC, 45)
        tone = player
        player.startTone(ToneGenerator.TONE_PROP_BEEP, durationMs)
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
