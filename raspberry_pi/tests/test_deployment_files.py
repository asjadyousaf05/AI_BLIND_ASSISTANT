from __future__ import annotations

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
