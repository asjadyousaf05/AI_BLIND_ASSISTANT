# Professional Application Audit

Audit date: 2026-08-14

## Outcome

The owner-authorized Mobile, Wearable, and foreground Voice Assistant paths are
analyzer-clean, covered by the available automated suites, and packaged as a
verified signed ARM64 release. Accessibility semantics, text scaling,
hands-free interaction, offline/private speech, provider fallback, lifecycle,
Android permissions, Python quality, release reproducibility, and artifact
integrity were reviewed together.

The assistant now follows a professional focused-wake → acknowledgement → command →
confirmation when needed → spoken result → ready cycle. It listens only while
the app is visible and unlocked. This audit does not convert missing human or
hardware evidence into a pass: real-speaker accent/noise/false-wake accuracy,
TalkBack, TTS/audio focus, battery/thermal behavior, camera safety quality,
live Gemini, and Raspberry Pi hardware acceptance remain open.

## Authoritative Research Applied

- [Apple's Siri activation guidance](https://support.apple.com/en-us/105020)
  establishes the memorable wake-phrase-followed-by-request interaction.
- [Android Voice Access commands](https://support.google.com/accessibility/android/answer/6151854)
  informed hands-free controls, spoken cancellation/help, automatic return to
  listening, and screen-off battery behavior.
- [Amazon's voice-agent invocation guidance](https://developer.amazon.com/en-US/alexa/voice-interoperability/design-guide/customer-choice-and-agent-invocation)
  informed the distinct branded wake phrase and prevention of one assistant or
  its TTS accidentally invoking another.
- [Android `SpeechRecognizer`](https://developer.android.com/reference/android/speech/SpeechRecognizer.html)
  documents that its general API is not intended for continuous recognition;
  the app therefore uses bundled Vosk for the continuous foreground path.
- [Vosk Android guidance](https://alphacephei.com/vosk/android) and
  [model catalogue](https://alphacephei.com/vosk/models) support offline Android
  streaming recognition with a packaged lightweight model.
- Flutter's [accessibility testing guidance](https://docs.flutter.dev/ui/accessibility/accessibility-testing),
  Android's [accessibility testing guide](https://developer.android.com/guide/topics/ui/accessibility/testing),
  and [core app quality guidance](https://developer.android.com/docs/quality-guidelines/core-app-quality)
  define automated and remaining physical accessibility acceptance.

## Material Findings and Corrections

| Area | Finding | Correction/evidence |
|---|---|---|
| Wake interaction | Generic “assistant” activation did not match the requested product identity; the first unrestricted decoder then captured audio but did not reliably wake. | Seven-entry “Hey Vision AI” wake grammar with `[unk]`, settled-partial activation, full-graph command switching, bounded decoder tolerance, duplicate suppression, and 5 native JVM tests. |
| Blank wake transcript | Vosk n-best configuration returned final text in `alternatives[]`, but the native handler read top-level `text`, silently discarding healthy recognition. | Release 1.3.3 disables n-best output, accepts both JSON shapes defensively, and locks top-level-text mode with a native contract regression. |
| Missing speech service | TECNO BG6 has no dedicated on-device speech-recognition service. | Official Vosk model/runtime bundled; model unpack and an active unsilenced 16 kHz capture client verified on the phone. |
| Spoken conversation | A control-only flow felt robotic and could not explain itself offline. | Audible wake acknowledgement, spoken results, offline greeting/identity/capability replies, and a calm Vision AI Gemini/Ollama persona. |
| Touch-free safety | Button-only confirmation broke the hands-free requirement. | “confirm”/“yes” and “cancel”/“no” are accepted in the bounded confirmation window; actions cannot execute earlier. |
| Lifecycle | Fast background/resume events could race and leave UI/listener state inconsistent. | Serialized stop/restart queue plus regression test; lock/background stops and foreground resume restarts. |
| Self-activation | TTS/wake audio could remain buffered when recognition resumed. | Recognition pauses for TTS and resets the local recognizer before accepting the next utterance. |
| Privacy | Ordinary Android recognition may use a remote implementation. | Never instantiate it; foreground uses Vosk, manual voice prefers the dedicated local API and falls back to Vosk. No raw-audio file/upload. |
| Backend setup | Requiring manual backend startup/host discovery added friction. | Current Mac runs a per-user launch service and the app defaults to `Asjads-MacBook-Pro.local:8765`; secure one-time pairing remains. |
| Accessibility | Voice state must not depend on color or a touchscreen. | Live semantic readiness/status, meaningful switch label, spoken acknowledgement/result/confirmation, typed/manual alternatives, and 2x widget coverage. |

## Verified Release

| Property | Result |
|---|---|
| Version | `1.3.3`; ARM64 split code `2011` |
| Artifact | `deliverables/AI-Blind-Assistant.apk` |
| SHA-256 | `9430d92b35dca391b24b29521a30e1c294c0578498fa3619869827185713c8ae` |
| Size | 97,185,174 bytes |
| Android | minimum SDK 24; target/compile SDK 36; `arm64-v8a` |
| Signing | ZIP aligned; one RSA-3072 project signer; APK Signature Scheme v2 |
| Flutter | format clean; analyzer clean; 202 tests passed, 1 Pi environment-gated skip |
| Native wake | 5 JVM tests passed; release Kotlin compilation passed |
| Backend | Ruff clean; 49 tests passed with 29 upstream Python 3.14 warnings |
| Target phone | USB update passed; version/code and focused wake-grammar construction verified; active unsilenced local 16 kHz recognition and physical typed-response TTS observed |
| AI provider | Ollama `llama3.2:3b` healthy; Gemini fallback contract tested, no live key configured |

## Release Decision

The software and distributable are ready for owner-observed physical acceptance,
not an unqualified safety or production claim. Do not claim Siri-equivalent
system integration: Vision AI is deliberately scoped to the already-open,
visible, unlocked app. Do not close the release until the unchecked phone,
accessibility, battery/thermal, Gemini, Mobile, and Pi gates in
`RELEASE_CHECKLIST.md` have real recorded evidence.
