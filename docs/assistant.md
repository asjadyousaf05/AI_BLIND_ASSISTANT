# Voice and AI Assistant

Last reviewed: 2026-08-20

## Scope and Safety Boundary

The assistant is a foreground, hands-free in-app assistant. After the user opens
AI Blind Assistant and grants Microphone once, it listens locally for “Hey
Vision AI” or “Hi Vision AI”, answers through TTS, and controls allow-listed app
functions without requiring another screen touch. It is not an Android
system-wide assistant: listening pauses when the app is backgrounded or the
phone is locked. It is not an emergency service, navigation authority, or a
replacement for a white cane, guide dog, trained human support, mobility
training, or user judgment.

Core Mobile Mode and Raspberry Pi assistance remain independent of Gemini and
Ollama. Object detection still runs on the phone or Pi, camera frames never
enter the assistant backend, and safety feedback does not depend on an LLM.

Basic app controls are provider-independent. Typed and spoken control commands
execute on the phone with no pairing, network, Gemini, Ollama, or laptop.
Hands-free speech uses a Vosk English model bundled in the APK, so it does not
depend on an Android speech-service installation. Manual push-to-talk prefers
Android 12+'s dedicated on-device recognizer and falls back to the same bundled
Vosk model. The app deliberately never uses Android's ordinary recognizer,
because that implementation may use a remote server. The in-memory transcript
enters the deterministic phone command matcher before any optional AI provider
is considered. While idle, Vosk uses a small wake-only grammar and accepts only
a finalized, complete branded phrase. It does not activate from a partial
hypothesis, standalone “Vision”, generic speech, or `[unk]`. After activation it
switches to a focused app-command or scanner grammar and keeps that foreground
command session active until an explicit “goodbye”, “bye”, or “stop listening”.
On the Smart AI screen, the same Vosk input uses its conversation graph until
“bye”/“by” returns to the still-active offline command session.

## Runtime Design

```text
typed app command
  -> on-phone deterministic command matcher
  -> strict allow-listed tool -> explicit confirmation when required
  -> Flutter Riverpod controller -> verify resulting real state
  -> deterministic on-phone result wording and Android TTS

foreground hands-free voice
  -> Android RECORD_AUDIO permission
  -> bundled Vosk English speech model
  -> focused local “Hey/Hi Vision AI” final-result activation grammar
  -> spoken “Listening.” acknowledgement
  -> persistent focused app-command/scanner grammar until explicit goodbye
  -> in-memory transcript; no app audio file and no raw-audio upload
  -> on-phone deterministic command matcher
       -> strict allow-listed tool -> explicit confirmation when required
       -> Flutter Riverpod controller -> verify resulting real state
     or, on the Smart AI screen only
       -> default Vosk conversation graph using the same microphone path
       -> unmatched general-conversation text only
       -> optional authenticated laptop on trusted LAN
       -> Gemini when a key is configured and reachable
       -> otherwise local Ollama llama3.2:3b
  -> concise Android TTS response

manual press/hold remains available
  -> dedicated Android on-device recognizer when installed
  -> otherwise the bundled Vosk model
  -> same deterministic routing and confirmation policy
```

The phone matcher is authoritative for basic app controls. On the Smart AI
screen, a typed or wake-driven spoken general-conversation request that is not
a known app command may use the paired backend; it does not silently pretend to
have offline conversational reasoning. Outside Smart AI, unmatched ambient
speech is rejected instead of being sent to a provider.
If no backend is paired, the app explains that app controls remain available.

The model never executes code, shell commands, arbitrary URLs, filesystem
operations, or database statements. It may only propose a JSON tool call. The
backend removes unexpected arguments and rejects unknown tools or invalid
values. Flutter maps the validated tool to existing controllers and reports the
observed state. Offline phone-command results are worded on the phone. Backend
tool-result wording and daily summaries are generated deterministically on the
laptop; neither path sends settings, detections, or tool results to Gemini.

## Supported App Controls

| Area | Typed or spoken examples | Confirmation |
|---|---|---|
| Detection | “Reduce sensitivity”, “Set sensitivity to medium/high” | Required |
| Feedback | “Use audio feedback”, “Use vibration and audio” | Required |
| Accessibility | “Turn on large text/high contrast/reduced motion” | Required |
| Alerts | “Set announcement cooldown to 8 seconds” | Required |
| Mobile Mode | start, pause, resume, stop, read status | Start required; pause/resume/stop direct |
| Raspberry Pi | scan, read status, connect/disconnect | Connect/disconnect required |
| Wearable assistance | start, pause, resume, stop | Start required; pause/resume/stop direct |
| Assistant | read paired status, time/date, recent generic on-device detections, typed questions | No destructive action without confirmation |

If discovery finds no Pi, the command reports that truthfully. If it finds more
than one, the user selects a device on the Raspberry Pi screen. A new Pi still
requires its short-lived pairing code; voice cannot bypass authentication.

## Provider Selection

The backend evaluates providers for each conversational request:

1. If `GOOGLE_API_KEY` or `GEMINI_API_KEY` is set, try Gemini. Google documents
   `GOOGLE_API_KEY` as taking precedence when both exist.
2. If Gemini is unconfigured, unreachable, rejected, rate-limited, or returns
   an invalid response, use the configured local Ollama model.
3. Common app-control phrases bypass both models. Typed phrases use the phone
   matcher; spoken phrases use the same phone matcher after on-device speech
   recognition.

Gemini requests use the current Interactions REST API with `store: false` and a
structured JSON response format. The model name is configurable through
`GEMINI_MODEL`; the current default is `gemini-3.6-flash`. Keys stay in the
laptop environment and are never packaged in the APK or returned to the phone.

With no Gemini key, optional general-conversation reasoning stays on the laptop
through Ollama. App-control recognition and execution always stay on the phone.
The retained Whisper service is not used by the mobile app-control voice path.

## Privacy Matrix

| Data | Phone | Laptop | Gemini when enabled |
|---|---|---|---|
| Camera frames/images | transient detection only | never sent | never sent |
| Raw assistant audio | transient in phone-local AudioRecord/recognizer memory; no app file/upload | never sent by the current mobile voice path | never sent |
| Transcript/typed text | session memory and deterministic control parsing | unmatched conversation text only; history retention off by default | unmatched conversational requests only |
| Pair bearer token | Android Keystore AES-GCM store | token hash/auth record | never sent |
| Settings/tool state | local settings/controllers | local deterministic wording | never sent |

`PERSIST_CONVERSATION_HISTORY=false` is the default. Notes, reminders, or other
explicit save actions remain deliberate local backend writes. The backend
stores no audio file and logs no audio bytes, bearer token, API key, query text,
or camera content.

## Optional General-Conversation Backend

The backend is not required for voice control of app settings, Mobile Mode, or
Raspberry Pi Mode. Install it only if general AI conversation is wanted.

```bash
cd /Users/mm/AI_BLIND_ASSISTANT/laptop_backend
uv venv --python 3.11 .venv
uv pip install --python .venv/bin/python -e '.[dev]'
.venv/bin/python scripts/prepare_whisper_model.py --model base
ollama pull llama3.2:3b
ollama serve
```

## Professional Voice Interaction Pattern

The foreground interaction follows the repeatable pattern used by established
assistants while respecting this app's narrower Android boundary:

1. Ready: the open app displays/listens for one distinct branded phrase.
2. Invoke: say “Hey Vision AI” or “Hi Vision AI”.
3. Acknowledge: Vision AI says “Listening.” and opens a foreground command
   session.
4. Resolve: recognized app controls execute through deterministic tools;
   unmatched conversation uses the optional Gemini-first/Ollama-fallback path.
5. Confirm: a sensitive change stays pending and accepts spoken
   “confirm”/“yes” or “cancel”/“no”.
6. Reply: Vision AI speaks a short, real result, clears buffered wake/TTS audio,
   and resumes the current contextual command grammar. “Goodbye” ends the
   offline session; Smart AI “bye” returns to that active offline session.

This mirrors Siri's documented wake-phrase-plus-request pattern and Voice
Access's spoken-command/automatic-listening loop. A distinct phrase and paused
recognition during the assistant's own TTS reduce false activation, consistent
with professional wake-word guidance. Unlike a system assistant, this release
is deliberately bounded to the visible, unlocked foreground app.

In a second terminal:

```bash
cd /Users/mm/AI_BLIND_ASSISTANT/laptop_backend
cp .env.example .env
.venv/bin/python -m uvicorn src.ai_assistant.main:app --host 0.0.0.0 --port 8765
```

To enable Gemini, place one key in the ignored `.env` file or shell environment:

```bash
GEMINI_API_KEY=your_key_here
```

Never commit `.env`, print the key, embed it in Flutter, or enter it on the
phone. `/health` reports the active/preferred/fallback providers without
exposing credentials.

On this development Mac the backend is registered as a per-user launch service,
starts automatically, and listens on port `8765`. The phone's connection form
defaults to `Asjads-MacBook-Pro.local:8765`, which continues to work if DHCP
changes this Mac's numeric address. A different laptop can replace the host and
port in the same form. The first connection still requires a short-lived code;
this deliberate one-time authentication must not be replaced by a hard-coded
secret. The resulting bearer credential is encrypted with Android Keystore and
reused automatically.

The current LAN transport is HTTP and therefore must be used only on a trusted
private network; do not port-forward or expose port 8765 to the internet.

## Android Interaction

- Grant Microphone once from Assistant Settings or the manual voice control.
- Foreground hands-free voice is enabled by default after permission is granted.
- Say “Hey Vision AI” or “Hi Vision AI” once; after “Listening.”, give commands
  without repeating the wake phrase. The idle recognizer uses a restricted wake
  grammar, then keeps a focused contextual grammar active until “goodbye”.
  Smart AI temporarily changes to the default conversation graph.
- Say “Open Smart AI” or “Start Smart AI” to enter paired conversation. Known
  app controls remain local. Say “bye”/“by” to leave Smart AI and resume the
  active offline command listener. Say “goodbye” again to end that session.
- Confirmation is voice-operable: say “confirm”/“yes” or “cancel”/“no”.
- The app keeps the screen awake while foregrounded. Backgrounding or locking
  the phone stops listening and discards any unfinished transcript; returning
  to the app restarts the listener when the setting remains enabled.
- Manual tap/hold recognition remains an accessible alternative and temporarily
  pauses the wake listener to prevent two microphone owners.
- Typed and spoken app controls work when the laptop is off, unpaired, or
  unavailable and when internet access is absent.
- An absent vendor speech-recognition service no longer blocks voice control,
  because the release includes its own model. It never switches to remote STT.
- Sensitive controls require confirmation after the spoken prompt. This
  prevents a mis-transcription from silently changing safety-relevant behavior.

## Verification and Remaining Physical Work

Module 55 automated evidence covers strict wake matching, persistent command
sessions, contextual Scanner grammar, reliable reader transport and direct-line
actions, semantic aliases, unknown/noise rejection, one-microphone ownership,
Smart AI return behavior, accessible Scanner UI, and the existing regression
suite. All 312 Flutter tests passed with one gated Pi skip; 8 native
wake/grammar tests passed; split release APKs built and the
ARM64 build was installed on the connected TECNO BG6. Static analysis has no
changed-voice-file finding and still reports 6 unrelated pre-existing
user-work findings.

Still required before a production claim: repeated real-speaker wake,
multi-command, and numbered-line accuracy in the intended accent/noise
conditions; reproduction of the prior unexpected close with app-scoped
logcat/tombstone capture; microphone
denial/revocation, TalkBack, TTS/audio focus, repeated grammar changes, sustained
battery/thermal behavior, and WAN-disabled sessions. This implementation is
not claimed to match proprietary Siri/Google recognition accuracy.

## Research Basis

- Android's dedicated `createOnDeviceSpeechRecognizer` API and availability
  check: <https://developer.android.com/reference/android/speech/SpeechRecognizer>
- `EXTRA_PREFER_OFFLINE` alone may have no effect, which is why the app requires
  the dedicated recognizer: <https://developer.android.com/reference/android/speech/RecognizerIntent>
- Installed/supported on-device language capabilities:
  <https://developer.android.com/reference/android/speech/RecognitionSupport>
- Vosk offline toolkit and Android implementation:
  <https://github.com/alphacep/vosk-api> and
  <https://github.com/alphacep/vosk-android-demo>
- Vosk model catalogue and redistribution notes:
  <https://alphacephei.com/vosk/models>
- Siri wake phrase followed immediately by a request:
  <https://support.apple.com/en-us/105020>
- Android Voice Access spoken controls, automatic return to listening, and
  screen-off behavior:
  <https://support.google.com/accessibility/android/answer/6151854>
- Voice-agent wake words should be distinct and easy to remember:
  <https://developer.amazon.com/en-US/alexa/voice-interoperability/design-guide/customer-choice-and-agent-invocation>
- Android wireless debugging setup: <https://developer.android.com/studio/debug/dev-options>
- Gemini API-key environment guidance: <https://ai.google.dev/gemini-api/docs/api-key>
- Gemini system instructions and Interactions REST API: <https://ai.google.dev/gemini-api/docs/text-generation>
- Gemini structured JSON outputs: <https://ai.google.dev/gemini-api/docs/structured-output>
- Gemini function execution remains the application's responsibility:
  <https://ai.google.dev/gemini-api/docs/function-calling>
- faster-whisper CPU/int8 and PyAV behavior:
  <https://github.com/SYSTRAN/faster-whisper>
