package com.example.ai_blind_assistant

import java.util.Locale

internal data class VisionAiWakeMatch(
    val command: String,
    val heardAiToken: Boolean,
)

/** Brand-specific wake matching with bounded offline-ASR/accent tolerance. */
internal object VisionAiWakePhrase {
    private val whitespace = Regex("\\s+")
    private val word = Regex("[a-z0-9]+")
    private val aiSpellings = setOf("ai", "aye", "eye", "i", "a", "eh")
    private val wakeLeads = setOf("hey", "hi", "hello", "hay")
    private val visionSpellings = setOf("vision", "visual", "version")

    fun match(rawTranscript: String): VisionAiWakeMatch? {
        val normalized = rawTranscript
            .trim()
            .lowercase(Locale.US)
            .replace(whitespace, " ")
        val tokens = word.findAll(normalized).toList()
        if (tokens.size < 3) return null
        if (tokens[0].value !in wakeLeads) return null
        if (tokens[1].value !in visionSpellings) return null

        var lastWakeToken = 2
        val aiToken = tokens[2].value
        if (aiToken !in aiSpellings) return null
        if (aiToken == "a") {
            if (tokens.getOrNull(3)?.value != "i") return null
            lastWakeToken = 3
        }

        val command = normalized
            .substring(tokens[lastWakeToken].range.last + 1)
            .trim()
            .trim { !it.isLetterOrDigit() }
            .takeUnless { it == "unk" }
            .orEmpty()
        return VisionAiWakeMatch(
            command = command,
            heardAiToken = true,
        )
    }
}
