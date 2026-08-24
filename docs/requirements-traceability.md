# Requirements Traceability

Last reviewed: 2026-08-20

Statuses: Not Started, In Progress, Blocked, Implemented, Verified, Deferred.
Implemented means code and automated evidence exist while required physical
acceptance remains open.

| ID | Requirement | Implementation/evidence | Status | Remaining verification |
|---|---|---|---|---|
| FR-001 | Launch native Flutter UI | signed ARM64 `1.4.2`; TECNO BG6 USB update, live focused process and no app-scoped fatal marker; Module 56's 1,191 ms cold foreground launch evidence retained | Verified on target phone | preserve regression |
| FR-002 | Explain/request camera permission | permission flow and safe local-processing copy | Implemented | physical denial/revocation |
| FR-003 | Select Mobile/Wearable mode | Riverpod, persisted settings, route tests | Verified | Pi physical use |
| FR-004 | Start/pause/resume/stop Mobile assistance | `AssistanceController`, integration tests, cleanup | Implemented | repeated physical sessions |
| FR-005 | Capture/process frames on-device | CameraX, bundled YOLOv8n LiteRT; TECNO BG6 live preview/Detecting/one result passed | Implemented | alignment and sustained performance |
| FR-006 | Generic person detection only | COCO person class; no face/identity code | Verified | preserve |
| FR-007 | Estimate risk, not exact distance | bounded relative visual heuristic and tests | Verified | real-scene usefulness |
| FR-008 | Offline spoken and bounded haptic alerts | local TTS, finite patterns, cooldown/rate limits; authenticated Pi priority alerts prefer the connected phone TTS owner with Pi-local disconnect fallback | Implemented | physical phone/Pi output and fallback |
| FR-009 | Configure/persist sensitivity and feedback | local validated settings and tests | Verified | physical comparison |
| FR-010 | Discover/enroll/control local Raspberry Pi | NSD/manual private host, configured `10.141.17.148:8765`, exclusive first-phone enrollment without a displayed code, Keystore credential, authenticated protocol, one Connect & Start action; no SSH secret or auth bypass | Implemented; endpoint blocked | Pi/phone must share one reachable non-isolated LAN |
| FR-011 | Recover from camera/model/output/Pi errors | typed failures, cleanup, retry/reconnect tests | Implemented | induced hardware failures |
| FR-012 | Accessible settings/help/about/running UI | named screens, headings, labels, live regions | Implemented | physical TalkBack |
| FR-013 | Foreground hands-free and manual voice assistant | one-time microphone grant; final-only “Hey/Hi Vision AI” opens a persistent foreground command session; goodbye restores wake-only mode; focused app/scanner graphs; safe cancel/join route switching; serialized manual alternative | Implemented | owner one-wake/multi-command, false-command, repeated profile-switch, crash-log, and TalkBack acceptance |
| FR-014 | Local speech transcription | bundled Vosk `VOICE_RECOGNITION` capture with retained AEC/NS/AGC when supported; dedicated Android preference for manual speech; no ordinary/remote fallback, app audio file, or upload | Implemented | varied voices, accent, noise, microphone-distance, and device-effect matrix |
| FR-015 | Voice/text control of app settings | phone-local semantic parser with whole-word matching and higher fuzzy threshold; persistent session covers app settings plus Scanner capture, reliable start/pause/resume/stop, relative/first/last/numbered-line navigation, full-line spelling, speed, camera, and torch variants; deterministic allow-listed tools | Implemented | physical multi-command and Scanner spoken matrix |
| FR-016 | Voice/text control of Mobile Mode | phone-local transcript routing to real status/start/pause/resume/stop controller checks | Implemented | phone camera/permission states |
| FR-017 | Voice/text control of Raspberry Pi | phone-local transcript routing to real discovery/status/connect/disconnect/session tools; manual and voice paths retain authenticated trusted-phone credentials | Implemented | hardware acceptance |
| FR-018 | Confirmation for sensitive actions | tool-spec enforcement and accessible Confirm/Cancel UI | Implemented | TalkBack confirmation matrix |
| FR-019 | Hybrid AI selection | Smart AI route uses the same phone-local Vosk capture; local commands have priority; unmatched transcript text uses Gemini when configured with automatic Ollama fallback; “bye” restores the active offline command session | Implemented | live paired multi-turn voice, “bye”, final goodbye, Gemini, and forced-outage acceptance |
| FR-020 | Local assistant personal utilities | explicit SQLite notes/reminders/schedule/preferences tools | Implemented | end-to-end user acceptance |
| FR-021 | Clear assistant connection/settings UI | `/assistant`, `/assistant/connection`, `/assistant/settings`, route/widget tests | Verified | physical TalkBack |
| FR-022 | Truthful provider/connection/error state | health schema and typed Flutter failures | Implemented | offline/provider outage UI |
| NFR-ACC-001 | TalkBack-compatible controls | semantic names/headings/live status, accessible confirmation, Document Reader transport/first/last/numbered-line controls, guideline tests | In Progress | manual TalkBack |
| NFR-ACC-002 | Large text/touch targets | bounded nonlinear scaler, responsive Scanner reader controls, and 2x assistant regression tests | In Progress | physical font/display scaling |
| NFR-OFFLINE-001 | Core assistance works without internet | bundled Mobile model and authenticated local Pi event/audio workflow independent of assistant providers; same routed LAN is required, internet is not | Implemented | WAN-disabled physical phone/Pi session |
| NFR-OFFLINE-002 | Assistant has fully local control path | typed and spoken app controls execute on-phone through deterministic tools; Gemini/Ollama backend is optional conversation only | Verified in automated/controller and Android build evidence | WAN-disabled physical spoken-command session |
| NFR-PERF-001 | Practical latency/resource use | Mobile gate/buffers; bounded audio; one local model owner | In Progress | phone/Pi mean/p95/thermal |
| NFR-SEC-001 | Raw frames never uploaded/stored/logged | no assistant frame input; separate inference and text/audio transport | Verified | ongoing review |
| NFR-SEC-002 | Secrets protected | assistant and Pi tokens use Android Keystore AES-GCM; Gemini keys use `SecretStr`; Modules 56-57 removed embedded Pi SSH login use and code-free enrollment issues only a random app credential | Implemented | physical Keystore/revocation and APK scan regression |
| NFR-SEC-003 | Minimize assistant data | no audio file/upload; in-memory phone transcript; diagnostics record word count rather than transcript; no default conversation persistence; unmatched Gemini text-only `store:false` | Implemented | physical and live Gemini request audit |
| NFR-SEC-004 | Local transport boundary disclosed | exclusive private-peer first enrollment, HMAC auth, private-host validation, no manual-IP bypass, trust-on-first-use warning; current split-subnet blocker documented | In Progress | TLS/pinning and physical LAN remain open |
| NFR-REL-001 | Safe provider degradation | deterministic controls and Gemini-to-Ollama fallback tests | Implemented | forced live Gemini outage |
| NFR-MAINT-001 | Platform logic outside widgets | domain service/repository interfaces, Riverpod orchestration, infrastructure adapters | Verified | preserve |
| NFR-MAINT-002 | Tests/docs accompany work | Module 57: analyzer/Ruff clean; 319 Flutter including code-free cross-stack process, 15 Pi, app-native Gradle success, signed ARM64 release build/install, living docs | Verified for Module 57 automation | physical Pi/enrollment/phone audio, reader/voice and accessibility matrices |
| NFR-RESP-001 | Responsive native UI | scrollable layouts, nonlinear scale, 2x tests; no WebView | In Progress | portrait/landscape phone |
| CON-001 | Native Flutter/no WebView | dependency/source/route review | Verified | preserve |
| CON-002 | Limited owner-authorized assistant exception | 2026-08-14 specification amendment permits paired auth and optional Gemini text only | Verified scope decision | preserve exclusions |
| CON-003 | No Firebase/analytics/remote config/cloud vision | source/dependency review; Gemini is reasoning-text exception only | Verified | preserve |
| CON-004 | Settings remain local | SharedPreferences plus deliberate laptop-local assistant SQLite; no cloud sync | Verified | reboot persistence |
| CON-005 | Preserve Stitch sources | no Stitch reference file edited/deleted | Verified | repeat inventory |
| BR-001 | Assistive aid, not replacement/navigation | safety copy in primary screens and assistant docs | Verified | preserve |
| BR-002 | Familiar identity and exact distance excluded | generic class and relative-risk terminology only | Verified | preserve |
| BR-003 | No background/lock-screen or OS-wide assistant control | wake/conversation listener is bounded to the foreground open app; lifecycle stop/restart and manual-mic ownership are serialized | Implemented | battery/thermal and repeated lifecycle acceptance |
