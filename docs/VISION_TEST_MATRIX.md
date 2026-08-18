# Vision Test Matrix

Last updated: 2026-08-18

## Test Levels

| Level | Meaning |
|---|---|
| L1 | Static verified (analyze + compile) |
| L2 | Automated / integration verified (flutter test) |
| L3 | Physical device verified |

## Automated Test Files

| File | Tests | Status |
|---|---|---|
| `test/domain/intent_resolver_test.dart` | ~62 | L2 PASS |
| `test/app/voice_kernel_test.dart` | voice kernel unit tests | L2 PASS |
| `test/domain/accessible_text_player_test.dart` | reader state machine | L2 PASS |
| `test/domain/accessible_document_test.dart` | document model | L2 PASS |
| `test/domain/document_text_normalizer_test.dart` | OCR normalization | L2 PASS |
| `test/domain/domain_defaults_test.dart` | domain defaults | L2 PASS |
| `test/domain/multi_model_fusion_service_test.dart` | fusion service | L2 PASS |
| `test/domain/tts_echo_guard_test.dart` | echo guard | L2 PASS |
| `test/features/assistant/assistant_controller_test.dart` | session controller | L2 PASS |
| `test/features/assistant/assistant_screen_test.dart` | assistant screen | L2 PASS |
| `test/features/assistant/assistant_session_state_test.dart` | session state | L2 PASS |
| `test/features/feedback/feedback_controller_test.dart` | feedback controller | L2 PASS |
| `test/features/detection/*` | detection pipeline, stability, risk | L2 PASS |
| `test/features/camera/camera_pipeline_test.dart` | camera pipeline | L2 PASS |
| `test/features/inference/inference_test.dart` | inference | L2 PASS |
| `test/features/wearable/*` | wearable protocol, simulator | L2 PASS |
| `test/accessibility/accessibility_test.dart` | accessibility | L2 PASS |
| `test/app/app_smoke_test.dart` | smoke test | L2 PASS |
| `test/app/router_test.dart` | router | L2 PASS |
| `test/app/module4_ui_migration_test.dart` | UI migration | L2 PASS |
| `test/app/theme_tokens_test.dart` | theme | L2 PASS |

Total: 295 passed, 1 skipped, 0 failed

## Physical Device Test Matrix (Section 51)

| Test | Description | Level | Status |
|---|---|---|---|
| HOME-01 | `Vision battery level` | L1 | NOT TESTED |
| HOME-02 | `Vision what time is it` | L1 | NOT TESTED |
| HOME-03 | `Vision open settings` | L1 | NOT TESTED |
| HOME-04 | `Vision go home` | L1 | NOT TESTED |
| DET-01 | `Vision start mobile detection` | L1 | NOT TESTED |
| DET-02 | `Vision pause detection` | L1 | NOT TESTED |
| DET-03 | `Vision continue detection` | L1 | NOT TESTED |
| DET-04 | `Vision what's ahead` | L1 | NOT TESTED |
| DET-05 | `Vision stop detection` | L1 | NOT TESTED |
| DET-06 | Camera works during detection | L1 | NOT TESTED |
| DET-07 | Detection model works | L1 | NOT TESTED |
| DET-08 | Announcements work | L1 | NOT TESTED |
| DET-09 | No duplicate inference | L1 | NOT TESTED |
| BACK-01 | Start detection → Stop → Back (no delayed stop) | L1 | NOT TESTED |
| BACK-02 | No ghost speech after back | L1 | NOT TESTED |
| BACK-03 | No stale recognition after back | L1 | NOT TESTED |
| SCAN-01 | `Vision open scanner` → 30s → 0 auto captures | L1 | NOT TESTED |
| SCAN-02 | `Vision scan document` → exactly 1 scan | L1 | NOT TESTED |
| SCAN-03 | No repeated automatic scan | L1 | NOT TESTED |
| BTN-01 | Pause button works | L1 | NOT TESTED |
| BTN-02 | Resume button works | L1 | NOT TESTED |
| BTN-03 | Slow button works | L1 | NOT TESTED |
| BTN-04 | Fast button works | L1 | NOT TESTED |
| BTN-05 | Stop button works | L1 | NOT TESTED |
| BTN-06 | Repeat button works | L1 | NOT TESTED |
| BTN-07 | Next button works | L1 | NOT TESTED |
| BTN-08 | Previous button works | L1 | NOT TESTED |
| PAUSE-01 | Pause sentence 3 → wait → resume → resumes at 3 | L1 | NOT TESTED |
| PAUSE-02 | Never jumps to last sentence | L1 | NOT TESTED |
| CONF-01 | Trigger confirmation → say cancel → cleared | L1 | NOT TESTED |
| CONF-02 | No Invalid command after cancel | L1 | NOT TESTED |
| CONF-03 | `no` cancels | L1 | NOT TESTED |
| CONF-04 | `never mind` cancels | L1 | NOT TESTED |
| CONF-05 | `yes` confirms and executes once | L1 | NOT TESTED |
| CONF-06 | `confirm` confirms and executes once | L1 | NOT TESTED |
| COMP-01 | Final sentence → readerStatus=completed | L1 | NOT TESTED |
| COMP-02 | No automatic Scan Again | L1 | NOT TESTED |
| ECHO-01 | Document with "Vision" → 0 self wake | L1 | NOT TESTED |
| ECHO-02 | Document with "stop detection" → 0 navigation | L1 | NOT TESTED |
| ECHO-03 | Document with "pause" → 0 pause | L1 | NOT TESTED |
| BARGE-01 | While speaking → "Vision" → TTS stops | L1 | NOT TESTED |
| BARGE-02 | After barge-in → "repeat" → correct sentence | L1 | NOT TESTED |
| STAB-01 | 20+ screen cycles → no degradation | L1 | NOT TESTED |
| STAB-02 | No progressive microphone leak | L1 | NOT TESTED |
| STAB-03 | No progressive TTS leak | L1 | NOT TESTED |
| STAB-04 | No progressive camera leak | L1 | NOT TESTED |

## Regression Tests Needed (Section 53)

| Test ID | Description | File | Status |
|---|---|---|---|
| REG-01 | Session invalidation | — | NOT WRITTEN |
| REG-02 | Context invalidation | — | NOT WRITTEN |
| REG-03 | TTL expiry | — | NOT WRITTEN |
| REG-04 | Deduplication | — | NOT WRITTEN |
| REG-05 | Circuit breaker | — | NOT WRITTEN |
| REG-06 | Partial result protection | — | NOT WRITTEN |
| REG-07 | Self-TTS protection | — | NOT WRITTEN |
| REG-08 | Unknown speech silence | — | NOT WRITTEN |
| REG-09 | Confirmation cancel | — | NOT WRITTEN |
| REG-10 | Confirmation confirm | — | NOT WRITTEN |
| REG-11 | Confirmation stale response | — | NOT WRITTEN |
| REG-12 | Scanner explicit scan | — | NOT WRITTEN |
| REG-13 | Scan request consumption | — | NOT WRITTEN |
| REG-14 | Scanner does not auto-scan on build | — | NOT WRITTEN |
| REG-15 | OCR success does not rescan | — | NOT WRITTEN |
| REG-16 | Reader completion does not rescan | — | NOT WRITTEN |
| REG-17 | Pause freezes reader | voice_kernel_test.dart | EXISTING |
| REG-18 | Resume uses paused sentence | accessible_text_player_test.dart | EXISTING |
| REG-19 | Stale TTS callback ignored | — | NOT WRITTEN |
| REG-20 | Speed change preserves sentence | — | NOT WRITTEN |
| REG-21 | Stop preserves document | — | NOT WRITTEN |
| REG-22 | UI and voice share reader | — | NOT WRITTEN |
| REG-23 | Detection voice uses existing controller | — | NOT WRITTEN |
| REG-24 | Detection start idempotency | — | NOT WRITTEN |
| REG-25 | Detection stop idempotency | — | NOT WRITTEN |
| REG-26 | Route transitions | — | NOT WRITTEN |
| REG-27 | App lifecycle | — | NOT WRITTEN |
