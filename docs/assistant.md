# Voice and AI Assistant

## Vision AI reliability — 2026-10-21

ADR-076 retains bundled on-phone English recognition and local deterministic
controls. Failed resume now surfaces to bounded recovery; stale lifecycle work
cannot reopen capture, and rejected echo wake restores listening. Successful
command readiness after wake/feedback requests a brief local tone/vibration.
Assistant Settings explains turn-taking and provides Restart voice listening on
failure. Normal controls remain paused during spoken feedback. Smart AI recording,
keys, provider selection and consent are unchanged. [Verification/demo guide](VISION_AI_RELIABILITY_2026-10-21.md).

## Fresh-phone Smart AI view — 1.4.17

A fresh phone shows the same circle with Set up Smart AI. Save a personal key and
review provider-specific consent to enable questions. Local commands, spoken setup
instructions and vibration/chime testing need no cloud account. Recording/send
remain disabled until setup; no keys transfer from another phone. Already saved
Gemini/laptop modes are preserved, and Use Gemini or laptop assistant explicitly
opens that alternative. Removing cloud keys keeps setup guidance rather than
silently substituting an unrelated unpaired screen. [Evidence](SMART_AI_FRESH_PHONE_2026-10-21.md).

## Direct local controls alongside Smart AI — 1.4.16

Local Vision AI accepts go back/go home/open setting/open about page and polite
variants directly while the Smart AI foreground screen is idle or paused. Hold
the circle only for a question; it exclusively owns the microphone during capture.
Ordinary local speech cannot start a cloud interaction. Command context follows
the visible route, and local feedback waits for reply cancellation/voice restoration.
Leaving idle/paused Smart AI preserves the new navigation acknowledgement. Saved
hands-free preference and all provider/key/language/capture policies remain.
[ADR-074 and exact evidence](VISION_AI_COMMANDS_2026-10-21.md).

## Listening vibration and sound — version 1.4.15

Hold the Smart AI circle for one second, then wait for the vibration and short
chime before speaking. The cue occurs after the microphone starts. Lift your
finger to send. Use Test listening vibration and sound to check both cues without
recording or using an API. Sound uses the phone's current media volume and route;
if muted, raise media volume and test again. The app does not change volume or
DND. Recording remains usable if a cue is unavailable; follow the Listening label
or named Button controls. Cancel/background/exit stop the bounded cue.

This update changes only Smart AI readiness feedback. Vision AI, language choices,
reply pause/resume and local goodbye retain their behavior. Owner requested the
APK for later testing, so actual motor/speaker output remains unverified.
[Exact evidence](SMART_AI_READY_CUE_2026-10-21.md).

## Smart AI bilingual circle — version 1.4.13

English questions receive English replies; Urdu-script questions receive Urdu
replies, even when switching within the same conversation. The installed offline
Urdu/English voices handle speech. Roman Urdu recognition is not inferred from
this script-based rule.

Hold the large circle for one second. When recording starts it vibrates once if
vibration is enabled; speak, then lift your finger to send. Tap while an answer
plays to pause; tap again to resume from its last reported word. Holding again
interrupts the current turn and begins a new recording. Release during setup
or cancel a touch to discard without sending. Recording still caps at 30 seconds.

For an alternative, expand Button controls and use Speak/Send recording or
Pause/Resume answer. TalkBack activates the circle by its normal double-tap;
Enter/Space also activates it without a timed hold. Existing Cancel and replay
remain available. Pause/resume/replay never request another answer from an API.

Record “goodbye Smart AI” to return Home and restore the saved local hands-free
preference. That phrase needs the usual foreground recording/transcription;
it is not heard in the background or while an answer is playing unless you
start a new recording. Typed goodbye also works without a provider. Existing
Vision AI controls remain local and unchanged. [Evidence/physical gate](SMART_AI_CIRCLE_2026-10-20.md).

## Smart AI cloud audio — 2026-10-19/20

Smart AI uses Groq Whisper large v3 for a temporary foreground 16 kHz mono clip,
then the explicitly selected Groq GPT-OSS 20B for bounded conversation text and
phone-local speech. This is the owner's choice after AgentRouter custom-client
rejection. The original AgentRouter/DeepSeek mode remains a manual option; no
automatic provider fallback is used. Groq selection never calls AgentRouter.

Open Assistant → connection settings → Smart AI cloud audio → Set up personal
Smart AI keys (or Replace personal Smart AI keys). Select Groq for speech and
answers, reuse encrypted saved keys or enter a personal Groq key, review the
speech/text destination/privacy/retention/quotas, select agreement and Use Groq
for Smart AI. Saving does not make an API call. Provider choice/keys stay in
separate Keystore storage; no secret is bundled. Legacy settings keep their
provider; changing provider requires fresh consent and clears conversation.

Speak to Smart AI → speak → Send recording. At 30 seconds it submits; Cancel
stops work. Typed questions skip STT. Deterministic local controls precede the
LLM; cloud text never executes tools. Groq uses the owner's exact concise-answer
prompt, low reasoning effort, no returned reasoning and 512 completion tokens.
The phone clip is deleted after STT/failure, before reasoning; deletion does not
delete provider copies. No cloud frame upload, wake recognition or background
recording. Vision AI/offline assistance remain independent.

Version 1.4.12 selects an installed offline Urdu voice for Urdu script (prefer
Pakistan, permit India) and English voice for English. It restores en-US after
completion/cancel/exit before returning audio ownership. Missing voice data gives
an install/replay message. Read last answer aloud uses retained text locally,
with no new transcription/LLM request. Roman Urdu and arbitrary multilingual
speech are outside this detection rule. The target phone's Urdu pack is installed.

Timeouts and safe provider-specific errors never automatically retry. A client
policy rejection is distinct from key rejection; HTTP 400/422 report request
compatibility, while 413 alone recommends shorter input. Removing cloud keys
restores earlier Gemini/laptop view and preserves their credentials/Pi trust.
This is sequential file-based speech, not full-duplex or guaranteed latency.
Groq free usage is quota/account limited. [Evidence/setup](SMART_AI_CLOUD_AUDIO_2026-10-19.md).

Last reviewed: 2026-10-20

## Laptop-free Gemini — Module 69

Open Smart AI → Connection → Gemini without a laptop. Create a personal key in
[Google AI Studio](https://aistudio.google.com/api-keys), enter it in the obscured
field, review text/history and free-tier data-use disclosure, tick agreement
and select Use Gemini without laptop. No key should be sent through chat or
committed to this repository. The app encrypts it through Android Keystore;
removing it preserves existing Pi/laptop pairing and restores laptop mode.
The default model is `gemini-3.1-flash-lite`; availability/quotas belong to the
owner's project. The app reports quota/key/model/network failures without
pretending the laptop is down. Configuration alone does not verify API access.

Both Speak and hands-free recognize audio on this phone in direct mode. Only
unmatched conversation text and up to ten recent conversation messages go to
Google over HTTPS. Replies are text spoken locally, with no cloud tool execution,
images or raw audio. Background cancels pending requests. Laptop notes/reminders,
Whisper and offline Ollama still require the optional paired laptop. There is
no laptop-free offline general language model or automatic Ollama fallback in
direct mode. Core app controls and Mobile/Pi assistance stay offline.

The [phone hotspot guide](PHONE_HOTSPOT.md) covers laptop and Pi as simultaneous
clients, separate current DHCP addresses and phone audio. USB is needed only
for development/installation, not the local hotspot communication itself.

## Smart AI recognition repair — Module 68

See [speech verification](SMART_AI_SPEECH_VERIFICATION_2026-10-16.md) for the
medium laptop-model default, honored language configuration, deterministic
unprompted decoding, unclear-speech rejection, capture cleanup and pause timing.
The existing paired Speak-button branch records for private-laptop Whisper;
hands-free questions still use bundled phone-local English Vosk. Increasing the
laptop model does not improve hands-free vocabulary. The owner's explicit
2026-10-16 approval permits this private-laptop path with disclosure before Speak
and deletion on both devices after processing/failure; ADR-068's addendum resolves
ISSUE-075's scope conflict. Audio never reaches Gemini. Synthetic tests still
include wrong names/nouns, so physical acceptance remains open (ISSUE-074).

## Reader commands during speech — Module 67

With foreground hands-free enabled, document playback opens a contextual
reader session. Stable multiword proposals can interrupt narration only after
the reader policy, current/recent spoken-text echo protection, session/context
checks and a native one-time claim. Other actions retain final recognition.
No new microphone owner, recording, cloud speech or provider is added.
Goodbye and background suspension remain effective. See
[reader verification](READER_VOICE_VERIFICATION_2026-10-15.md) for 459 Flutter/
13 native passes and the required physical speaker-overlap matrix.

## Module 66 current interaction

Opening Smart AI checks the explicitly saved paired laptop's health/version,
without sending a question or Scanner draft. The bounded check has its own
status and does not block offline voice/app controls; Retry checks connectivity
without replaying text. Returning from Connection settings checks the saved
endpoint. A healthy endpoint is not proof of authenticated/provider readiness.
First-time pairing still requires the owner's one-time code.

End an offline command session with a complete “goodbye”/“stop listening”.
Use “exit Smart AI” to return to offline commands. Bare bye/by/buy and quoted
or incidental substrings do not dismiss a session. These rules supersede older
bare-bye descriptions below. Scanner voice rescan/restart returns to framing;
position the page, then say “scan document” or tap Scan when ready. The owner's
later positioning request supersedes immediate capture in Module 66.
See [verification](VOICE_FIXES_2026-10-15.md).

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

manual press/hold outside paired Smart AI
  -> dedicated Android on-device recognizer when installed
  -> otherwise the bundled Vosk model
  -> same deterministic routing and confirmation policy

manual Speak on paired Smart AI
  -> foreground permission and destination/deletion disclosure
  -> bounded temporary phone-cache clip (30 seconds/4 MB)
  -> existing authenticated private-LAN laptop only
  -> local Whisper medium -> transcript; laptop clip deleted even on failure
  -> deterministic command matcher or optional text-only Gemini/local Ollama
  -> phone clip deleted after request completion/failure
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
through Ollama. Hands-free/unpaired recognition stays on the phone. Paired Smart
AI manual speech uses laptop Whisper with deterministic routing before optional
conversation reasoning; mobile controls still execute through phone controllers.

## Privacy Matrix

| Data | Phone | Laptop | Gemini when enabled |
|---|---|---|---|
| Camera frames/images | transient detection only | never sent | never sent |
| Raw assistant audio | hands-free/unpaired in memory; paired manual uses a bounded temporary cache clip, deleted after request/failure | paired manual only: local Whisper; temporary clip deleted after transcription/failure | never sent |
| Transcript/typed text | session memory and deterministic control parsing | paired manual transcripts and unmatched conversation text; history retention off by default | unmatched conversational requests only |
| Pair bearer token | Android Keystore AES-GCM store | token hash/auth record | never sent |
| Settings/tool state | local settings/controllers | local deterministic wording | never sent |

`PERSIST_CONVERSATION_HISTORY=false` is the default. Notes, reminders, or other
explicit save actions remain deliberate local backend writes. The backend
retains no audio after processing: its temporary transcription file is removed
before query routing, including errors. It logs no audio bytes, bearer token,
API key, query text or camera content.

## Optional General-Conversation Backend

The backend is not required for voice control of app settings, Mobile Mode, or
Raspberry Pi Mode. Install it only if general AI conversation is wanted.

```bash
cd /Users/mm/AI_BLIND_ASSISTANT/laptop_backend
uv venv --python 3.11 .venv
uv pip install --python .venv/bin/python -e '.[dev]'
.venv/bin/python scripts/prepare_whisper_model.py --model medium
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
   offline session; “exit Smart AI” returns to that active offline session.

This mirrors Siri's documented wake-phrase-plus-request pattern and Voice
Access's spoken-command/automatic-listening loop. A distinct phrase and paused
recognition during short assistant feedback reduce false activation, consistent
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
  app controls remain local. Say “exit Smart AI” to leave Smart AI and resume the
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
