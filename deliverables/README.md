# AI Blind Assistant deliverables

## GitHub APK delivery — 29 October 2026

[Download the updated 1.4.19 ARM64 APK](https://github.com/asjadyousaf05/AI_BLIND_ASSISTANT/releases/download/v1.4.19/AI-Blind-Assistant-1.4.19-arm64.apk) from the
[v1.4.19 release](https://github.com/asjadyousaf05/AI_BLIND_ASSISTANT/releases/tag/v1.4.19); its SHA-256 checksum is attached to the same release.
Release-mode APK, Android code 4059, 126,355,367 bytes; matches the existing
development signer used for the previous phone update. Source is on
`feature/offline-assistant-audio`. [Build and verification](../docs/GITHUB_DELIVERY_2026-10-29.md).
APK binaries are release assets rather than repository files. Previous local
APKs are preserved; no new physical acceptance is claimed.

## Complete project guide for GPT and viva — 22 October 2026

- [AI_Blind_Assistant_Complete_GPT_Guide.md](AI_Blind_Assistant_Complete_GPT_Guide.md) — self-contained GPT upload with a ready tutor prompt.
- [AI_Blind_Assistant_Complete_GPT_Guide.docx](AI_Blind_Assistant_Complete_GPT_Guide.docx) — readable Word copy with headings and tables.

35 sections cover the actual stack, models, camera/feedback flows, Pi networking,
voice/OCR/Smart AI, privacy, evidence, setup, demos and 32 viva answers. Completed
custom fine-tuning is not claimed; a real proposed workflow and evidence checklist
are included. Use this guide over the older presentation Word export for current
claims. [Verification record](../docs/GPT_GUIDE_VERIFICATION_2026-10-22.md).

## Vision AI demo reliability APK — 21 October 2026

[AI-Blind-Assistant-1.4.18-vision-ai-reliability.apk](AI-Blind-Assistant-1.4.18-vision-ai-reliability.apk)
is the verified matching-phone-signer ARM64 release-mode update, 1.4.18/code 4058.
It restores stranded listening, adds bounded recovery and actual-readiness cue,
exposes explicit restart and handles incomplete/negated commands conservatively.
673 Flutter/25 native app cases, clean analysis/format, both builds, 16 KiB
alignment and installed-byte checks pass. Installed in place on Pixel; owner
confirms repeated commands and cue both work. Previous APKs remain preserved.
[Exact evidence, SHA-256 and tomorrow's rehearsal](../docs/VISION_AI_RELIABILITY_2026-10-21.md).

## Fresh-phone Smart AI circle APK — 21 October 2026

[AI-Blind-Assistant-1.4.17-smart-ai-circle-setup.apk](AI-Blind-Assistant-1.4.17-smart-ai-circle-setup.apk)
keeps the Smart AI circle visible before personal setup, with disabled question
capture, a labelled setup action and local command/help/cue support. Existing
configured and saved Gemini/laptop modes remain. No shared keys or provider probe.
652 Flutter cases/clean analysis/format and debug build pass. [Exact release/install/hash evidence](../docs/SMART_AI_FRESH_PHONE_2026-10-21.md).

Final 1.4.17/code 4057 debug/release builds pass (9.8/24.2 s). Matching-signer/
alignment/non-debuggable/package/delivery checks pass; installed Pixel bytes match
and its first-install time is retained. Cold MainActivity launch succeeds in
217 ms / 220 ms wait; later lock does not invalidate that recorded launch. The
owner confirms the large circle and Set up Smart AI button now appear. UI mismatch
resolved; next action is personal Groq key/consent setup on Pixel. No paid test.

## Vision AI command APK — 21 October 2026

[AI-Blind-Assistant-1.4.16-vision-ai-commands.apk](AI-Blind-Assistant-1.4.16-vision-ai-commands.apk)
is the matching-phone-signer ARM64 release-mode update, version 1.4.16/code 4056.
It adds truthful spoken Pi/Mobile progress/outcomes, visible-screen/polite local
commands and direct Smart AI idle/paused navigation. 646 Flutter/22 native app
cases, clean analysis/format, both builds, signature/alignment/non-debuggable/
packaged-change/delivery-byte checks pass. No embedded keys or provider probe.
[Exact hash, installation, inventory and physical check](../docs/VISION_AI_COMMANDS_2026-10-21.md).

Installed 1.4.16 in place; pulled installed bytes match delivery and the original
first-install timestamp is retained. Process alive, zero current-process fatal
markers. Post-install launch is UNKNOWN/3073 ms behind the lock screen; physical
new-command/foreground acceptance awaits the owner's reply. No provider call.

The owner subsequently selected a Pixel 9 Pro. This same APK installed there
successfully as a fresh application; installed bytes/version/foreground/process
checks pass. Personal Smart AI setup and Pi pairing are per device. No provider
request or source rebuild was needed; physical voice/cue acceptance remains open.

## Smart AI listening-cue APK — 21 October 2026

[AI-Blind-Assistant-1.4.15-smart-ai-ready-cue.apk](AI-Blind-Assistant-1.4.15-smart-ai-ready-cue.apk)
is the matching-phone-signer ARM64 release-mode update, version 1.4.15/code 4055.
It adds a short local readiness chime and accessibility vibration after the Smart
AI microphone starts, plus updated guidance and a local cue test. No embedded
keys, new permission or Vision AI change. Signature/alignment/non-debuggable
metadata/delivery bytes, 615 Flutter/21 native cases and both builds pass.
Owner requested later device testing; this APK was not installed in this pass.
[Exact hashes, commands and physical check](../docs/SMART_AI_READY_CUE_2026-10-21.md).

## Smart AI bilingual circle — 20 October 2026

[AI-Blind-Assistant-1.4.13-smart-ai-circle.apk](AI-Blind-Assistant-1.4.13-smart-ai-circle.apk)
is the current matching-phone-signer ARM64 release-mode update installed on
TECNO BG6, code 4053. It adds per-turn English/Urdu, hold/vibrate/release circle,
local pause/resume/interrupt and recorded goodbye → Home. Existing keys/data
and Vision AI/native/backend/Pi sources are preserved. 591 Flutter tests,
analysis/format/build/signature/alignment/installed bytes/non-debuggable flags/
cold launch pass; new physical interaction acceptance is pending.
[Exact results](../docs/SMART_AI_CIRCLE_2026-10-20.md).

## Smart AI cloud audio build — 20 October 2026

[AI-Blind-Assistant-1.4.12-smart-ai.apk](AI-Blind-Assistant-1.4.12-smart-ai.apk) is
the matching-phone-signer ARM64 release-mode build installed on TECNO BG6.
It adds the owner's isolated Smart AI pipeline, approved Groq speech/answers,
personal-key setup, private-cache/microphone-handover repair and Urdu voice/replay; no key is
embedded. Vision AI/native recognizers/backend/Pi sources are preserved.
Installed bytes/signature/non-debuggable flags/retained data timestamp/launch
are verified. Urdu recognition/answers/speech/replay are owner-confirmed. Local capture/cancel,
background/resume and settings reentry pass; broader latency/noise/TalkBack gates
remain separate. [Exact evidence](../docs/SMART_AI_CLOUD_AUDIO_2026-10-19.md).

## Phone-hotspot build — 19 October 2026

[AI-Blind-Assistant-1.4.7-hotspot.apk](AI-Blind-Assistant-1.4.7-hotspot.apk) is the
ARM64 release-mode build installed on the authorized TECNO BG6. It uses that
phone's existing development signer for an in-place update; the independent
project-signed release remains in the Flutter build output. No source signing
configuration changed. [Verification](../docs/HOTSPOT_AND_GEMINI_VERIFICATION_2026-10-19.md)
records exact hashes, tests, hotspot/Pi/audio evidence and remaining power/API/
physical acceptance gates. This build includes opt-in personal Gemini; no key
or supplied network/login password is embedded.

## Demo video — 15 October 2026

[AI Blind Assistant — 2:50 demo](demo/AI_Blind_Assistant_Demo.mp4), with English
narration, visible captions and automatic coloured cursor-hover borders.
The native app walkthrough covers Home, local settings, Mobile Mode, actual
synthetic OCR, reader controls, a successful local battery command and optional
Pi/laptop setup. [Delivery notes](demo/README.md),
[subtitles](demo/AI_Blind_Assistant_Demo.srt) and
[verification](demo/VERIFICATION.json) include the emulator speech limitation
and unchanged physical acceptance gates.

## Presentation brief — 12 October 2026

[AI_Blind_Assistant_Presentation_Brief.docx](AI_Blind_Assistant_Presentation_Brief.docx)
is the editable Word brief for presentation preparation. Its
[Markdown source](../docs/PROJECT_PRESENTATION_BRIEF.md) covers functionality,
scope, architecture, workflows, household YOLOv8n integration,
verification limits, a 22-slide outline, demo and viva answers. It does not
promote software simulations to physical acceptance or invent training metrics.
The Markdown brief has a 22 October correction withdrawing unsupported completed
fine-tuning wording. The original Word file is historical and retains older copy;
use the complete current guide above for study/submission preparation.

## Existing APK

`AI-Blind-Assistant.apk` is the locally signed ARM64-v8a release.

- Android 7.0 or newer (minimum API 24, target API 36)
- Package: `com.example.ai_blind_assistant`
- Version: `1.3.3` (ARM64 split build `2011`)
- Size: 97,185,174 bytes
- Core Mobile/Wearable assistance remains local and independent
- Typed app-control commands execute entirely on the phone without a backend or
  AI provider
- Foreground hands-free app controls listen for “Hey Vision AI” through the
  bundled Vosk English model and deterministic phone-local routing; no
  installed speech service, internet, or laptop is required
- The screen remains awake while the app is foregrounded. Listening pauses
  when the app is backgrounded or the phone is locked
- General conversation uses optional Gemini with automatic local Ollama
  fallback on the paired laptop

Verify and install on an authorized ARM64 Android phone:

```bash
cd /Users/mm/AI_BLIND_ASSISTANT/deliverables
shasum -a 256 -c AI-Blind-Assistant.apk.sha256
adb devices -l
adb -s <android-device-id> install -r AI-Blind-Assistant.apk
```

Grant Camera only for Mobile Mode and Microphone once for hands-free voice.
The laptop is optional and is needed only for general conversation. If paired,
it must be on a trusted private LAN. This assistive aid does
not replace a cane, guide dog, mobility training, human assistance, situational
awareness, or personal judgment.
