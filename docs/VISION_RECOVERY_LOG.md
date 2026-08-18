# Vision Recovery Log

Last updated: 2026-08-18

## Checkpoint Table

| # | Phase | Commit | Branch | Files Changed | Problem Addressed | Tests Run | Physical Device | Known-Good | Known Remaining Bugs | Rollback Commit |
|---|---|---|---|---|---|---|---|---|---|---|
| 0 | Pre-stabilization baseline | `5949ea8` | vision-assistant-stabilization | 58 files (initial V3 creation) | Preserve pre-stabilization state | flutter test: pass | App installed on TECNO BG6 | V3 kernel, intent resolver, command executor, authorizer, dedup, circuit breaker | 10 uncommitted fix files pending | `b21dd41` |
| 1 | Phase A checkpoint | PENDING | vision-assistant-stabilization | 10 files (bug fixes) + 5 doc files | TTS race condition, confirmation cancel, return type, import, vibration auto-enable, test fixes | 295 pass, 0 fail | Installed | All 295 tests pass, 0 analyze issues | None confirmed via tests | `5949ea8` |

## Detailed Recovery Notes

### Checkpoint 0: `5949ea8`

Created the VisionVoiceKernelV3 architecture from scratch:
- `lib/app/voice_kernel/` — 7 files (kernel, executor, authorizer, dedup, circuit breaker, diagnostics, providers)
- `lib/domain/services/` — intelligent_intent_resolver, semantic_lexicon, asr_correction_lexicon, voice_action_registry
- `lib/domain/enums/` — voice_intent, voice_feature_context, voice_rejection_reason, voice_runtime_state
- `lib/domain/entities/` — voice_command, voice_command_result, voice_action_definition, voice_recognition_event
- Tests: voice_kernel_test.dart, intent_resolver_test.dart

### Checkpoint 1: PENDING COMMIT

Bug fixes from prior model session:
1. Fixed `vision_voice_kernel_v3.dart` return type (`false` → `null` for `Future<String?>`)
2. Added missing `assistant_session_controller.dart` import in `command_executor.dart`
3. Auto-enable vibration when `_setFeedbackMode` selects vibration/both
4. Updated test assertions to avoid false positive intent matches
5. Removed stale `confirmAction()` call in feedback test
6. Prior session also fixed TTS race condition in AccessibleTextPlayer and confirmation cancellation flow
