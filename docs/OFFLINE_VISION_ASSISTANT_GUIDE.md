# Offline Vision AI Assistant Guide

Last reviewed: 2026-08-20

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
6. Say “goodbye”, “bye”, or “stop listening” to end the offline command session.
7. In Smart AI, ask follow-up questions without repeating the wake phrase. Say
   “bye” (including the common ASR spelling “by”) to leave Smart AI and return
   to the active offline command session.

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
  -> pause microphone during TTS
  -> restore contextual command/conversation state until explicit goodbye
```

The wake decoder includes `[unk]` so unrelated sound is not forced into an app
command. Partial Vosk hypotheses never activate the assistant. A standalone
“Vision”, “Vision AI”, generic speech, and arbitrary leading words are rejected.
Decoder timeouts do not end an activated offline session; its contextual grammar
keeps listening until explicit goodbye. Smart AI conversation stays active only
while its screen is visible and the app remains foregrounded.

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
- one-wake/multiple-command/scanner/Smart AI/“bye”/“goodbye” cycles;
- reproduction and logcat/tombstone verification of the reported app close;
- TalkBack, permission revocation, audio focus, battery, memory, and thermal
  acceptance.

Treat the assistant as an aid only. It does not replace a white cane, guide
dog, trained human assistance, mobility training, situational awareness, or
user judgment.
