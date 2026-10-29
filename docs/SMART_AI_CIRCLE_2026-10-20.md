# Smart AI bilingual circle verification

Date: 2026-10-20. Module 71 / ADR-072. Final software verified; device follow-up in progress.

## Result and owner clarification

The initial 1.4.13 circle passed 591 Flutter tests/build/install, but the owner
reported missing vibration, English speech transcribed into Urdu, and goodbye
said without a button hold. That physical check did not pass. The owner then
explicitly authorized local Vision AI to stay available on Smart AI while cloud
questions remain button-initiated. The current follow-up supersedes recorded-only
goodbye and screen-wide wake pause; no new background or cloud wake listener.

## Current behavior

Hold the large circle one second, wait for its 180 ms pulse, speak and lift your
finger to send once. Tap a speaking answer to pause, tap again to resume at its
last reported word, or hold again to interrupt and record a new question. Setup
release, pointer cancel and backgrounding discard clips; the existing 30-second
cap still submits once. No worker, conversion, new package or automatic retry.

Auto leaves Whisper's language unspecified and chooses reply language from the
latest transcript. Automatic detection can mistake short English speech for Urdu;
a response prompt cannot repair an already wrong transcript. Accessible English/
Urdu choices send en/ur on the same STT request and preserve that choice through
the reply. No extra inference call. Choices last for the in-memory app session.
The exact original base prompt stays verbatim first, followed by the language
instruction and bounded history. The active Groq Whisper large v3 / GPT-OSS 20B
models, keys, consent, deadlines, text/file limits and no-tools policy remain.
Existing installed offline English/Urdu voices pronounce the answer and restore
en-US on completion, pause, cancel and exit. Roman Urdu/general language detection
and guaranteed automatic language accuracy are not claimed.

Local Vision AI listens on this foreground screen between button recordings.
An isolated exact final goodbye Smart AI event needs neither a hold nor a wake
prefix and makes no API request. The native local decoder releases its microphone
during button capture and resumes afterwards. A narrow kernel button-mode guard
uses app controls and blocks unmatched speech from invoking legacy Smart AI.
Speaker echo, incidental mentions and unknown-token goodbye phrases cannot exit.
Cancel the Smart AI turn, restore/release audio and the saved global hands-free
preference, then navigate through the existing Home route. The global preference
is never rewritten. Typed/recorded goodbye remain deterministic alternatives;
a recorded goodbye uses normal STT and deletes its clip before interpretation.

The bounded listening pulse uses the already installed vibrator plugin with default
amplitude, suitable for this phone's lack of amplitude control. It is independent
of obstacle-alert vibration preferences. Test listening vibration needs no capture
or API. Clear state-specific circle hints, a Speak to Smart AI heading, named
Button controls, Hear how to use Smart AI, Speech language choices, local-listener
status and Back to Home and Vision AI provide guidance and alternatives. The
spoken guide stays local and uses the same echo protection and pausable playback.

## Architecture and preserved workspace

Feature-first layers and Riverpod injection remain. Domain interfaces express
local audio/capture handover and the optional foreground recognition capability.
Infrastructure implements fixed HTTPS, existing native recognition bridge,
localized speech and the bounded vibrator cue. Widgets have callbacks/controller
operations only. Existing centralized Home/Assistant routes remain.

The 559-file pre-request snapshot includes extensive existing dirty work. The
initial candidate preserved all Vision AI/native files; the owner clarification
now justifies a narrow shared kernel flag, Dart recognition bridge capability and
native handler extension plus an isolated grammar helper. Base Vision AI wake/
command grammar, resolver/authorization, shared TTS implementation, detection,
camera/models, backend/Pi, dependencies/source version/signing remain unchanged.
No revert/commit/push, uninstall/data clear, credential readback or pairing rotation.
All 31 Stitch references must remain byte-identical; final audit below.

## Verification history and final checks

Initial focused run 84 passed; gesture/locale/screen run 22 passed. Initial circle
recognizer cascade compile/style findings and deprecated/misplaced/unnecessary
test imports were corrected without removing assertions. 591 full Flutter cases,
clean analysis (2.5 s), 17-file zero-change formatting, 1.4.13 ARM64 debug/release
14.5/23.7 s and matching-signer code 4053 installation passed. Installed bytes were
verified; cold launch Status ok/COLD, TotalTime 1114 ms, WaitTime 1186 ms, first
install time retained and DEBUGGABLE absent. Owner rejection above takes precedence
over interpreting these software checks as physical acceptance.

Follow-up compilation/style findings were corrected. One intermediate full run
had a real Pi simulator 30-second timeout and a stalled Home widget test; the
stalled runner was terminated, not counted as passing. Home teardown awaited
broadcast unsubscribe in a widget fake clock. It now invalidates activity first,
unsubscribes without blocking and still awaits microphone/speech restoration
before Home; seven screen tests then passed unchanged. A full 604-case rerun
including all real simulator cases passed. Final review added waiting for an
in-flight local microphone restart before exit and an empty-grammar guard. A final speech-ownership check also distinguishes
natural completion from external local-control interruption: an interrupted
reply yields with a local replay option instead of queueing another chunk over
Vision AI speech. Circle pause/resume still waits and resumes locally.

Final source checks: **606 Flutter tests pass**, including the real Python Pi
simulator, **35 more than the 571-case baseline**; no cases removed/skipped.
Analysis has no issues (**2.6 s**). Formatting checks **24 Dart files**, zero
changes. Native app unit tests: **17 pass, 0 failures/errors/skips**, including
four new Smart AI grammar cases; Gradle task succeeds in **7 s**. This is the
app task, not an aggregate plugin/lint pass. Legacy plugin Kotlin/Gradle migration
warnings remain. Final Android packaging/install results are recorded below.

Coverage includes both latest-turn language directions, explicit en/ur/Auto
multipart behavior and frozen per-recording selection, exact base prompt,
one-second gesture timing, release/cancel/setup cleanup, haptic cue count,
capped recording ownership, local pause/resume/interrupt, word progress, local
spoken guidance/no history or API, semantic activation, narrow 2x UI, no-hold
local goodbye/no API, recording suppression, speaker-echo rejection/recovery,
foreground bridge gating, no unprompted legacy conversation, microphone yield/
resume and awaiting its in-flight restart before exit, external speech interruption yielding without another queued chunk, and
audio-before-Home.

## Physical acceptance

Owner confirmed Urdu speech and replay on prior 1.4.12. It does not establish
acceptance of new circle/English detection/haptic/foreground-exit behavior.
After 1.4.14 installation, check Test listening vibration; choose English for
one English question, Urdu for one Urdu question, then pause/resume and say
goodbye Smart AI without holding after the answer. Auto remains best-effort;
measure it separately. Full TalkBack/accent/noise/local wake/acoustic echo and
end-to-end latency remain independent gates. No AgentRouter completion/paid
probe or agent-triggered Groq conversation is required for software checks.

## Primary sources

Groq's [speech-to-text guide](https://console.groq.com/docs/speech-to-text) and
[API reference](https://console.groq.com/docs/api-reference) document optional
ISO-639-1 input-language hints. Explicit en/ur uses this existing parameter;
no second transcription, new provider or translation endpoint is introduced.
Installed Flutter/plugin source and device vibrator capabilities were inspected
for the existing speech progress, native microphone ownership and cue behavior.
