package com.example.ai_blind_assistant

import org.junit.Assert.*
import org.junit.Test

class SmartAiControlGrammarTest {
    @Test fun disabledModePreservesTheOriginalGrammar() {
        assertEquals("[\"hey vision ai\",\"[unk]\"]", SmartAiControlGrammar.extend("[\"hey vision ai\",\"[unk]\"]", false))
    }
    @Test fun enabledModeRetainsWakeUnknownAndAddsSmartAiExit() {
        val grammar = SmartAiControlGrammar.extend("[\"hey vision ai\",\"[unk]\"]", true)
        assertTrue(grammar.contains("\"hey vision ai\""))
        assertTrue(grammar.contains("\"[unk]\""))
        assertTrue(grammar.contains("\"goodbye smart ai\""))
        assertTrue(grammar.endsWith("]"))
    }
    @Test fun goodbyeRequiresTheWholeBrandedFinalPhrase() {
        assertTrue(SmartAiControlGrammar.isGoodbye("Goodbye  Smart AI"))
        assertTrue(SmartAiControlGrammar.isGoodbye("good bye smart a i"))
        assertFalse(SmartAiControlGrammar.isGoodbye("how do I say goodbye smart ai"))
        assertFalse(SmartAiControlGrammar.isGoodbye("goodbye vision ai"))
        assertFalse(SmartAiControlGrammar.isGoodbye("goodbye [unk] smart ai"))
    }
    @Test fun anEmptyBaseNeverCreatesAnInvalidLeadingComma() {
        val grammar = SmartAiControlGrammar.extend("[]", true)
        assertTrue(grammar.startsWith("[\"goodbye smart ai\""))
        assertFalse(grammar.contains("[,"))
        assertTrue(grammar.endsWith("]"))
    }

}
