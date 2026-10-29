# Smart AI cloud speech verification

Started 2026-10-19; updated 2026-10-20 (Asia/Karachi). Module 70.

## Current result

Implemented the owner-approved Smart AI-only sequential pipeline:
foreground 16 kHz mono AAC/M4A recording → Groq `whisper-large-v3` → Groq
`openai/gpt-oss-20b` → phone-local speech. The exact original system prompt is
preserved. The owner explicitly chose Groq for answers after AgentRouter's
client-access rejection; no automatic provider/model fallback is introduced.
The original `deepseek-v4-flash` AgentRouter adapter remains an optional manual
selection. Groq mode never calls AgentRouter or needs its key.

Version **1.4.12/code 4052** is installed on TECNO BG6 with retained app data,
matching installed bytes/signer and non-debuggable flags. Groq selection/consent
and encrypted keys survive the update. The owner confirms Urdu transcription
and Urdu replies on 1.4.11; an English-only speech defect triggered the isolated
Urdu voice repair in 1.4.12. The owner confirms **Urdu speech and replay both work** on 1.4.12. Physical
Start/Cancel, background capture cancellation/resume, and settings leave/reentry
also pass without an upload. No measured end-to-end latency or broad acoustic
acceptance is claimed.

## Scope and architecture

Existing feature-first layers and Riverpod providers/Notifier remain. Separate
Smart AI domain configuration/provider selection, repository, cloud service,
audio coordinator and reply-speech interfaces isolate its controller and view.
Existing named Assistant/Connection routes and folders are reused. No package,
SDK, conversion worker, isolate, additional background thread or backend is
introduced. Direct asynchronous Dart HTTPS implements OpenAI-compatible wire
protocols using a reusable client.

Vision AI/kernel/grammar/native recognizers, shared assistant session controller,
shared TTS implementation, camera/model, Pi/backend, routes, dependencies and
source version/signing files match the pre-request snapshot. The sole native
edit adds `getSmartAiCacheDirectory` to the existing recorder handler; existing
recording operations/format are unchanged. Two existing Smart AI presentation
files select/embed the isolated view/setup. ADR-070/071 and the specification/
agent guide record the owner's narrow cloud-audio and provider exceptions.
All **31 Stitch reference/document hashes** remain unchanged; no baseline
file is removed. The existing dirty workspace is preserved; no commit or push.

## Behavior and limits

| Stage | Implemented behavior |
|---|---|
| Capture | Existing native 16 kHz mono AAC/M4A, 64 kbps, 30 s/4 MB caps; feature-specific private Android cache; no conversion |
| Transcription | Fixed Groq `/openai/v1/audio/transcriptions`, multipart generic filename, whisper-large-v3, JSON text, temperature zero, 20 s deadline |
| Groq answer | Fixed `/openai/v1/chat/completions`, GPT-OSS 20B, low reasoning effort, `include_reasoning:false`, 512 completion tokens including internal reasoning, 25 s deadline |
| Optional AgentRouter | Original fixed `https://agentrouter.org/v1/chat/completions`, deepseek-v4-flash, 220 tokens, explicit non-thinking option, 25 s deadline; custom-client access remains blocked |
| Prompt/history | Exact owner system prompt; six recent non-tool user/assistant messages, 2048 chars each; current query/transcript ≤4096 chars |
| Transport | 8 s connect timeout, 128 KiB response bound; no redirects, retries, tools or host/model substitutions |
| Turn | Single operation, cancellable; network turn ≤45 s after capture; generations suppress late/background results; foreground-only recording |
| Speech | Existing shared speech owner; offline Urdu voice preferred ur-PK, alternate installed Urdu locale accepted; offline English for English; en-US restored before release; answer ≤8192 chars |
| Replay | Read last answer aloud reuses retained answer locally without STT, LLM or command routing |
| Privacy | Personal encrypted Keystore credentials/provider choice; no key in source/APK/logs; no audio/frame/transcript logging or persisted conversation |

The exact system instruction remains:

> You are a helpful, empathetic real-time assistant for a blind individual. Listen to their query and give highly concise, clear, and direct answers. Avoid lengthy lists, markdown symbols, or bullet points because your text output will be directly read aloud to them. Keep responses conversational and brief.

Typed input skips capture/transcription. Recognized user controls use the
existing deterministic router before conversation; cloud output never runs
commands. Local wake listening pauses on this screen and its saved preference
is restored on exit. No Vision AI recognition/provider behavior changes.

Phone clips are deleted immediately after transcription, before reasoning,
and on failure/cancellation. Next capture removes only this feature's orphan
cache prefix after process death. Phone deletion does not delete provider
copies; provider privacy/retention policies apply. Voice selection only accepts
installed offline voices; missing Urdu data gives install/replay recovery
instead of silently using English. Serialized selection/restoration is guarded
against cancel/exit races. Script-based Urdu and English are covered; Roman
Urdu and arbitrary multilingual pronunciation are not claimed.

This is sequential file-based interaction, not full-duplex streaming. Provider
queues/network can dominate delay; successful builds/tests do not prove real-time
latency. Groq free-plan quotas depend on account/model limits, not unlimited use.

## Setup

1. Assistant → connection settings → Smart AI cloud audio.
2. Expand Set up personal Smart AI keys (or Replace personal Smart AI keys).
3. Select Groq for speech and answers. Reuse saved keys without exposing fields,
   or enter a personal Groq key. AgentRouter is a separate optional selection.
4. Review recipient/retention/quotas, tick consent and select Use Groq for Smart AI.
5. Return, tap Speak to Smart AI, speak, then Send recording. At 30 s it submits
   automatically. Stop/Cancel remain available. Typed questions skip STT.
6. Read last answer aloud replays locally; missing voice data requires installing
   its Android text-to-speech voice pack first.

Save makes no API call, clears entry fields, and encrypts selection/keys under a
separate storage key. Older provider-less configurations retain AgentRouter;
unknown providers fail closed. Provider changes require renewed destination
consent and clear conversation. Removing Smart AI keys restores the previous
Gemini/laptop view while preserving their credentials and Pi trust. Keys are
personal prototype credentials; no shared production secret is bundled.

## Runtime findings and corrections

- 1.4.8 saved configuration but displayed a microphone-start error. This did not
  prove rejected keys. 1.4.9 gets private cache from Android instead of assuming
  Dart system temp is permitted, and reacquires audio before capture. Actual
  Start → Recording → Cancel succeeds without upload.
- Both owner-supplied keys were entered into obscured phone fields transiently,
  without plaintext files or diagnostic prints, and saved through Keystore.
  Source/APK never embeds the supplied values.
- Owner then reported AgentRouter timeout and shorter-input advice. UI confirms
  timeout; visible user question lengths were only 10–44 chars. The old generic
  HTTP 400 message wrongly implied excessive input. Now 400/422 report request
  compatibility, 402 account credit, 413 size and 408/504 gateway timeout.
- Three read-only AgentRouter model-list checks return HTTP 401; a bounded,
  credential-redacted diagnostic identifies `unauthorized_client_error` /
  `unauthorized client detected`. Owner confirms token/model enabled and no
  dashboard log. This is not proof of an invalid key. No agent-triggered
  AgentRouter completion was made; owner-triggered requests/billing are separate.
  No client impersonation or alternate gateway is introduced.
- Owner explicitly selected Groq speech and answers. Groq metadata using the
  application HTTP stack returns HTTP 200, listing Whisper and GPT-OSS 20B.
  An earlier Python urllib metadata check returned 403; that does not establish
  rejection by the application stack. GET diagnostics generate no answer/audio.
- Groq selection and renewed consent save on the physical phone using encrypted
  keys. Owner confirms Urdu input recognition and Urdu response text. The old
  English voice pronounced only English fragments. Google's Urdu (Pakistan)
  pack is installed (Delete voice pack shown); no download is necessary.
- 1.4.12 adds only the Smart AI locale adapter and local replay. System TTS
  settings were restored to their initial Use system language after inspection.
  Owner confirms Urdu pronunciation and local replay both work. The phone
  returns Ready with its Groq disclosure; no new API call is needed for replay.

## Final physical acceptance — 2026-10-20

Owner reply: **Urdu speech and replay both work**. This confirms the repaired
Urdu path produces audible output and its retained answer replays on the phone.
No extra AgentRouter credit was spent by the agent. No latency number, provider
billing amount, noise/accent matrix or full TalkBack acceptance is inferred.

Local lifecycle checks (no Send/upload/provider action): Start reaches Recording,
Cancel returns Ready; another capture reaches Recording before Home/background,
then foreground resumes to Ready with Send/Cancel absent. A first immediate
lifecycle snapshot preceded settled UI state; a bounded repeat that explicitly
waited for Recording and Ready passes. Settings leave/reentry returns Ready and
retains Groq selection. Current app process remains alive; inspected crash
buffer contains zero current-process FATAL EXCEPTION/native Fatal signal markers.
Broader local Vision AI wake-command acoustics remain a separate acceptance
matrix; its implementation/source hashes remain unchanged.

## Commands and exact verification

Flutter commands run in `mobile_app/` unless specified.

| Command/check | Exact result |
|---|---|
| Scoped `dart format`, then `--output=none --set-exit-if-changed` | Exit 0; 25 files, zero changes |
| `dart fix --apply --code=prefer_initializing_formals,curly_braces_in_flow_control_structures` | Four locale-adapter/test style fixes; no protected-source change |
| `flutter --no-version-check analyze --no-pub` | Exit 0; No issues found, 2.5 s |
| `AIBA_PI_PYTHON=/Users/mm/AI_BLIND_ASSISTANT/raspberry_pi/.venv/bin/python flutter --no-version-check test --no-pub --concurrency=4 -r expanded` | Exit 0; **571 passed**, ~16 s, real Python simulator; **73 new cases** relative to baseline 498 |
| Post-style locale-adapter/screen tests | Exit 0; **15 passed** |
| Earlier `JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew :app:testDebugUnitTest --rerun --offline --console=plain` in Android | Exit 0; BUILD SUCCESSFUL in 7 s, **13 tests**, zero failures/errors/skips; native source unchanged since |
| `flutter --no-version-check build apk --debug --target-platform android-arm64 --split-per-abi --build-name=1.4.12 --build-number=2052` | Exit 0; assembleDebug **9.2 s** |
| Same build with `--release` | Exit 0; assembleRelease **22.9 s** |
| Candidate signature / installed predecessor comparison / 16 KiB zip alignment | All pass; existing phone development signer, source signing unchanged |
| `adb install --no-incremental -r /tmp/AI-Blind-Assistant-1.4.12-phone.apk` | Success; no uninstall/data clear |
| Pulled installed APK, package flags/version/time | Hash matches; **1.4.12/code 4052**, DEBUGGABLE absent, firstInstallTime **2026-10-15 07:27:09** |
| `adb shell am start -W -n com.example.ai_blind_assistant/.MainActivity` | Status **ok**, COLD, TotalTime **1030 ms**, WaitTime **1068 ms** |
| Physical Urdu/replay and local lifecycle | Owner confirms Urdu speech/replay; Start/Cancel, background/resume, settings reentry pass; no extra provider request |
| Current-process crash-buffer inspection | App alive; zero FATAL EXCEPTION and native Fatal signal markers |
| Scoped credential-shaped literal scan | Zero matches in this task's source/docs; no values printed |
| `git diff --check`, scoped preservation | Exit 0; 31 Stitch hashes unchanged, zero original removals; only native cache lookup differs among protected files |

Builds retain existing legacy Kotlin plugin/SDK tooling warnings; both succeed.
Source package version/signing/dependencies remain unchanged; flags set artifact
version. No aggregate plugin/native/lint gate is promoted by the app-native task.

Regression coverage includes actual synthetic HTTP multipart/header/destination,
exact prompt/model, same-key Groq routing with no AgentRouter contact, excluded
reasoning, bounded context/body, auth/credit/quota/size/status/malformed errors,
no redirects/retries/tools, bounded client-error parser, late connection abort,
sequential flow, immediate clip cleanup, native-start/cancel/focus races,
background deadlines, deterministic controls, credential isolation/failure/
legacy migration, consent, narrow/2× UI, offline Urdu/English selection, missing
or uninstalled voice data, cancellation during selection/speech, and local replay
without API/control calls.

Intermediate evidence is retained: first full 542 pass/five missing-fake widget
failures were corrected without removing assertions; 547 then passed. Native
cache repair gave 548; error-message/non-thinking intermediate 553; Groq selection
560. Two intermediate Groq widget failures exposed null configuration before
async load and were fixed with nullable presentation. Locale adapter style
findings were fixed; final analysis is clean. Earlier 1.4.8 debug/release builds
22.3/30.8 s; 1.4.9 15.1/26.1 s; 1.4.10 9.7/23.5 s; 1.4.11 9.3/22.4 s.
Earlier 1.4.8 crash inspection had zero app fatal evidence; current physical
voice/lifecycle acceptance is not inferred from those old checks.

## Current artifacts

- Project-signed ARM64 release: **126,244,592 bytes**, SHA-256
  `7f9324fa2ff956d644d07abcac2c3751de4524ecad6056ef1983b91c1a3562d7`.
- Matching-phone-signer release-mode candidate: **126,289,831 bytes**, SHA-256
  `f92edf5641b6f46e39168628773b8c72bbcb97d45bead053cdd6ec24f185fdd0`.
- Identical ignored deliverable:
  [AI-Blind-Assistant-1.4.12-smart-ai.apk](../deliverables/AI-Blind-Assistant-1.4.12-smart-ai.apk).

Current installed bytes match the second hash. Older ignored artifacts remain.
No source signing configuration, uninstall or pairing rotation was required.

## Primary sources

- [Groq speech-to-text](https://console.groq.com/docs/speech-to-text): accepted
  format, endpoint/model, and 16 kHz mono guidance.
- [Groq models](https://console.groq.com/docs/models),
  [reasoning controls](https://console.groq.com/docs/reasoning), and
  [free-plan quotas](https://console.groq.com/docs/rate-limits).
- [AgentRouter guide](https://github.com/agentrouter-org/docs/blob/main/qwencode.md)
  confirms `/v1`; [client-denial report](https://github.com/agentrouter-org/docs/issues/37)
  in its tracker matches the observed diagnostic. This is a user report, not
  provider approval for this app.
- Locale support/voice metadata verified against installed flutter_tts 4.2.5
  Dart/native implementation and actual Android speech settings; no dependency
  upgrade or remote TTS provider introduced.

## Required completion record

1. **Module result:** approved Smart AI pipeline/Groq selection implemented,
   installed/software verified; Urdu input/reasoning/spoken reply/local replay
   owner-confirmed; physical cancellation/background/reentry pass.
2. **Workspace before:** extensive existing dirty work preserved; 539-file
   pre-request hash snapshot. No commit/push.
3. **Architecture:** feature-first domain interfaces, application orchestration,
   isolated infrastructure adapters and Smart AI presentation.
4. **State management:** existing Riverpod Notifier/providers.
5. **Routing:** existing centralized named Assistant/Connection routes.
6. **Folders:** existing layer/feature/test folders reused; none created.
7. **Screens:** isolated cloud Smart AI view and embedded connection card.
8. **Domain types:** configuration/provider enum, repository, transport/safe
   exception, audio coordinator and localized reply-speech interfaces.
9. **Tests:** five new test files/shared fakes plus original fixture/screen
   updates; 73 additional cases, 571 total; prior native 13 pass.
10. **Markdown created:** this verification report.
11. **Markdown updated:** AGENTS/specification/ADR/architecture, current/status/
    handoff/known issues/changelog/testing/index/traceability, assistant/build/
    deliverable guidance; exact file inventory below.
12. **Requirements:** FR-013/014/015/019/022, NFR-SEC-002/003, NFR-REL-001,
    NFR-MAINT-002 under explicit ADR-070/071 exceptions.
13. **Commands:** format/style/analyze, focused/full tests, debug/release builds,
    read-only model metadata, signer/install/package/launch/UI checks.
14. **Results:** exact command table and intermediate failures/corrections above.
15. **Android:** 1.4.12/code 4052 ARM64 debug/release pass, matching-signer update
    and installed-byte/cold-launch verification pass.
16. **Added:** 20 scoped source/test/report files; ignored delivery APK additional.
17. **Modified:** 22 existing files relative to pre-request hashes, listed below.
18. **Unchanged:** Vision AI/kernel/recognizers/shared session/shared TTS,
    backend/camera/model/Pi/routes/dependencies/source version/signing.
19. **Stitch:** all 31 reference/document hashes unchanged; zero original removals.
20. **Known issues:** optional AgentRouter client denial; broader noise/TalkBack/
    measured latency/local wake acoustic acceptance and prior Pi power remain.
21. **Deferred:** duplex streaming, cloud wake, Roman Urdu/general multilingual
    voice detection, shared production secrets; no vision work added.
22. **Next action:** use installed Groq mode for normal short English/Urdu turns;
    record broader accent/noise/TalkBack/latency acceptance separately.
23. **Git-style summary:** `feat(smart-ai): Groq speech and answers with offline Urdu replies`.

## Scoped file inventory

Existing files changed relative to the pre-request snapshot:

```text
AGENTS.md
deliverables/README.md
docs/AGENT_HANDOFF.md
docs/BUILD_AND_RUN.md
docs/CHANGELOG.md
docs/CURRENT_MODULE.md
docs/INDEX.md
docs/KNOWN_ISSUES.md
docs/PROJECT_STATUS.md
docs/TESTING.md
docs/architecture.md
docs/assistant.md
docs/decision-log.md
docs/requirements-traceability.md
docs/specification-baseline.md
mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/AssistantAudioRecorderHandler.kt
mobile_app/lib/features/assistant/presentation/assistant_connection_screen.dart
mobile_app/lib/features/assistant/presentation/assistant_screen.dart
mobile_app/test/app/module4_ui_migration_test.dart
mobile_app/test/app/router_test.dart
mobile_app/test/features/assistant/assistant_screen_test.dart
mobile_app/test/features/assistant/gemini_connection_screen_test.dart
```

New source/test/report files:

```text
docs/SMART_AI_CLOUD_AUDIO_2026-10-19.md
mobile_app/lib/app/smart_ai_cloud_controller.dart
mobile_app/lib/app/smart_ai_cloud_providers.dart
mobile_app/lib/domain/entities/smart_ai_cloud_configuration.dart
mobile_app/lib/domain/repositories/smart_ai_cloud_configuration_repository.dart
mobile_app/lib/domain/services/smart_ai_audio_coordinator.dart
mobile_app/lib/domain/services/smart_ai_cloud_service.dart
mobile_app/lib/domain/services/smart_ai_reply_speech_service.dart
mobile_app/lib/features/assistant/presentation/smart_ai_cloud_connection_card.dart
mobile_app/lib/features/assistant/presentation/smart_ai_cloud_screen.dart
mobile_app/lib/infrastructure/assistant/http_smart_ai_cloud_service.dart
mobile_app/lib/infrastructure/assistant/localized_smart_ai_reply_speech.dart
mobile_app/lib/infrastructure/assistant/secure_smart_ai_cloud_configuration_repository.dart
mobile_app/lib/infrastructure/assistant/smart_ai_audio_recorder.dart
mobile_app/test/features/assistant/http_smart_ai_cloud_service_test.dart
mobile_app/test/features/assistant/localized_smart_ai_reply_speech_test.dart
mobile_app/test/features/assistant/smart_ai_cloud_controller_test.dart
mobile_app/test/features/assistant/smart_ai_cloud_screen_test.dart
mobile_app/test/features/assistant/smart_ai_cloud_storage_recorder_test.dart
mobile_app/test/helpers/smart_ai_cloud_fakes.dart
```
