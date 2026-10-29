"""Render a 170-second narrated walkthrough from captured native app screens.

Uses local macOS speech, Pillow and FFmpeg. No network calls or cloud assets.
Hover highlighting is computed by hit-testing the animated cursor against
captured control rectangles, not by drawing a border on every field.
"""

import argparse
import bisect
import json
import subprocess
import wave
from functools import lru_cache
from itertools import pairwise
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "source"
CAPTURES = SOURCE / "captures"
BUILD = ROOT / "build"
W, H, FPS = 1920, 1080, 24
PX, PY, PW, PH = 1390, 62, 424, 942
ACCENT = "#45DAD1"
INK = "#F4F7FC"
MUTED = "#A9B9CF"
BG = "#0A1220"
STORY = json.loads((SOURCE / "storyboard.json").read_text())
STARTS = [0]
for _scene in STORY:
    STARTS.append(STARTS[-1] + _scene["duration"])


def run(*cmd):
    return subprocess.run(list(map(str, cmd)), check=True, capture_output=True)


def font(size, bold=False):
    name = "Arial Bold.ttf" if bold else "Arial.ttf"
    return ImageFont.truetype("/System/Library/Fonts/Supplemental/" + name, size)


def srt_time(t):
    ms = round(t * 1000)
    return (
        f"{ms // 3600000:02}:{ms // 60000 % 60:02}:{ms // 1000 % 60:02},{ms % 1000:03}"
    )


def make_audio():
    BUILD.mkdir(exist_ok=True)
    cues = []
    track = bytearray()
    sample_rate = 48000
    for i, scene in enumerate(STORY):
        pieces = []
        for j, sentence in enumerate(scene["narration"]):
            aiff = BUILD / f"voice_{i:02}_{j:02}.aiff"
            wav = aiff.with_suffix(".wav")
            run("say", "-v", "Samantha", "-r", "172", "-o", aiff, sentence)
            run(
                "ffmpeg",
                "-y",
                "-v",
                "error",
                "-i",
                aiff,
                "-ar",
                sample_rate,
                "-ac",
                "1",
                "-c:a",
                "pcm_s16le",
                wav,
            )
            with wave.open(str(wav)) as f:
                data = f.readframes(f.getnframes())
            pieces.append((sentence, data))
        speech_length = sum(len(p[1]) for p in pieces) / 2 / sample_rate
        gap = 0.24
        available = scene["duration"] - 0.65 - gap * (len(pieces) - 1)
        speed = max(1, speech_length / available)
        segment = bytearray(b"\0" * round(0.35 * sample_rate) * 2)
        for j, (sentence, data) in enumerate(pieces):
            if speed > 1:
                wav = BUILD / f"voice_{i:02}_{j:02}.wav"
                data = run(
                    "ffmpeg",
                    "-v",
                    "error",
                    "-i",
                    wav,
                    "-af",
                    f"atempo={speed:.6f}",
                    "-f",
                    "s16le",
                    "-",
                ).stdout
            begin = STARTS[i] + len(segment) / 2 / sample_rate
            duration = len(data) / 2 / sample_rate
            words = sentence.split()
            chunks = []
            chunk = []
            for word in words:
                if len(" ".join(chunk + [word])) > 100 and chunk:
                    chunks.append(" ".join(chunk))
                    chunk = []
                chunk.append(word)
            if chunk:
                chunks.append(" ".join(chunk))
            at = begin
            for chunk in chunks:
                end = at + duration * len(chunk.split()) / len(words)
                cues.append({"start": at, "end": end, "text": chunk})
                at = end
            segment.extend(data)
            if j != len(pieces) - 1:
                segment.extend(b"\0" * round(gap * sample_rate) * 2)
        target = scene["duration"] * sample_rate * 2
        assert len(segment) <= target, (i, len(segment), target)
        segment.extend(b"\0" * (target - len(segment)))
        track.extend(segment)
        print(f"Narration {i + 1}/{len(STORY)} ready", flush=True)
    with wave.open(str(BUILD / "narration.wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(sample_rate)
        f.writeframes(track)
    (BUILD / "captions.json").write_text(json.dumps(cues, indent=2))
    (ROOT / "AI_Blind_Assistant_Demo.srt").write_text(
        "\n\n".join(
            f"{i + 1}\n{srt_time(c['start'])} --> {srt_time(c['end'])}\n{c['text']}"
            for i, c in enumerate(cues)
        )
        + "\n"
    )


@lru_cache(maxsize=32)
def screen(name):
    im = Image.open(CAPTURES / f"{name}.png").convert("RGB")
    return im.resize((PW, PH), Image.Resampling.LANCZOS)


@lru_cache(maxsize=32)
def regions(name):
    return json.loads((CAPTURES / f"{name}.json").read_text())


def target(name, label):
    matches = [
        r
        for r in regions(name)
        if label.lower() in r["label"].lower() and r["clickable"]
    ]
    if not matches:
        matches = [
            r
            for r in regions(name)
            if label.lower() in r["label"].lower() and r["bounds"] != [0, 0, 720, 1600]
        ]
    return (
        min(
            matches,
            key=lambda r: (
                (r["bounds"][2] - r["bounds"][0]) * (r["bounds"][3] - r["bounds"][1])
            ),
        )
        if matches
        else None
    )


def cursor_at(shot, elapsed):
    points = []
    for t, label in shot.get("targets", []):
        r = target(shot["capture"], label)
        if r:
            x1, y1, x2, y2 = r["bounds"]
            points.append((t, (x1 + x2) / 2, (y1 + y2) / 2))
    if not points or elapsed < points[0][0] - 0.5:
        return None
    if elapsed <= points[0][0]:
        return points[0][1:]
    for a, b in pairwise(points):
        if elapsed < b[0]:
            u = max(0, min(1, (elapsed - (b[0] - 0.8)) / 0.8))
            u = u * u * (3 - 2 * u)
            return a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u
    return points[-1][1:]


def hovered(name, point):
    x, y = point
    hits = [
        r
        for r in regions(name)
        if r["clickable"]
        and r["bounds"][0] <= x <= r["bounds"][2]
        and r["bounds"][1] <= y <= r["bounds"][3]
    ]
    return (
        min(
            hits,
            key=lambda r: (
                (r["bounds"][2] - r["bounds"][0]) * (r["bounds"][3] - r["bounds"][1])
            ),
        )
        if hits
        else None
    )


def wrapped(draw, text, xy, size, fill, width, bold=False, spacing=12):
    f = font(size, bold)
    lines = []
    for paragraph in text.split("\n"):
        line = ""
        for word in paragraph.split():
            candidate = (line + " " + word).strip()
            if draw.textlength(candidate, font=f) > width and line:
                lines.append(line)
                line = word
            else:
                line = candidate
        lines.append(line)
    draw.multiline_text(xy, "\n".join(lines), font=f, fill=fill, spacing=spacing)
    return len(lines) * (size + spacing)


@lru_cache(maxsize=10)
def background(i):
    scene = STORY[i]
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((1352, 22, 1852, 1042), radius=62, fill="#10243A")
    d.rounded_rectangle(
        (PX - 10, PY - 10, PX + PW + 10, PY + PH + 10), radius=35, fill="#E4E9EF"
    )
    d.text((90, 63), "VISION AI", font=font(26, True), fill=INK)
    d.rounded_rectangle((269, 60, 409, 95), radius=16, fill="#15332F")
    d.text((286, 66), "LOCAL FIRST", font=font(17, True), fill=ACCENT)
    d.text((90, 152), scene["eyebrow"], font=font(23, True), fill=ACCENT)
    h = wrapped(d, scene["title"], (86, 210), 80, INK, 1160, True, 13)
    y = 230 + h
    y += wrapped(d, scene["description"], (90, y), 32, MUTED, 1115, spacing=12) + 28
    for n, point in enumerate(scene["points"]):
        d.rounded_rectangle((90, y, 1280, y + 67), radius=14, fill="#142236")
        d.ellipse((110, y + 22, 132, y + 44), fill=ACCENT)
        d.text((153, y + 17), point, font=font(28), fill=INK)
        y += 80
    d.text((90, 820), scene["note"], font=font(22), fill=MUTED)
    d.rounded_rectangle((80, 874, 1290, 1014), radius=20, fill="#17273D")
    d.text((104, 886), "NARRATION", font=font(16, True), fill=ACCENT)
    d.line((90, 1041, 1280, 1041), fill="#29405A", width=4)
    d.text((90, 1051), f"{i + 1:02} / {len(STORY):02}", font=font(16), fill=MUTED)
    d.text((1020, 1051), "AI BLIND ASSISTANT", font=font(16, True), fill=MUTED)
    return im


def frame(t, cues):
    i = min(len(STORY) - 1, bisect.bisect_right(STARTS, t) - 1)
    scene = STORY[i]
    local = t - STARTS[i]
    shots = scene["screens"]
    shot = max((s for s in shots if s["at"] <= local), key=lambda s: s["at"])
    im = background(i).copy()
    phone = screen(shot["capture"])
    if shot.get("clip"):
        folder = BUILD / shot["clip"]
        files = sorted(folder.glob("*.jpg"))
        if files:
            k = min(len(files) - 1, int((local - shot["at"]) * 12))
            phone = Image.open(files[k]).convert("RGB")
    im.paste(phone, (PX, PY))
    d = ImageDraw.Draw(im)
    d.line((90, 1041, 90 + round(1190 * t / STARTS[-1]), 1041), fill=ACCENT, width=4)
    for c in cues:
        if c["start"] <= t < c["end"]:
            wrapped(d, c["text"], (104, 920), 30, INK, 1158, spacing=9)
            break
    point = cursor_at(shot, local)
    if point:
        r = hovered(shot["capture"], point)
        if r:
            a, b, c, e = r["bounds"]
            box = (
                PX + a * PW / 720,
                PY + b * PH / 1600,
                PX + c * PW / 720,
                PY + e * PH / 1600,
            )
            for pad, color, width in [(7, "#164F59", 7), (2, ACCENT, 4)]:
                d.rounded_rectangle(
                    (box[0] - pad, box[1] - pad, box[2] + pad, box[3] + pad),
                    radius=12,
                    outline=color,
                    width=width,
                )
            label_y = max(PY + 4, box[1] - 26)
            label_x = min(PX + PW - 133, box[0])
            d.rounded_rectangle(
                (label_x, label_y, label_x + 130, label_y + 24), radius=5, fill=ACCENT
            )
            d.text(
                (label_x + 10, label_y + 3),
                "ACTIVE CONTROL",
                font=font(13, True),
                fill=BG,
            )
        x, y = PX + point[0] * PW / 720, PY + point[1] * PH / 1600
        # Standard arrow pointer with a dark outline remains visible on light UI.
        poly = [
            (x, y),
            (x + 2, y + 35),
            (x + 11, y + 27),
            (x + 19, y + 43),
            (x + 27, y + 39),
            (x + 18, y + 24),
            (x + 31, y + 22),
        ]
        d.polygon(poly, fill="white", outline="#081321", width=3)
    # Short fade makes each editorial cut clear without obscuring the controls.
    fade = min(1.0, local / 0.22, (scene["duration"] - local) / 0.22)
    if fade < 1:
        im = Image.blend(Image.new("RGB", (W, H), BG), im, max(0, fade))
    return im


def render():
    for scene in STORY:
        for shot in scene["screens"]:
            if not shot.get("clip"):
                continue
            folder = BUILD / shot["clip"]
            folder.mkdir(parents=True, exist_ok=True)
            if not list(folder.glob("*.jpg")):
                run(
                    "ffmpeg",
                    "-y",
                    "-v",
                    "error",
                    "-i",
                    CAPTURES / (shot["capture"] + ".mp4"),
                    "-t",
                    "5.5",
                    "-vf",
                    f"fps=12,scale={PW}:{PH}",
                    "-q:v",
                    "3",
                    folder / "%04d.jpg",
                )
    cues = json.loads((BUILD / "captions.json").read_text())
    dest = ROOT / "AI_Blind_Assistant_Demo.mp4"
    command = [
        "ffmpeg",
        "-y",
        "-v",
        "warning",
        "-f",
        "rawvideo",
        "-pix_fmt",
        "rgb24",
        "-s",
        f"{W}x{H}",
        "-r",
        str(FPS),
        "-i",
        "-",
        "-i",
        str(BUILD / "narration.wav"),
        "-c:v",
        "libx264",
        "-preset",
        "fast",
        "-crf",
        "20",
        "-pix_fmt",
        "yuv420p",
        "-c:a",
        "aac",
        "-b:a",
        "160k",
        "-af",
        "loudnorm=I=-16:TP=-1.5:LRA=11",
        "-ar",
        "48000",
        "-t",
        str(STARTS[-1]),
        "-movflags",
        "+faststart",
        "-metadata",
        "title=AI Blind Assistant — Project Demo",
        str(dest),
    ]
    with (BUILD / "render.log").open("w") as log:
        proc = subprocess.Popen(command, stdin=subprocess.PIPE, stderr=log)
        try:
            for n in range(STARTS[-1] * FPS):
                proc.stdin.write(frame(n / FPS, cues).tobytes())
                if n % (FPS * 10) == 0:
                    print(f"Rendered {n // FPS}/{STARTS[-1]} seconds", flush=True)
            proc.stdin.close()
            if proc.wait() != 0:
                raise RuntimeError("FFmpeg failed; see build/render.log")
        except BaseException:
            proc.kill()
            raise
    frame(5, cues).save(ROOT / "AI_Blind_Assistant_Demo_Poster.jpg", quality=93)
    # Contact sheet for review; standalone PNGs permit full-size inspection.
    times = [5, 16, 32, 55, 72, 94, 117, 134, 151, 164]
    sheet = Image.new("RGB", (960 * 2, 540 * 5), BG)
    for i, t in enumerate(times):
        still = frame(t, cues)
        still.save(BUILD / f"review_{t:03}.png")
        sheet.paste(still.resize((960, 540)), (i % 2 * 960, i // 2 * 540))
    sheet.save(BUILD / "contact_sheet.jpg", quality=90)
    print("Exported", dest, flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--audio-only", action="store_true")
    parser.add_argument("--render-only", action="store_true")
    args = parser.parse_args()
    if not args.render_only:
        make_audio()
    if not args.audio_only:
        render()


if __name__ == "__main__":
    main()
