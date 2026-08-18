package com.example.ai_blind_assistant

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class VisionAiWakePhraseTest {
    @Test
    fun keepsVoskTranscriptInTopLevelTextField() {
        assertEquals(0, VisionAiVoskContract.maxAlternatives)
    }

    @Test
    fun matchesExactWakePhraseWithoutCommand() {
        val match = VisionAiWakePhrase.match("Hey Vision AI")

        assertNotNull(match)
        assertEquals("", match?.command)
        assertEquals(true, match?.heardAiToken)

        val singleWordMatch = VisionAiWakePhrase.match("Vision")
        assertNotNull(singleWordMatch)
        assertEquals("", singleWordMatch?.command)

        val visionAiMatch = VisionAiWakePhrase.match("Vision AI")
        assertNotNull(visionAiMatch)
        assertEquals("", visionAiMatch?.command)
        assertEquals(true, visionAiMatch?.heardAiToken)
    }

    @Test
    fun extractsCommandFromCombinedRequest() {
        val match = VisionAiWakePhrase.match(
            "Hey Vision AI, turn mobile mode detection on",
        )
        assertEquals("turn mobile mode detection on", match?.command)

        val visionMatch = VisionAiWakePhrase.match(
            "Vision start mobile mode",
        )
        assertEquals("start mobile mode", visionMatch?.command)
    }

    @Test
    fun toleratesCommonOfflineRecognizerSpellings() {
        assertNotNull(VisionAiWakePhrase.match("hey vision a i"))
        assertNotNull(VisionAiWakePhrase.match("hey vision eye"))
        assertNotNull(VisionAiWakePhrase.match("hay version aye"))
        assertNotNull(VisionAiWakePhrase.match("hi visual i"))
        assertNotNull(VisionAiWakePhrase.match("hey vision"))
        assertEquals("", VisionAiWakePhrase.match("hey vision ai [unk]")?.command)
    }

    @Test
    fun rejectsGenericAssistantWordsAndUnbrandedSpeech() {
        assertNull(VisionAiWakePhrase.match("hey assistant"))
        assertNull(VisionAiWakePhrase.match("start mobile mode"))
        assertNull(VisionAiWakePhrase.match("hey there"))
    }
}
