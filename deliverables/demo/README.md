# AI Blind Assistant demo video

[Play the MP4](AI_Blind_Assistant_Demo.mp4) ·
[Subtitles](AI_Blind_Assistant_Demo.srt) ·
[Narration and chapters](NARRATION.md) ·
[Verification results](VERIFICATION.json)

Completed 15 October 2026. **2:50**, 1920 × 1080, 24 fps, H.264 video and
48 kHz AAC English narration. File size: 6,764,129 bytes (about 6.8 MB).
Captions are visible in the video; the SRT contains 37 timed cues.

The video combines genuine native Flutter app captures, an actual recorded
on-device OCR transition, editorial explanations and an animated cursor.
The renderer automatically hit-tests the cursor against captured accessible
control rectangles. Only the control under the cursor receives the turquoise
border and “ACTIVE CONTROL” label. Thirty targets passed both hit-testing and
pixel checks. These are recording overlays; production app behavior is unchanged.

| Time | User journey |
|---|---|
| 00:00 | Purpose and main capabilities |
| 00:10 | Home and feature entry points |
| 00:22 | Local feedback and sensitivity settings |
| 00:42 | Start Mobile Mode; synthetic camera reaches Detecting |
| 01:06 | Open Scanner, frame synthetic print and perform local OCR |
| 01:25 | Reader controls, speeds, recognized lines and Ask AI entry |
| 01:47 | Local command interface and actual typed battery-status result |
| 02:05 | Optional Raspberry Pi connection workflow |
| 02:21 | Optional laptop/Smart AI setup |
| 02:38 | End of journey and assistive-aid boundary |

All capture actions targeted `emulator-5554`, the dedicated API 36 ARM64 AVD
`AI_Blind_Assistant_Release_API36`. No physical phone was recorded or modified;
its existing pairing was preserved. No provider request, pairing-code entry,
credential rotation, production source change, APK build or installation was
needed. Existing unrelated workspace edits remain intact.

Camera footage and print are synthetic emulator material. The synthetic page
was actually recognized into six reading lines; OCR imperfections remain visible.
The battery command actually returned 100 percent through phone-local routing.
The added narrator is the local macOS Samantha synthetic voice, not microphone
audio from a person. No camera, document or narration was uploaded.

The emulator returned `null` for `tts_default_synth` and the reader reported
speech-output failure. The reader segment explicitly labels this limitation;
the voice-over is not evidence of Android speaker output or physical speech
recognition. A narrow-layout defect in the document header was also observed
and recorded as ISSUE-073. Wearable and Smart AI segments demonstrate interfaces,
not a connected Pi or a generated laptop reply. Existing physical TalkBack,
audio, camera accuracy, Pi and speech acceptance gates remain open.

To reproduce with the saved captures on macOS, install Pillow and FFmpeg and
use the built-in `say` command:

```sh
python3 deliverables/demo/source/render_demo.py
python3 deliverables/demo/source/verify_demo.py
```

The editable timeline is [source/storyboard.json](source/storyboard.json).
`source/capture_demo.py` captures only the named emulator; it does not access
physical devices. Raw OCR footage is retained at
`source/captures/10_reader.mp4`. Generated speech, extraction frames and review
images live in ignored `build/`. The full export decoded without errors;
duration, codec, captions and border checks are recorded in `VERIFICATION.json`.

SHA-256:
`4c0458df0d57c12c24b2092f8c2650f10e1eadf8fdb81315da3577557a4de62a`

No application test suite or Android build was rerun for this multimedia-only
task. Previous application verification retains its original date and scope.
