"""Capture only the dedicated emulator; never access a physical camera/phone.

Run this file with --help. UI labels/bounds drive the video's hover borders.
Temporary recordings stay on the emulator until copied to the chosen output.
"""

import argparse
import json
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

DEVICE = "emulator-5554"
ROOT = Path(__file__).resolve().parents[1]


def adb(*args, timeout=30):
    return subprocess.run(
        ["adb", "-s", DEVICE, *map(str, args)],
        check=True,
        capture_output=True,
        timeout=timeout,
    ).stdout


def capture(name):
    folder = ROOT / "source" / "captures"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / f"{name}.png").write_bytes(adb("exec-out", "screencap", "-p"))
    adb("shell", "uiautomator", "dump", "/sdcard/aba-demo-ui.xml")
    xml = adb("exec-out", "cat", "/sdcard/aba-demo-ui.xml")
    regions = []
    for node in ET.fromstring(xml).iter("node"):
        label = node.get("content-desc") or node.get("text")
        if not label:
            continue
        bounds = list(map(int, re.findall(r"\d+", node.get("bounds", ""))))
        regions.append(
            {
                "label": label,
                "bounds": bounds,
                "clickable": node.get("clickable") == "true",
            }
        )
    (folder / f"{name}.json").write_text(json.dumps(regions, indent=2))
    print(name, json.dumps(regions), flush=True)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("name")
    p.add_argument("--tap", nargs=2, type=int)
    p.add_argument("--swipe", nargs=4, type=int)
    p.add_argument("--back", action="store_true")
    p.add_argument("--wait", type=float, default=1.5)
    p.add_argument("--clip", type=int, default=0)
    a = p.parse_args()
    recorder = None
    remote = f"/sdcard/aba-demo-{a.name}.mp4"
    if a.clip:
        recorder = subprocess.Popen(
            [
                "adb",
                "-s",
                DEVICE,
                "shell",
                "screenrecord",
                "--bit-rate",
                "4000000",
                "--time-limit",
                str(a.clip),
                remote,
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        time.sleep(1)
    if a.tap:
        adb("shell", "input", "tap", *a.tap)
    if a.swipe:
        adb("shell", "input", "swipe", *a.swipe, 450)
    if a.back:
        adb("shell", "input", "keyevent", "4")
    time.sleep(a.wait)
    capture(a.name)
    if recorder:
        recorder.wait(timeout=a.clip + 15)
        dest = ROOT / "source" / "captures" / f"{a.name}.mp4"
        adb("pull", remote, dest)
        adb("shell", "rm", remote)
        print("Recorded", dest.name, flush=True)


if __name__ == "__main__":
    main()
