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

    fun match(rawTranscript: String): VisionAiWakeMatch? {
        val normalized = rawTranscript
            .trim()
            .lowercase(Locale.US)
            .replace(whitespace, " ")
        val tokens = word.findAll(normalized).toList()
        if (tokens.isEmpty()) return null

        for (index in tokens.indices) {
            val token = tokens[index].value

            // Case A: Standalone "Vision" or "Vision AI" at position index
            if (isVision(token)) {
                var lastWakeToken = index
                var heardAiToken = false
                val possibleAi = tokens.getOrNull(index + 1)?.value
                if (possibleAi in aiSpellings) {
                    heardAiToken = true
                    lastWakeToken = index + 1
                    if (possibleAi == "a" && tokens.getOrNull(index + 2)?.value == "i") {
                        lastWakeToken = index + 2
                    }
                }

                val command = normalized
                    .substring(tokens[lastWakeToken].range.last + 1)
                    .trim()
                    .trim { !it.isLetterOrDigit() }
                    .takeUnless { it == "unk" }
                    .orEmpty()
                return VisionAiWakeMatch(
                    command = command,
                    heardAiToken = heardAiToken,
                )
            }

            // Case B: "Hey Vision" / "Hi Vision" / "Hello Vision" at position index
            if (isWakeLead(token) && index < tokens.lastIndex && isVision(tokens[index + 1].value)) {
                var lastWakeToken = index + 1
                val possibleAi = tokens.getOrNull(index + 2)?.value
                var heardAiToken = false
                if (possibleAi in aiSpellings) {
                    heardAiToken = true
                    lastWakeToken = index + 2
                    if (possibleAi == "a" && tokens.getOrNull(index + 3)?.value == "i") {
                        lastWakeToken = index + 3
                    }
                }

                val command = normalized
                    .substring(tokens[lastWakeToken].range.last + 1)
                    .trim()
                    .trim { !it.isLetterOrDigit() }
                    .takeUnless { it == "unk" }
                    .orEmpty()
                return VisionAiWakeMatch(
                    command = command,
                    heardAiToken = heardAiToken,
                )
            }
        }
        return null
    }

    private fun isWakeLead(value: String): Boolean =
        value == "hi" ||
            value == "hello" ||
            value == "ok" ||
            value == "okay" ||
            value == "yo" ||
            (value.length in 2..4 && editDistance(value, "hey") <= 1)

    private fun isVision(value: String): Boolean =
        value == "visual" ||
            (value.length in 4..8 && editDistance(value, "vision") <= 2)

    private fun editDistance(left: String, right: String): Int {
        var previous = IntArray(right.length + 1) { it }
        for (leftIndex in left.indices) {
            val current = IntArray(right.length + 1)
            current[0] = leftIndex + 1
            for (rightIndex in right.indices) {
                val substitution = previous[rightIndex] +
                    if (left[leftIndex] == right[rightIndex]) 0 else 1
                current[rightIndex + 1] = minOf(
                    current[rightIndex] + 1,
                    previous[rightIndex + 1] + 1,
                    substitution,
                )
            }
            previous = current
        }
        return previous[right.length]
    }
}
