package com.example.ai_blind_assistant

import org.junit.Assert.*
import org.junit.Test

class SmartAiCueSessionTest {
    private class Output : SmartAiCueSession.Output {
        var vibrationFails = false
        var chimeFails = false
        var vibrations = 0
        var chimes = 0
        var stops = 0
        var active = false

        override fun vibrate(durationMs: Long): Boolean {
            assertEquals(220L, durationMs)
            vibrations++
            if (vibrationFails) error("Synthetic vibrator failure")
            active = true
            return true
        }

        override fun chime(durationMs: Int): Boolean {
            assertEquals(160, durationMs)
            chimes++
            if (chimeFails) error("Synthetic audio failure")
            active = true
            return true
        }

        override fun stop() {
            stops++
            active = false
        }
    }

    @Test fun lateOldCleanupCannotStopTheReplacementCue() {
        val output = Output()
        val cleanups = mutableListOf<() -> Unit>()
        val cue = SmartAiCueSession(output) { delay, action ->
            assertEquals(300L, delay)
            cleanups.add(action)
        }
        cue.play()
        cue.play()
        val stops = output.stops
        cleanups.first().invoke()
        assertTrue(output.active)
        assertEquals(stops, output.stops)
        cleanups.last().invoke()
        assertFalse(output.active)
        assertEquals(stops + 1, output.stops)
    }

    @Test fun vibratorFailureStillStartsTheChime() {
        val output = Output().apply { vibrationFails = true }
        val cue = SmartAiCueSession(output) { _, _ -> }
        assertEquals(SmartAiCueSession.Started(false, true), cue.play())
        assertEquals(1, output.chimes)
    }

    @Test fun audioFailureStillStartsTheVibration() {
        val output = Output().apply { chimeFails = true }
        val cue = SmartAiCueSession(output) { _, _ -> }
        assertEquals(SmartAiCueSession.Started(true, false), cue.play())
        assertEquals(1, output.vibrations)
    }

    @Test fun cancelledCueCannotBeAffectedByItsPendingCleanup() {
        val output = Output()
        var cleanup: (() -> Unit)? = null
        val cue = SmartAiCueSession(output) { _, action -> cleanup = action }
        cue.play()
        cue.stop()
        val stops = output.stops
        cleanup!!.invoke()
        assertFalse(output.active)
        assertEquals(stops, output.stops)
    }
}
