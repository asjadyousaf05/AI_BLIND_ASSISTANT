package com.example.ai_blind_assistant

import java.util.Locale

/** Stable partial proposals only; the Dart reader/echo policy owns acceptance. */
internal class ReaderBargeInGate {
    data class Candidate(val id: String, val transcript: String)

    private var epoch = 0L
    private var sequence = 0L
    private var text = ""
    private var since = 0L
    private var proposed: Candidate? = null
    private var proposedAt = 0L

    fun observe(partial: String, now: Long): Candidate? {
        val normalized = partial.lowercase(Locale.US)
            .replace("[unk]", " ").trim().replace(Regex("\\s+"), " ")
        if (normalized != text) {
            text = normalized
            since = now
            proposed = null
            return null
        }
        if (normalized.split(' ').size < 2 || now - since < 250 || proposed != null) {
            return null
        }
        return Candidate("$epoch:${++sequence}", normalized).also {
            proposed = it
            proposedAt = now
        }
    }

    fun consume(id: String, now: Long): String? {
        val candidate = proposed ?: return null
        if (candidate.id != id || now - proposedAt > 1500) return null
        val accepted = candidate.transcript
        reset()
        return accepted
    }

    fun reset() {
        epoch++
        text = ""
        proposed = null
        since = 0L
    }
}
