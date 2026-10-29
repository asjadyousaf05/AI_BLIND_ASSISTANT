package com.example.ai_blind_assistant

import org.junit.Assert.assertEquals
import org.junit.Test

class VisionAiReadyCueSessionTest {
    private class Output : VisionAiReadyCueSession.Output {
        val vibrations = mutableListOf<Long>()
        val chimes = mutableListOf<Int>()
        var stops = 0
        var failVibration = false
        override fun vibrate(durationMs: Long) {
            if (failVibration) throw IllegalStateException("unavailable")
            vibrations += durationMs
        }
        override fun chime(durationMs: Int) { chimes += durationMs }
        override fun stop() { stops++ }
    }

    @Test fun readyCueIsBoundedAndReleasesItsResources() {
        val output = Output()
        val tasks = mutableListOf<() -> Unit>()
        val session = VisionAiReadyCueSession(output) { delay, task ->
            assertEquals(180L, delay)
            tasks += task
        }
        session.play()
        assertEquals(listOf(80L), output.vibrations)
        assertEquals(listOf(100), output.chimes)
        tasks.single()()
        assertEquals(2, output.stops)
    }

    @Test fun oldCleanupCannotStopAReplacementCue() {
        val output = Output()
        val tasks = mutableListOf<() -> Unit>()
        val session = VisionAiReadyCueSession(output) { _, task -> tasks += task }
        session.play()
        session.play()
        tasks[0]()
        assertEquals(2, output.stops)
        tasks[1]()
        assertEquals(3, output.stops)
    }

    @Test fun cancellingInvalidatesCleanupAndOneFailedOutputDoesNotBlockTheOther() {
        val output = Output().apply { failVibration = true }
        val tasks = mutableListOf<() -> Unit>()
        val session = VisionAiReadyCueSession(output) { _, task -> tasks += task }
        session.play()
        assertEquals(listOf(100), output.chimes)
        session.stop()
        tasks.single()()
        assertEquals(2, output.stops)
    }
}
