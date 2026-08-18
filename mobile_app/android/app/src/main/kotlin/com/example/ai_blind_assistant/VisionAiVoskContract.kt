package com.example.ai_blind_assistant

/** Vosk result-shape settings relied on by the native transcript parser. */
internal object VisionAiVoskContract {
    // Vosk emits the top-level `text` field only when n-best alternatives are
    // disabled. Keep this at zero unless every consumer is migrated together.
    const val maxAlternatives = 0
}
