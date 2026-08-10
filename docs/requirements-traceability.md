# Requirements Traceability

Last reviewed: 2026-08-09

Statuses: Not Started, In Progress, Blocked, Implemented, Verified, Deferred.
“Implemented” means the code and automated evidence exist but a required
physical-device acceptance check is still open.

| ID | Requirement | Implementation/evidence | Status | Remaining verification |
|---|---|---|---|---|
| FR-001 | Launch native Flutter UI | startup/routes, `WT-APP-001`; signed ARM64 release built and emulator evidence retained | Implemented | final release install/launch on physical phone |
| FR-002 | Explain camera permission | permission screen and safe local-processing copy, `WT-UI-003` | Verified | TalkBack review on phone |
| FR-003 | Request camera before capture | native MethodChannel and assistance gate, `UT-PERM-001`–`012` | Implemented | physical deny/permanent-deny/Open Settings |
| FR-004 | Select Mobile Mode | Riverpod/settings route and local persistence, `WT-UI-002`, `UT-SETTINGS-*` | Verified | none for current scope |
| FR-005 | Select Raspberry Pi Mode after Mobile Mode is stable | owner-authorized ADR-031; preserved route/controller and verified simulator service | Implemented | Pi/phone physical acceptance |
| FR-006 | Start assistance | `AssistanceController`, `UT-INT-001`–`006`; emulator reached Detecting | Implemented | physical camera session |
| FR-007 | Pause/stop assistance and release resources | `UT-INT-007`–`008`, `UT-INT-021`, `WT-UI-008`; explicit pause, Home stop, generation and route-exit cleanup | Implemented | repeated physical cycles |
| FR-008 | Capture Android camera frames | `MobileCameraService`, rear-camera fallback, actionable CameraX errors, structured YUV planes, `UT-CAM-001`–`008`; virtual camera streamed | Implemented | physical startup, stride/orientation and alignment |
| FR-009 | Run detection fully on-device | bundled model, `TfliteInferenceService`, native `InferenceHandler`; current emulator LiteRT/XNNPACK log and `Detecting` | Implemented | physical airplane-mode run |
| FR-010 | `person` means generic object class | COCO label 0 and parser tests; no face/identity code | Verified | preserve in future model work |
| FR-011 | Estimate risk, not exact distance | visual proximity/importance heuristic, `UT-RISK-001`–`010` | Verified | physical usefulness study later |
| FR-012 | Offline audio feedback | local Android TTS architecture and `UT-ALERT-*` | Implemented | installed offline voice and intelligibility on phone |
| FR-013 | Structured vibration feedback | finite `DeviceVibrationService` patterns, unavailable-hardware error, and mode tests | Implemented | physical haptic behavior |
| FR-014 | Cooldown and bounded repetition | per-class cooldown, duplicate/global rate limits, urgent rule, `UT-ALERT-003`–`012` | Verified | real-scene cadence check |
| FR-015 | Configure sensitivity | saved low/medium/high maps to 0.60/0.45/0.30, widget/settings/parser tests | Verified | physical detection comparison |
| FR-016 | Choose audio, vibration, or both | saved `FeedbackMode` enforced; `UT-INT-022` rejects a configuration with no effective output | Verified | physical output check |
| FR-017 | Persist settings locally | SharedPreferences validation/recovery, `UT-SETTINGS-001`–`005` | Verified | none |
| FR-018 | Discover/enter local Pi target | Android NSD TXT identity, saved stable-ID refresh, validated private manual endpoint, `wearable_protocol_test` | Implemented | real LAN mDNS/hostname/manual acceptance |
| FR-019 | Handle Pi connection loss | authenticated heartbeat, stale detection, bounded retry/backoff, endpoint rediscovery, dynamic concrete-private Pi binding/address monitor, lifecycle controller, cross-stack disconnect/reconnect-to-running test | Implemented | Wi-Fi/IP/Pi reboot tests on hardware |
| FR-020 | Recover from runtime errors | typed assistance failures, retry, cleanup, `UT-INT-003`–`015`; emulator no fatal error | Implemented | induce camera/model/TTS failures on phone |
| FR-021 | Settings, help, about screens | native routes/widget tests; saved contrast, text scale, and motion preferences apply globally | Verified | TalkBack review |
| FR-022 | Running UI status/current alert/stop | dynamic states, live region, detection boxes, stop/retry; widget/controller/emulator evidence | Implemented | real current alert on phone |
| FR-023 | Clear navigation | centralized routes and `WT-ROUTER-001`–`004` | Verified | none |
| FR-024 | Pi screen exposes truthful disconnected/unconfigured states | preserved UI, explicit protocol/assistance/component/health states, `WT-UI-005`, wearable semantic test | Verified in widget tests | physical TalkBack/telemetry review |
| NFR-ACC-001 | TalkBack-compatible controls | semantic labels/live states, `WT-ACC-001`, Wearable setup semantic controls | In Progress | manual TalkBack on physical phone |
| NFR-ACC-002 | Large text and touch targets | shared tokens, app-level saved large-text scaling, `WT-ACC-002`, `WT-UI-007` at 2.0 scale | In Progress | physical font/display scaling |
| NFR-ACC-003 | Accessible dynamic state/focus design | native controls, live status, accessibility docs/tests | In Progress | manual focus/announcement order |
| NFR-OFFLINE-001 | Core assistance works without internet | bundled Mobile runtime plus local-only Pi service/model/protocol; cross-stack simulator has no cloud dependency | Implemented | WAN-disabled phone/Pi cold session |
| NFR-OFFLINE-002 | UI assets/fonts are local/native | no runtime URLs/WebView/remote fonts; source audit | Verified | continue preserving |
| NFR-PERF-001 | Practical assistive inference rate | Mobile 200 ms gate; Pi 320 input, frame stride, 3 threads, one-slot latest-frame drop | In Progress | mean/p95/FPS on phone and Pi |
| NFR-PERF-002 | Avoid excessive memory/battery/thermal use | reusable Mobile buffers; Pi one loaded model, bounded queues/retries/logs and lifecycle cleanup | In Progress | sustained phone/Pi profiling |
| NFR-SEC-001 | Raw frames stay on device | transient Mobile frames never enter the separate wearable transport; no frame upload/log/storage | Verified | ongoing code review |
| NFR-SEC-002 | No exposed secrets/API keys | short-lived codes, per-phone random secret, Android Keystore AES-GCM, Pi verifier-only mode-0600 store, no credential logs | Implemented | physical secure-store/revocation inspection |
| NFR-REL-001 | Safe degradation | Mobile failures plus Pi bounded camera recovery, protocol errors, heartbeat/retry/idempotency, persisted state, simulator reconnect | Implemented | hardware service/camera/network failure matrix |
| NFR-MAINT-001 | Platform logic outside widgets | domain interfaces, infrastructure implementations, Riverpod orchestration | Verified | preserve architecture |
| NFR-MAINT-002 | Tests and docs accompany modules | 146 Flutter tests plus 14 Python tests, Ruff, cross-stack E2E, analyzer-clean signed ARM64 release, and living docs | Verified | keep current after device acceptance |
| NFR-MAINT-003 | Centralized UI tokens | theme token tests and existing native UI | Verified | preserve |
| NFR-RESP-001 | Adapt to screen/orientation | responsive safe areas, preview aspect correction, large-text tests | In Progress | portrait/landscape physical review |
| NFR-RESP-002 | Avoid fixed Stitch canvas | native scrollable layouts and `WT-UI-007` | In Progress | physical screenshots |
| CON-001 | Native Flutter, no WebView | dependency/source review and route tests | Verified | preserve |
| CON-002 | No Firebase/cloud analytics/auth/cloud APIs | dependency, manifest, and source review | Verified | preserve |
| CON-003 | Module 1 did not implement inference | historical scope boundary | Verified | none |
| CON-004 | Mobile Mode before Pi Mode | ADR-031 records explicit owner authorization for isolated Module 15; Mobile pipeline remains independent | Verified scope decision | Mobile physical acceptance still open |
| CON-005 | Finite vibration with cooldown | bounded patterns and orchestrator tests | Verified | physical check |
| CON-006 | Settings local only | SharedPreferences plus authenticated local Pi persistence/synchronization; no cloud sync | Verified in simulation | physical persistence/reboot |
| CON-007 | Preserve Stitch sources | no Stitch files edited/deleted during integration | Verified | repeat file inventory at handoff |
| BR-001 | Assistive aid, not replacement | safety copy in Home/Mobile/About and tests | Verified | preserve |
| BR-002 | Trace requirements/architecture/decisions | current living docs and ADRs | Verified | update after phone tests |
| BR-003 | Familiar-person ID remains future only | generic COCO detection only | Verified | preserve |
| BR-004 | No exact-distance claims | code/docs use relative visual terms only | Verified | preserve |
