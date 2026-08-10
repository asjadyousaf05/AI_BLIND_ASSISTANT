"""Validated runtime configuration loaded from environment variables."""

from __future__ import annotations

import fcntl
import hashlib
import ipaddress
import os
import socket
import struct
import sys
from dataclasses import dataclass
from pathlib import Path


def _env_bool(name: str, default: bool) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    normalized = value.strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return True
    if normalized in {"0", "false", "no", "off"}:
        return False
    raise ValueError(f"{name} must be true or false")


def _env_int(name: str, default: int, minimum: int, maximum: int) -> int:
    raw = os.getenv(name)
    value = default if raw is None else int(raw)
    if not minimum <= value <= maximum:
        raise ValueError(f"{name} must be between {minimum} and {maximum}")
    return value


def _env_float(name: str, default: float, minimum: float, maximum: float) -> float:
    raw = os.getenv(name)
    value = default if raw is None else float(raw)
    if not minimum <= value <= maximum:
        raise ValueError(f"{name} must be between {minimum} and {maximum}")
    return value


def _device_id() -> str:
    try:
        machine_id = Path("/etc/machine-id").read_text(encoding="utf-8").strip()
    except OSError:
        machine_id = socket.gethostname()
    return "pi-" + hashlib.sha256(machine_id.encode("utf-8")).hexdigest()[:16]


def select_private_bind_host() -> str:
    """Select one concrete private IPv4 address without binding a wildcard."""
    candidates: list[tuple[int, str]] = []
    if sys.platform.startswith("linux"):
        for _, interface in socket.if_nameindex():
            probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            try:
                request = struct.pack("256s", interface.encode("utf-8")[:15])
                response = fcntl.ioctl(probe.fileno(), 0x8915, request)
                value = socket.inet_ntoa(response[20:24])
            except OSError:
                continue
            finally:
                probe.close()
            address = ipaddress.ip_address(value)
            if address.is_private and not address.is_loopback and not address.is_link_local:
                normalized = interface.casefold()
                rank = (
                    0
                    if normalized.startswith(("wlan", "wl"))
                    else 1
                    if normalized.startswith(("eth", "en"))
                    else 2
                )
                candidates.append((rank, value))
    else:
        # Development fallback. Connecting a datagram selects an interface but
        # does not transmit application data.
        probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            probe.connect(("192.0.2.1", 9))
            value = str(probe.getsockname()[0])
            address = ipaddress.ip_address(value)
            if address.is_private and not address.is_loopback:
                candidates.append((0, value))
        except OSError:
            pass
        finally:
            probe.close()
    if not candidates:
        raise ValueError("no concrete private-LAN IPv4 address is available")
    return min(candidates)[1]


@dataclass(frozen=True, slots=True)
class ServiceConfig:
    bind_host: str
    port: int
    device_id: str
    device_name: str
    state_dir: Path
    log_dir: Path
    model_dir: Path
    camera_width: int
    camera_height: int
    camera_fps: int
    ncnn_threads: int
    nms_threshold: float
    frame_stride: int
    max_announcements_per_minute: int
    heartbeat_seconds: int
    stale_seconds: int
    pairing_ttl_seconds: int
    max_camera_restarts: int
    enable_mdns: bool
    enable_local_speech: bool
    auto_bind: bool = False
    simulate: bool = False

    @property
    def state_file(self) -> Path:
        return self.state_dir / "state.json"

    @property
    def log_file(self) -> Path:
        return self.log_dir / "wearable-service.log"

    @classmethod
    def from_env(cls, *, simulate: bool = False) -> ServiceConfig:
        default_root = Path.home() / ".local" / "share" / "ai-blind-assistant"
        raw_port = os.getenv("AIBA_PORT")
        port = 8765 if raw_port is None else int(raw_port)
        if simulate:
            if not 0 <= port <= 65535:
                raise ValueError("AIBA_PORT must be between 0 and 65535 in simulation")
        elif not 1024 <= port <= 65535:
            raise ValueError("AIBA_PORT must be between 1024 and 65535")
        requested_bind_host = os.getenv("AIBA_BIND_HOST", "auto").strip()
        auto_bind = requested_bind_host.casefold() == "auto"
        bind_host = select_private_bind_host() if auto_bind else requested_bind_host
        config = cls(
            # `auto` resolves to one concrete private address, never a wildcard.
            bind_host=bind_host,
            port=port,
            device_id=os.getenv("AIBA_DEVICE_ID", _device_id()).strip(),
            device_name=os.getenv("AIBA_DEVICE_NAME", socket.gethostname()).strip(),
            state_dir=Path(os.getenv("AIBA_STATE_DIR", default_root / "state")),
            log_dir=Path(os.getenv("AIBA_LOG_DIR", default_root / "logs")),
            model_dir=Path(os.getenv("AIBA_MODEL_DIR", "/opt/ai-blind-assistant/model")),
            camera_width=_env_int("AIBA_CAMERA_WIDTH", 640, 320, 1920),
            camera_height=_env_int("AIBA_CAMERA_HEIGHT", 480, 240, 1080),
            camera_fps=_env_int("AIBA_CAMERA_FPS", 12, 1, 30),
            ncnn_threads=_env_int("AIBA_NCNN_THREADS", 3, 1, 4),
            nms_threshold=_env_float("AIBA_NMS_THRESHOLD", 0.45, 0.05, 0.95),
            frame_stride=_env_int("AIBA_FRAME_STRIDE", 2, 1, 12),
            max_announcements_per_minute=_env_int("AIBA_MAX_ANNOUNCEMENTS_PER_MINUTE", 12, 1, 60),
            heartbeat_seconds=_env_int("AIBA_HEARTBEAT_SECONDS", 10, 3, 60),
            stale_seconds=_env_int("AIBA_STALE_SECONDS", 30, 10, 180),
            pairing_ttl_seconds=_env_int("AIBA_PAIRING_TTL_SECONDS", 300, 30, 900),
            max_camera_restarts=_env_int("AIBA_MAX_CAMERA_RESTARTS", 3, 0, 10),
            enable_mdns=_env_bool("AIBA_ENABLE_MDNS", True),
            enable_local_speech=_env_bool("AIBA_ENABLE_LOCAL_SPEECH", True),
            auto_bind=auto_bind,
            simulate=simulate,
        )
        config.validate()
        return config

    def validate(self) -> None:
        if not self.device_id or len(self.device_id) > 128:
            raise ValueError("AIBA_DEVICE_ID must contain 1 to 128 characters")
        if not self.device_name or len(self.device_name) > 128:
            raise ValueError("AIBA_DEVICE_NAME must contain 1 to 128 characters")
        try:
            address = ipaddress.ip_address(self.bind_host)
        except ValueError as error:
            raise ValueError(
                "AIBA_BIND_HOST must be a concrete loopback or private-LAN IP address"
            ) from error
        if address.is_unspecified or not (address.is_loopback or address.is_private):
            raise ValueError("AIBA_BIND_HOST must be a concrete loopback or private-LAN IP address")

    def prepare_directories(self) -> None:
        for path in (self.state_dir, self.log_dir):
            path.mkdir(parents=True, exist_ok=True, mode=0o700)
            path.chmod(0o700)
