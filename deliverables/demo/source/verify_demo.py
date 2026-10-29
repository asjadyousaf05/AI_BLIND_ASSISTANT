"""Verify the exported video, caption timing and automatic hover borders."""

import hashlib
import json
import runpy
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
model = runpy.run_path(str(ROOT / "source" / "render_demo.py"))
video = ROOT / "AI_Blind_Assistant_Demo.mp4"
probe = json.loads(
    subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_streams",
            "-show_format",
            "-of",
            "json",
            str(video),
        ],
        capture_output=True,
        check=True,
    ).stdout
)
v = next(s for s in probe["streams"] if s["codec_type"] == "video")
a = next(s for s in probe["streams"] if s["codec_type"] == "audio")
duration = float(probe["format"]["duration"])
assert 169.9 <= duration <= 170.1 and duration <= 180
assert (v["width"], v["height"], v["codec_name"], v["r_frame_rate"]) == (
    1920,
    1080,
    "h264",
    "24/1",
)
assert a["codec_name"] == "aac" and a["sample_rate"] == "48000"
decoded = subprocess.run(
    ["ffmpeg", "-v", "error", "-i", str(video), "-f", "null", "-"],
    capture_output=True,
    check=True,
)
assert not decoded.stderr
cues = json.loads((ROOT / "build" / "captions.json").read_text())
last_end = 0
draw = ImageDraw.Draw(Image.new("RGB", (1920, 1080)))
for cue in cues:
    assert last_end <= cue["start"] < cue["end"] <= duration
    last_end = cue["end"]
    # Check the same fixed caption panel at export size; text must fit two lines.
    height = model["wrapped"](
        draw, cue["text"], (104, 920), 30, "white", 1158, spacing=9
    )
    assert height <= 78
target_count = 0
for i, scene in enumerate(model["STORY"]):
    for shot in scene["screens"]:
        with Image.open(
            ROOT / "source" / "captures" / (shot["capture"] + ".png")
        ) as im:
            assert im.size == (720, 1600)
        for at, label in shot.get("targets", []):
            region = model["target"](shot["capture"], label)
            assert region and region["clickable"], (shot["capture"], label)
            x1, y1, x2, y2 = region["bounds"]
            point = ((x1 + x2) / 2, (y1 + y2) / 2)
            assert model["hovered"](shot["capture"], point) == region
            picture = model["frame"](model["STARTS"][i] + at + 0.05, cues)
            x = round(model["PX"] + x1 * model["PW"] / 720 - 2)
            y = round(model["PY"] + point[1] * model["PH"] / 1600)
            assert any(
                picture.getpixel((x + dx, y)) == (69, 218, 209) for dx in range(-2, 4)
            ), label
            target_count += 1
report = {
    "duration_seconds": duration,
    "resolution": "1920x1080",
    "fps": "24",
    "video_codec": v["codec_name"],
    "audio_codec": a["codec_name"],
    "audio_sample_rate": int(a["sample_rate"]),
    "bytes": video.stat().st_size,
    "sha256": hashlib.sha256(video.read_bytes()).hexdigest(),
    "full_decode": "PASS, no error output",
    "caption_cues": len(cues),
    "caption_timing_and_layout": "PASS",
    "automatic_hover_borders": f"PASS, {target_count} targets hit-tested and pixel-checked",
}
(ROOT / "VERIFICATION.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
