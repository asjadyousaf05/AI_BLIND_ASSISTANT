from __future__ import annotations

import os
import subprocess
from configparser import ConfigParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_systemd_unit_has_restricted_non_root_runtime() -> None:
    parser = ConfigParser(interpolation=None, strict=True)
    parser.optionxform = str
    unit = ROOT / "systemd" / "ai-blind-assistant-pi.service"
    parser.read(unit, encoding="utf-8")
    service = parser["Service"]
    assert service["User"] == "aiba"
    assert service["Group"] == "aiba"
    assert service["WorkingDirectory"] == "/opt/ai-blind-assistant/service"
    assert service["ExecStart"].startswith("/opt/ai-blind-assistant/venv/bin/")
    assert service["Restart"] == "on-failure"
    assert service["NoNewPrivileges"] == "true"
    assert service["ProtectSystem"] == "strict"
    assert service["ProtectHome"] == "true"
    assert service["CapabilityBoundingSet"] == ""
    assert int(parser["Unit"]["StartLimitBurst"]) <= 5


def test_model_checksum_manifest_covers_exact_required_files() -> None:
    entries = {
        line.split()[1]: line.split()[0]
        for line in (ROOT / "model" / "SHA256SUMS").read_text().splitlines()
    }
    assert set(entries) == {"model.ncnn.param", "model.ncnn.bin", "metadata.yaml"}
    assert all(len(digest) == 64 for digest in entries.values())


def test_default_deployment_uses_dynamic_private_address_not_a_wildcard() -> None:
    environment = (ROOT / "config" / "wearable.env.example").read_text(encoding="utf-8")
    assert "AIBA_BIND_HOST=auto" in environment
    assert "AIBA_BIND_HOST=0.0.0.0" not in environment
    assert "AIBA_ALLOW_FIRST_CLIENT_ENROLLMENT=true" in environment


def test_hotspot_link_restores_service_without_exhausting_restart_limit(tmp_path: Path) -> None:
    hook = ROOT / "scripts" / "hotspot_network_dispatcher.sh"
    installer = (ROOT / "scripts" / "install.sh").read_text(encoding="utf-8")
    assert "90-ai-blind-assistant-hotspot" in installer
    assert "hotspot_network_dispatcher.sh" in installer

    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    calls = tmp_path / "calls"
    fake_systemctl = bin_dir / "systemctl"
    fake_systemctl.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$CALLS"\n')
    fake_systemctl.chmod(0o755)
    env = {**os.environ, "PATH": str(bin_dir), "CALLS": str(calls)}

    subprocess.run(["/bin/sh", str(hook), "eth0", "up"], env=env, check=True)
    assert not calls.exists()
    subprocess.run(["/bin/sh", str(hook), "wlan0", "up"], env=env, check=True)
    assert calls.read_text().splitlines() == [
        "reset-failed ai-blind-assistant-pi.service",
        "--no-block restart ai-blind-assistant-pi.service",
    ]
