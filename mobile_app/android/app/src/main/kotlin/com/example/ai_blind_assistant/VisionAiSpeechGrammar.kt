package com.example.ai_blind_assistant

import org.json.JSONArray

/** Decoder graphs used by the foreground-only Vision AI speech pipeline. */
internal enum class VisionAiDecoderProfile {
    WAKE,
    APP_COMMANDS,
    SCANNER_COMMANDS,
    CONVERSATION,
}

/**
 * Small, explicit Vosk grammars for wake and deterministic app-control speech.
 *
 * Smart AI conversation deliberately uses Vosk's bundled default graph so a
 * user's question is not limited to the app-command vocabulary. The wake graph
 * never contains app commands: ambient speech cannot execute an action before
 * a complete branded wake phrase has opened the foreground command session.
 */
internal object VisionAiSpeechGrammar {
    val wakePhrases: List<String> = listOf(
        "hey vision ai",
        "hi vision ai",
        "hello vision ai",
        "hey vision a i",
        "hi vision a i",
        "hey vision eye",
        "hi vision eye",
        "hey vision aye",
        "hi vision aye",
        "hay vision ai",
        "hey version ai",
        "hi visual ai",
        "[unk]",
    )

    val appCommandPhrases: List<String> = buildAppCommandPhrases()

    val scannerCommandPhrases: List<String> = buildScannerCommandPhrases()

    fun jsonFor(profile: VisionAiDecoderProfile): String = when (profile) {
        VisionAiDecoderProfile.WAKE -> JSONArray(wakePhrases).toString()
        VisionAiDecoderProfile.APP_COMMANDS -> JSONArray(appCommandPhrases).toString()
        VisionAiDecoderProfile.SCANNER_COMMANDS ->
            JSONArray(scannerCommandPhrases).toString()
        // Vosk documents [] as restoring the model's default language graph.
        VisionAiDecoderProfile.CONVERSATION -> "[]"
    }

    private fun buildScannerCommandPhrases(): List<String> {
        val core = linkedSetOf(
            // Capture and rescan.
            "scan",
            "scan document",
            "scan the document",
            "scan this document",
            "scan page",
            "scan this page",
            "scan now",
            "scan it",
            "start scan",
            "start scanning",
            "begin scanning",
            "read document",
            "read the document",
            "read this document",
            "read page",
            "read this page",
            "read text",
            "read the text",
            "read this",
            "take picture",
            "take a picture",
            "take photo",
            "take a photo",
            "capture",
            "capture page",
            "capture this page",
            "capture document",
            "capture photo",
            "capture now",
            "rescan",
            "scan again",
            "scan another",
            "scan another document",
            "scan another page",
            "scan next page",
            "capture another page",
            "capture another",
            "read another page",
            "new scan",
            "try again",
            "read again",
            "read text again",
            "read document again",
            "read it again",

            // Pause, resume, and stop.
            "pause",
            "pause reading",
            "pause the reading",
            "pause it",
            "pause audio",
            "pause speech",
            "hold",
            "hold on",
            "wait a moment",
            "stop for a moment",
            "resume",
            "resume reading",
            "resume audio",
            "resume speech",
            "start reading",
            "start the reading",
            "begin reading",
            "begin the reading",
            "read aloud",
            "play document",
            "continue",
            "continue reading",
            "continue from here",
            "keep reading",
            "keep going",
            "carry on",
            "start reading again",
            "play",
            "unpause",
            "stop",
            "stop it",
            "stop reading",
            "stop speaking",
            "stop talking",
            "stop voice",
            "stop audio",
            "be quiet",
            "quiet",
            "silence",
            "mute",
            "hush",

            // Sentence navigation and repetition.
            "next",
            "next line",
            "next sentence",
            "go next",
            "move next",
            "move forward",
            "go forward",
            "read next",
            "read the next sentence",
            "move to next sentence",
            "skip this sentence",
            "continue to next",
            "skip line",
            "skip sentence",
            "skip ahead",
            "forward",
            "skip",
            "previous",
            "previous line",
            "previous sentence",
            "go previous",
            "go back one sentence",
            "read previous",
            "read the previous sentence",
            "last sentence",
            "last line",
            "what was before this",
            "rewind",
            "repeat",
            "repeat that",
            "repeat this",
            "repeat line",
            "repeat sentence",
            "repeat this sentence",
            "repeat current sentence",
            "say line again",
            "read line again",
            "say that again",
            "read that again",
            "read that sentence again",
            "say again",
            "again",
            "one more time",
            "repeat text",
            "what did you just say",
            "say the sentence again",

            // Restart and spelling.
            "restart",
            "restart reading",
            "start again",
            "start over",
            "start from beginning",
            "start from the beginning",
            "read from beginning",
            "read from the beginning",
            "go to beginning",
            "begin again",
            "restart document",
            "from the beginning",
            "from the top",
            "first line",
            "first sentence",
            "go to first line",
            "go to the first line",
            "read first line",
            "read the first line",
            "beginning of document",
            "top of document",
            "last line",
            "last sentence",
            "final line",
            "final sentence",
            "go to last line",
            "go to the last line",
            "read last line",
            "read the last line",
            "end of document",
            "bottom of document",
            "spell",
            "spell it",
            "spell that",
            "spell out",
            "spell this",
            "spell word",
            "spell this word",
            "spell current word",
            "spell the word",
            "spell sentence",
            "spell this sentence",
            "spell current sentence",
            "spell current line",
            "spell this line",
            "spell the current line",
            "spell the sentence",
            "spell it out",
            "spelling",
            "read letter by letter",
            "letter by letter",

            // Reading speed profiles.
            "study mode",
            "learning mode",
            "slow down",
            "speak slower",
            "read slowly",
            "slow mode",
            "make it slower",
            "make reading slower",
            "make the reading slower",
            "fast mode",
            "skim mode",
            "speed up",
            "speak faster",
            "read faster",
            "make it faster",
            "make reading faster",
            "make the reading faster",
            "normal speed",
            "normal mode",
            "standard mode",
            "standard speed",
            "read normally",
            "reset reading speed",

            // Scanner utilities and navigation.
            "copy",
            "copy text",
            "copy the text",
            "copy document",
            "copy this document",
            "copy all text",
            "copy everything",
            "copy to clipboard",
            "copy result",
            "switch camera",
            "flip camera",
            "change camera",
            "toggle camera",
            "turn flashlight on",
            "turn flashlight off",
            "flashlight on",
            "flashlight off",
            "turn torch on",
            "turn torch off",
            "torch on",
            "torch off",
            "go back",
            "navigate back",
            "close scanner",
            "exit scanner",
            "open smart ai",
            "start smart ai",
            "ask ai about this",
            "ask ai about this document",
            "yes",
            "confirm",
            "proceed",
            "no",
            "cancel",
            "bye",
            "by",
            "goodbye",
            "good bye",
            "stop listening",
            "go to sleep",
            "that's all",
            "that is all",
            "emergency stop",
            "stop everything",
        )

        // Keep numeric navigation inside the focused graph rather than opening
        // full-vocabulary recognition. One hundred reading units covers long
        // OCR pages while retaining constrained noise behavior.
        val numberedLinePhrases = linkedSetOf<String>()
        for (lineNumber in 1..100) {
            val spokenNumber = numberToWords(lineNumber)
            numberedLinePhrases += "line $spokenNumber"
            numberedLinePhrases += "line number $spokenNumber"
            numberedLinePhrases += "go to line $spokenNumber"
            numberedLinePhrases += "read line $spokenNumber"
            numberedLinePhrases += "sentence $spokenNumber"
        }

        val phrases = linkedSetOf<String>()
        val politePrefixes = listOf(
            "please",
            "can you",
            "could you",
            "would you",
            "please can you",
        )
        for (phrase in core) {
            phrases += phrase
            for (prefix in politePrefixes) {
                phrases += "$prefix $phrase"
            }
        }
        for (phrase in numberedLinePhrases) {
            phrases += phrase
            phrases += "please $phrase"
            phrases += "can you $phrase"
        }
        phrases += "[unk]"
        return phrases.toList()
    }

    private fun numberToWords(value: Int): String {
        require(value in 1..100)
        if (value == 100) return "one hundred"
        val belowTwenty = listOf(
            "zero",
            "one",
            "two",
            "three",
            "four",
            "five",
            "six",
            "seven",
            "eight",
            "nine",
            "ten",
            "eleven",
            "twelve",
            "thirteen",
            "fourteen",
            "fifteen",
            "sixteen",
            "seventeen",
            "eighteen",
            "nineteen",
        )
        if (value < 20) return belowTwenty[value]
        val tens = listOf(
            "",
            "",
            "twenty",
            "thirty",
            "forty",
            "fifty",
            "sixty",
            "seventy",
            "eighty",
            "ninety",
        )
        val remainder = value % 10
        return if (remainder == 0) {
            tens[value / 10]
        } else {
            "${tens[value / 10]} ${belowTwenty[remainder]}"
        }
    }

    private fun buildAppCommandPhrases(): List<String> {
        val phrases = linkedSetOf<String>()

        fun combine(verbs: List<String>, entities: List<String>) {
            for (verb in verbs) {
                for (entity in entities) {
                    phrases += "$verb $entity"
                }
            }
        }

        combine(
            listOf("start", "run", "begin", "launch", "activate", "enable", "turn on"),
            listOf(
                "mobile mode",
                "mobile detection",
                "object detection",
                "obstacle detection",
                "detection",
                "mobile assistance",
            ),
        )
        combine(
            listOf("stop", "end", "close", "deactivate", "disable", "turn off"),
            listOf(
                "mobile mode",
                "mobile detection",
                "object detection",
                "obstacle detection",
                "detection",
                "mobile assistance",
            ),
        )
        combine(
            listOf("pause", "resume", "continue"),
            listOf("mobile mode", "mobile detection", "detection", "mobile assistance"),
        )

        phrases += listOf(
            "help me see",
            "look around",
            "detect objects",
            "what do you see",
            "what is in front of me",
            "what is nearby",
            "read recent detections",
            "detection status",
            "mobile mode status",
            "is detection running",
            "camera status",
        )

        phrases += listOf(
            "open smart ai",
            "start smart ai",
            "launch smart ai",
            "go to smart ai",
            "switch to smart ai",
            "talk to smart ai",
            "open online assistant",
            "start online assistant",
            "switch to online mode",
            "ask ai",
            "talk to ai",
        )

        phrases += listOf(
            "change feedback mode to audio",
            "set feedback mode to audio",
            "use audio feedback",
            "audio feedback only",
            "change feedback mode to vibration",
            "set feedback mode to vibration",
            "use vibration feedback",
            "vibration feedback only",
            "change feedback mode to both",
            "set feedback mode to both",
            "use audio and vibration feedback",
            "both audio and vibration",
            "turn vibration on",
            "turn vibration off",
            "enable vibration",
            "disable vibration",
            "turn high contrast on",
            "turn high contrast off",
            "enable high contrast",
            "disable high contrast",
            "turn large text on",
            "turn large text off",
            "enable large text",
            "disable large text",
            "turn reduced motion on",
            "turn reduced motion off",
            "enable reduced motion",
            "disable reduced motion",
            "turn hands free on",
            "turn hands free off",
            "enable hands free",
            "disable hands free",
            "enable hands-free",
            "disable hands-free",
        )

        combine(
            listOf("set", "change", "adjust", "make"),
            listOf(
                "sensitivity low",
                "sensitivity medium",
                "sensitivity high",
                "detection sensitivity low",
                "detection sensitivity medium",
                "detection sensitivity high",
            ),
        )
        phrases += listOf(
            "reduce sensitivity",
            "decrease sensitivity",
            "lower sensitivity",
            "increase sensitivity",
            "raise sensitivity",
            "normal sensitivity",
            "high sensitivity",
            "medium sensitivity",
            "low sensitivity",
            "read settings",
            "current settings",
            "settings status",
            "set sensitivity to low",
            "set sensitivity to medium",
            "set sensitivity to high",
            "set detection sensitivity to low",
            "set detection sensitivity to medium",
            "set detection sensitivity to high",
            "set speech rate to slow",
            "set speech rate to normal",
            "set speech rate to fast",
            "change speech rate to slow",
            "change speech rate to normal",
            "change speech rate to fast",
            "set voice speed to slow",
            "set voice speed to normal",
            "set voice speed to fast",
        )

        for (seconds in listOf(1, 2, 3, 5, 10, 15, 20, 30)) {
            phrases += "set announcement cooldown to $seconds seconds"
            phrases += "set announcement interval to $seconds seconds"
            phrases += "set alert interval to $seconds seconds"
        }

        phrases += listOf(
            "open settings",
            "go to settings",
            "show settings",
            "go home",
            "open home",
            "open scanner",
            "open document scanner",
            "open mobile mode",
            "go to mobile mode",
            "open raspberry pi",
            "open modes",
            "open help",
            "open safety",
            "go back",
            "navigate back",
            "previous screen",
        )

        phrases += listOf(
            "scan document",
            "scan this document",
            "scan page",
            "scan another page",
            "take picture",
            "take photo",
            "capture page",
            "read document",
            "read text",
            "pause reading",
            "resume reading",
            "continue reading",
            "repeat",
            "repeat sentence",
            "say that again",
            "next sentence",
            "previous sentence",
            "restart reading",
            "start from the beginning",
            "spell word",
            "spell sentence",
            "study mode",
            "normal speed",
            "fast mode",
            "copy text",
            "switch camera",
            "flip camera",
        )

        phrases += listOf(
            "raspberry pi status",
            "pi status",
            "wearable status",
            "find raspberry pi",
            "discover pi",
            "scan for raspberry pi",
            "connect to raspberry pi",
            "connect pi",
            "disconnect raspberry pi",
            "disconnect pi",
            "start wearable mode",
            "stop wearable mode",
            "pause wearable mode",
            "resume wearable mode",
        )

        phrases += listOf(
            "turn flashlight on",
            "turn flashlight off",
            "flashlight on",
            "flashlight off",
            "turn torch on",
            "turn torch off",
            "torch on",
            "torch off",
            "indoor mode",
            "outdoor mode",
            "auto environment",
            "what time is it",
            "tell me the time",
            "current time",
            "what is the date",
            "what day is it",
            "current date",
            "battery level",
            "battery status",
            "battery percentage",
            "check battery",
            "assistant status",
            "connection status",
        )

        phrases += listOf(
            "stop everything",
            "emergency stop",
            "stop speaking",
            "stop talking",
            "quiet",
            "silence",
            "mute",
            "what can you do",
            "who are you",
            "hello",
            "thank you",
            "yes",
            "confirm",
            "proceed",
            "do it",
            "no",
            "cancel",
            "never mind",
            "bye",
            "by",
            "goodbye",
            "good bye",
            "exit assistant",
            "dismiss assistant",
            "go to sleep",
            "stop listening",
            "that's all",
            "that is all",
            "[unk]",
        )

        return phrases.toList()
    }
}
