# Offline Vision AI Assistant Guide

## Demo listening reliability — 1.4.18

Keep the app visible and say “Hey Vision AI”, “Hi Vision AI” or “Listen Vision AI”.
Wait until “Listening” finishes and the short ready tone/vibration occurs, then
say one short English command. After ordinary spoken results, the same cue marks
command readiness. Cue output depends on media volume/hardware; it is not emitted
while the document reader speaks or in Smart AI button mode. Vision AI pauses
ordinary commands during feedback and does not provide general interruption.

The local microphone automatically attempts recovery twice. If it cannot recover,
open Assistant Settings and use Restart voice listening, or use the existing
screen buttons. No saved preference, key or Pi pairing is changed. Unknown-word
markers/negated requests ask for repetition instead of being guessed as actions.
[Verification and short demo rehearsal](VISION_AI_RELIABILITY_2026-10-21.md).

Last reviewed: 2026-10-15

## Spoken results and screen commands — 1.4.16

Wake Vision AI with Hey Vision AI, Hi Vision AI, or Listen Vision AI, then speak
a command. Go back, can you please go back, go home, open setting, open settings
and open about page navigate screens. On Smart AI, say these directly without
holding the circle when not recording, including while an answer is paused.
Hold the circle only to record a Smart AI question. Named controls remain available.

Connect to Raspberry Pi announces finding when discovery is needed, connecting,
and the actual outcome. Not found includes hotspot/power guidance; multiple Pis
require selection. A connection does not start detection: say start wearable next.
Start Mobile Mode announces camera preparation and confirms only when active;
permission/startup failures give a reason. Bare pause/resume/stop target the visible
Mobile Mode, wearable or reader; previous line is document movement and go back
exits a screen. Unavailable screen-specific controls do not target another feature.
[Verification and physical limits](VISION_AI_COMMANDS_2026-10-21.md).

## Purpose and Boundary

Offline Vision AI is a foreground, in-app voice controller for blind and
visually impaired Android users. It controls allow-listed AI Blind Assistant
features without internet, pairing, or an AI model. It is not a system-wide
assistant, does not listen while the app is backgrounded or locked, and cannot
be guaranteed to match the proprietary models and microphone tuning used by
Siri or Google Assistant.

Raw microphone audio stays in transient Android/Vosk memory. It is not saved,
logged, or uploaded. Smart AI may send only unmatched transcript text to the
owner-paired private-LAN backend. Camera frames never enter either voice path.

## Interaction

1. Open AI Blind Assistant and grant Microphone once.
2. Say “Hey Vision AI” or “Hi Vision AI”.
3. Wait for the short spoken acknowledgement: “Listening.”
4. Say a command, for example:
   - “Run mobile mode detection.”
   - “Start mobile mode detection.”
   - “Change feedback mode to audio.”
   - “Set speech rate to fast.”
   - “Open Smart AI.”
5. Keep giving offline commands without repeating the wake phrase. Commands
   execute through deterministic Riverpod controllers and the assistant speaks
   each observed result.
6. Say the complete phrase “goodbye” or “stop listening” to end the offline
   command session. Bare “bye”, “by” and “buy” are not exit commands.
7. In Smart AI, ask follow-up questions without repeating the wake phrase. Say
   “exit Smart AI” or “close Smart AI” to return to the active offline command
   session. Opening Smart AI automatically checks the saved paired laptop;
   first-time pairing remains explicit. Entry and Retry do not send a draft.
8. In Scanner, “scan again” or “restart scanner” returns to camera framing.
   Point at the next document, then say “scan document” or tap Scan when ready.
   It waits without a countdown. “Restart reading” returns to the first reading unit.
9. With hands-free enabled, reader playback opens contextual commands directly.
   Multiword reader controls can interrupt ongoing speech; goodbye still ends
   that session. Printed-command collisions are rejected conservatively: use
   the wake phrase, wait for silence/acknowledgement, then command, or use touch.

## Audio and Recognition Pipeline

```text
Android VOICE_RECOGNITION AudioRecord, 16 kHz mono
  -> device AEC / noise suppression / automatic gain control when supported
  -> bundled English Vosk model
  -> wake-only grammar while idle
  -> complete final “Hey/Hi Vision AI” match
  -> pause microphone and speak “Listening.”
  -> focused app/scanner grammar, or Smart AI conversation graph
  -> in-memory transcript
  -> deterministic local intent resolver first
  -> real local controller action, or Smart AI text backend on /assistant only
  -> pause microphone during assistant feedback; keep guarded reader controls during document TTS
  -> restore contextual command/conversation state until explicit goodbye
```

The wake decoder includes `[unk]` so unrelated sound is not forced into an app
command. Partial Vosk hypotheses never activate the wake listener. During
foreground reader playback only, stable multiword proposals can execute a
strong registered reader control after text-echo/context/session checks and
an atomic native claim. They cannot execute navigation, capture or backend tools.
A standalone
“Vision”, “Vision AI”, generic speech, and arbitrary leading words are rejected.
Decoder timeouts do not end an activated offline session; its contextual grammar
keeps listening until explicit goodbye. Smart AI conversation stays active only
while its screen is visible and the app remains foregrounded.

Module 67 evidence: [reader voice verification](READER_VOICE_VERIFICATION_2026-10-15.md),
459 Flutter tests, 13 native app tests, clean analysis and both APK builds.
Device acoustic overlap/AEC remains a physical acceptance check.

## Crash-Safety and Microphone Ownership

`VisionVoiceKernelV3` is the application-level microphone owner. Manual
push-to-talk stops hands-free capture before opening its bounded recognizer and
restores the correct wake or Smart AI state afterward.

Vosk grammar changes do not replace the private recognizer through reflection.
The native handler calls `SpeechService.cancel()`, which interrupts and joins
the decoder thread, then resets the same recognizer, changes its grammar, and
restarts the service. Recognizer close/reset cannot race the active decoder
thread through this path.

## Semantic Command Routing

The Dart resolver checks exact aliases, parameterized patterns, whole-word
semantic composition, and conservative token similarity. Examples such as
“start”, “run”, “begin”, “launch”, “activate”, and “turn on” compose with Mobile
Mode/detection entities. Fuzzy matches require at least two shared tokens and a
0.60 score. Unknown phrases cannot execute an app action.

Supported areas include Mobile Mode start/stop/pause/resume/status, Scanner
capture and reliable reader start/pause/resume/stop, first/last/numbered-line
navigation, full-line spelling and speed controls, feedback mode, sensitivity, accessibility toggles, speech
rate, announcement cooldown, flashlight/environment controls, app navigation,
time/date/battery/status, and Raspberry Pi/wearable controls. Existing safety
confirmation policy still applies where the command executor requires it.

## Smart AI and faster-whisper

Wake-driven Smart AI uses the same phone-local Vosk/AudioRecord stack as the
offline assistant. Known app commands remain deterministic and local. Only
unmatched intentional questions are passed as text to the paired backend, which
may use Gemini when configured and otherwise falls back to local Ollama.

The repository retains a laptop faster-whisper service, but the current mobile
voice path does not send it raw audio. Moving transcription to faster-whisper
would add private-LAN audio transport, latency, backend dependence, and a change
to the approved privacy boundary. An on-device Whisper runtime would also need
separate size, speed, battery, and accuracy validation on the target TECNO BG6.

## Verified and Still Open

Verified on 2026-08-20:

- 312 Flutter tests passed; one Pi simulator test was intentionally gated.
- 8 Android wake/grammar unit tests passed.
- Split release APKs built successfully; ARM64 was installed on the TECNO BG6.
- Changed voice files have no analyzer finding.

Still open pending owner-spoken physical acceptance on the connected phone:

- intended-accent accuracy and quiet/noisy false-wake rate;
- TV/music/fan and phone-speaker echo behavior;
- one-wake/multiple-command/scanner/Smart AI/explicit-exit cycles, including
  rejection of buy/by/bye and incidental conversation;
- reproduction and logcat/tombstone verification of the reported app close;
- TalkBack, permission revocation, audio focus, battery, memory, and thermal
  acceptance.

Treat the assistant as an aid only. It does not replace a white cane, guide
dog, trained human assistance, mobility training, situational awareness, or
user judgment.
