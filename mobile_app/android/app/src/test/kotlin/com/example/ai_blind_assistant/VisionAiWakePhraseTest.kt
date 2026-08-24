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

        assertNotNull(VisionAiWakePhrase.match("Hi Vision AI"))
        assertNotNull(VisionAiWakePhrase.match("Hello Vision AI"))
    }

    @Test
    fun extractsCommandFromCombinedRequest() {
        val match = VisionAiWakePhrase.match(
            "Hey Vision AI, turn mobile mode detection on",
        )
        assertEquals("turn mobile mode detection on", match?.command)

        val hiVisionMatch = VisionAiWakePhrase.match(
            "Hi Vision AI start mobile mode",
        )
        assertEquals("start mobile mode", hiVisionMatch?.command)
    }

    @Test
    fun toleratesCommonOfflineRecognizerSpellings() {
        assertNotNull(VisionAiWakePhrase.match("hey vision a i"))
        assertNotNull(VisionAiWakePhrase.match("hey vision eye"))
        assertNotNull(VisionAiWakePhrase.match("hay version aye"))
        assertNotNull(VisionAiWakePhrase.match("hi visual i"))
        assertEquals("", VisionAiWakePhrase.match("hey vision ai [unk]")?.command)
    }

    @Test
    fun rejectsGenericAssistantWordsAndUnbrandedSpeech() {
        assertNull(VisionAiWakePhrase.match("hey assistant"))
        assertNull(VisionAiWakePhrase.match("start mobile mode"))
        assertNull(VisionAiWakePhrase.match("hey there"))
        assertNull(VisionAiWakePhrase.match("vision"))
        assertNull(VisionAiWakePhrase.match("vision ai"))
        assertNull(VisionAiWakePhrase.match("hey vision"))
        assertNull(VisionAiWakePhrase.match("television ai"))
        assertNull(VisionAiWakePhrase.match("noise hey vision ai"))
    }

    @Test
    fun wakeGrammarContainsNoExecutableAppCommands() {
        assertEquals(true, "hey vision ai" in VisionAiSpeechGrammar.wakePhrases)
        assertEquals(true, "hi vision ai" in VisionAiSpeechGrammar.wakePhrases)
        assertEquals(true, "[unk]" in VisionAiSpeechGrammar.wakePhrases)
        assertEquals(false, "start mobile mode" in VisionAiSpeechGrammar.wakePhrases)
        assertEquals(false, "stop" in VisionAiSpeechGrammar.wakePhrases)
        assertEquals(false, "vision" in VisionAiSpeechGrammar.wakePhrases)
    }

    @Test
    fun commandGrammarCoversSemanticAliasesAndSmartAiSwitching() {
        val commands = VisionAiSpeechGrammar.appCommandPhrases

        assertEquals(true, "start mobile mode" in commands)
        assertEquals(true, "run mobile mode" in commands)
        assertEquals(true, "begin mobile detection" in commands)
        assertEquals(true, "change feedback mode to audio" in commands)
        assertEquals(true, "open smart ai" in commands)
        assertEquals(true, "start smart ai" in commands)
        assertEquals(true, "set speech rate to fast" in commands)
        assertEquals(true, "set announcement cooldown to 5 seconds" in commands)
        assertEquals(true, "bye" in commands)
        assertEquals(true, "[unk]" in commands)
    }

    @Test
    fun scannerGrammarCoversNaturalCapturePlaybackSpeedAndExitPhrases() {
        val commands = VisionAiSpeechGrammar.scannerCommandPhrases

        assertEquals(true, "scan this page" in commands)
        assertEquals(true, "could you take a picture" in commands)
        assertEquals(true, "pause the reading" in commands)
        assertEquals(true, "please continue reading" in commands)
        assertEquals(true, "stop" in commands)
        assertEquals(true, "say the sentence again" in commands)
        assertEquals(true, "go back one sentence" in commands)
        assertEquals(true, "make the reading slower" in commands)
        assertEquals(true, "please can you make it faster" in commands)
        assertEquals(true, "start reading" in commands)
        assertEquals(true, "first line" in commands)
        assertEquals(true, "go to last line" in commands)
        assertEquals(true, "go to line seven" in commands)
        assertEquals(true, "please read line forty two" in commands)
        assertEquals(true, "line one hundred" in commands)
        assertEquals(true, "spell current line" in commands)
        assertEquals(true, "copy to clipboard" in commands)
        assertEquals(true, "turn flashlight on" in commands)
        assertEquals(true, "good bye" in commands)
        assertEquals(true, "[unk]" in commands)
    }
}
