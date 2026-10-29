package com.example.ai_blind_assistant

/** One bounded cue. Late cleanup from an old cue cannot stop its replacement. */
internal class SmartAiCueSession(
    private val output: Output,
    private val scheduleCleanup: (Long, () -> Unit) -> Unit,
) {
    interface Output {
        fun vibrate(durationMs: Long): Boolean
        fun chime(durationMs: Int): Boolean
        fun stop()
    }

    data class Started(val vibration: Boolean, val chime: Boolean)

    private var generation = 0

    fun play(): Started {
        stop()
        val current = generation
        // Failure in one output must never prevent the other from starting.
        val vibration = runCatching { output.vibrate(220L) }.getOrDefault(false)
        val chime = runCatching { output.chime(160) }.getOrDefault(false)
        scheduleCleanup(300L) {
            if (current == generation) stop()
        }
        return Started(vibration, chime)
    }

    fun stop() {
        generation++
        runCatching { output.stop() }
    }
}
