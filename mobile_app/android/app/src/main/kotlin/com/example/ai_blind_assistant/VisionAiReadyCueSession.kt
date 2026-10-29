package com.example.ai_blind_assistant

/** A brief local cue; failure or old cleanup cannot stop a new listening turn. */
internal class VisionAiReadyCueSession(
    private val output: Output,
    private val schedule: (Long, () -> Unit) -> Unit,
) {
    interface Output {
        fun vibrate(durationMs: Long)
        fun chime(durationMs: Int)
        fun stop()
    }

    private var generation = 0

    fun play() {
        stop()
        val current = generation
        runCatching { output.vibrate(80L) }
        runCatching { output.chime(100) }
        schedule(180L) { if (generation == current) stop() }
    }

    fun stop() {
        generation++
        runCatching { output.stop() }
    }
}
