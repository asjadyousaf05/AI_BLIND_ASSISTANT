# Requirements Traceability

Last reviewed: 2026-08-14

Statuses: Not Started, In Progress, Blocked, Implemented, Verified, Deferred.
Implemented means code and automated evidence exist while required physical
acceptance remains open.

| ID | Requirement | Implementation/evidence | Status | Remaining verification |
|---|---|---|---|---|
| FR-001 | Launch native Flutter UI | signed ARM64 `1.3.3`; TECNO BG6 USB update, foreground launch, and active local microphone client passed | Verified on target phone | preserve regression |
| FR-002 | Explain/request camera permission | permission flow and safe local-processing copy | Implemented | physical denial/revocation |
| FR-003 | Select Mobile/Wearable mode | Riverpod, persisted settings, route tests | Verified | Pi physical use |
| FR-004 | Start/pause/resume/stop Mobile assistance | `AssistanceController`, integration tests, cleanup | Implemented | repeated physical sessions |
| FR-005 | Capture/process frames on-device | CameraX, bundled YOLOv8n LiteRT; TECNO BG6 live preview/Detecting/one result passed | Implemented | alignment and sustained performance |
| FR-006 | Generic person detection only | COCO person class; no face/identity code | Verified | preserve |
| FR-007 | Estimate risk, not exact distance | bounded relative visual heuristic and tests | Verified | real-scene usefulness |
| FR-008 | Offline spoken and bounded haptic alerts | local TTS, finite patterns, cooldown/rate limits | Implemented | physical output |
| FR-009 | Configure/persist sensitivity and feedback | local validated settings and tests | Verified | physical comparison |
| FR-010 | Discover/pair/control local Raspberry Pi | NSD/manual private host, short code, Keystore, authenticated protocol | Implemented | Pi/phone hardware matrix |
| FR-011 | Recover from camera/model/output/Pi errors | typed failures, cleanup, retry/reconnect tests | Implemented | induced hardware failures |
| FR-012 | Accessible settings/help/about/running UI | named screens, headings, labels, live regions | Implemented | physical TalkBack |
| FR-013 | Foreground hands-free and manual voice assistant | one-time microphone grant, bundled Vosk focused-wake/full-command graph switching, corrected n-best/text result contract, partial activation, duplicate suppression, manual alternative, lifecycle tests | Implemented | owner unlocked audible-response retest and repeated real-speaker/TalkBack acceptance |
| FR-014 | Local speech transcription | bundled Vosk plus dedicated Android recognizer preference for manual speech; no ordinary/remote fallback, app audio file, or upload | Implemented | varied voices, accent, and noise matrix |
| FR-015 | Voice/text control of app settings | phone-local speech/text parser; touch-free command and spoken sensitivity-confirmation tests; deterministic allow-listed tools | Implemented | physical spoken-command matrix |
| FR-016 | Voice/text control of Mobile Mode | phone-local transcript routing to real status/start/pause/resume/stop controller checks | Implemented | phone camera/permission states |
| FR-017 | Voice/text control of Raspberry Pi | phone-local transcript routing to real discovery/status/connect/disconnect/session tools; no pairing bypass | Implemented | hardware acceptance |
| FR-018 | Confirmation for sensitive actions | tool-spec enforcement and accessible Confirm/Cancel UI | Implemented | TalkBack confirmation matrix |
| FR-019 | Hybrid AI selection | Gemini primary when configured; provider-neutral automatic Ollama fallback | Implemented | live Gemini and forced outage |
| FR-020 | Local assistant personal utilities | explicit SQLite notes/reminders/schedule/preferences tools | Implemented | end-to-end user acceptance |
| FR-021 | Clear assistant connection/settings UI | `/assistant`, `/assistant/connection`, `/assistant/settings`, route/widget tests | Verified | physical TalkBack |
| FR-022 | Truthful provider/connection/error state | health schema and typed Flutter failures | Implemented | offline/provider outage UI |
| NFR-ACC-001 | TalkBack-compatible controls | semantic names/headings/live status, accessible confirmation, guideline tests | In Progress | manual TalkBack |
| NFR-ACC-002 | Large text/touch targets | bounded nonlinear scaler and 2x assistant regression tests | In Progress | physical font/display scaling |
| NFR-OFFLINE-001 | Core assistance works without internet | bundled Mobile model and local Pi workflow independent of assistant/providers | Implemented | WAN-disabled physical session |
| NFR-OFFLINE-002 | Assistant has fully local control path | typed and spoken app controls execute on-phone through deterministic tools; Gemini/Ollama backend is optional conversation only | Verified in automated/controller and Android build evidence | WAN-disabled physical spoken-command session |
| NFR-PERF-001 | Practical latency/resource use | Mobile gate/buffers; bounded audio; one local model owner | In Progress | phone/Pi mean/p95/thermal |
| NFR-SEC-001 | Raw frames never uploaded/stored/logged | no assistant frame input; separate inference and text/audio transport | Verified | ongoing review |
| NFR-SEC-002 | Secrets protected | assistant and Pi tokens use Android Keystore AES-GCM; Gemini keys use `SecretStr` environment config | Implemented | physical Keystore/revocation |
| NFR-SEC-003 | Minimize assistant data | no app-command audio file/upload; in-memory phone transcript; no default conversation persistence; unmatched Gemini text-only `store:false` | Implemented | physical and live Gemini request audit |
| NFR-SEC-004 | Local transport boundary disclosed | pairing and bearer auth; private-host validation; trusted-LAN warning | In Progress | TLS/pinning remains open |
| NFR-REL-001 | Safe provider degradation | deterministic controls and Gemini-to-Ollama fallback tests | Implemented | forced live Gemini outage |
| NFR-MAINT-001 | Platform logic outside widgets | domain service/repository interfaces, Riverpod orchestration, infrastructure adapters | Verified | preserve |
| NFR-MAINT-002 | Tests/docs accompany work | 202 Flutter tests plus 1 gated skip, 5 native wake/parser tests, 49 backend tests, analyzer, signed release, living docs | Verified | restore fresh Pi test run |
| NFR-RESP-001 | Responsive native UI | scrollable layouts, nonlinear scale, 2x tests; no WebView | In Progress | portrait/landscape phone |
| CON-001 | Native Flutter/no WebView | dependency/source/route review | Verified | preserve |
| CON-002 | Limited owner-authorized assistant exception | 2026-08-14 specification amendment permits paired auth and optional Gemini text only | Verified scope decision | preserve exclusions |
| CON-003 | No Firebase/analytics/remote config/cloud vision | source/dependency review; Gemini is reasoning-text exception only | Verified | preserve |
| CON-004 | Settings remain local | SharedPreferences plus deliberate laptop-local assistant SQLite; no cloud sync | Verified | reboot persistence |
| CON-005 | Preserve Stitch sources | no Stitch reference file edited/deleted | Verified | repeat inventory |
| BR-001 | Assistive aid, not replacement/navigation | safety copy in primary screens and assistant docs | Verified | preserve |
| BR-002 | Familiar identity and exact distance excluded | generic class and relative-risk terminology only | Verified | preserve |
| BR-003 | No background/lock-screen or OS-wide assistant control | wake listener is bounded to the foreground open app; screen stays awake; lifecycle stop/restart is serialized | Implemented | battery/thermal and repeated lifecycle acceptance |
