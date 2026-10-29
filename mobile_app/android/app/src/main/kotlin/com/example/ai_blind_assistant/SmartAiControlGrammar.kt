package com.example.ai_blind_assistant

import java.util.Locale

/** Foreground Smart AI exit phrases; the base Vision AI grammars stay unchanged. */
internal object SmartAiControlGrammar {
    private val whitespace = Regex("\\s+")
    private val phrases = setOf(
        "goodbye smart ai", "good bye smart ai", "bye smart ai",
        "goodbye smart a i", "good bye smart a i",
    )

    fun isGoodbye(text: String): Boolean =
        text.trim().lowercase(Locale.US).replace(whitespace, " ") in phrases

    fun extend(base: String, active: Boolean): String {
        if (!active) return base
        val grammar = base.trim()
        val prefix = if (grammar == "[]") "[" else grammar.dropLast(1) + ","
        return phrases.joinToString(prefix = prefix, postfix = "]") { "\"$it\"" }
    }
}
