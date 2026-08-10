"""Owner CLI and service entry point."""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import signal
import sys
from pathlib import Path

from .adapters.camera_picamera2 import Picamera2Camera
from .adapters.detector_ncnn import NcnnYoloDetector
from .adapters.simulated import NullSpeech, SimulatedCamera, SimulatedDetector
from .config import ServiceConfig, select_private_bind_host
from .discovery import MdnsAdvertiser
from .feedback import EspeakSpeech, FeedbackPolicy
from .logging_setup import configure_logging
from .persistence import StateStore
from .security import PairingManager
from .service import AssistanceEngine
from .websocket_server import WearableWebSocketServer

LOGGER = logging.getLogger(__name__)


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="ai-blind-pi")
    subparsers = parser.add_subparsers(dest="command", required=True)
    serve_parser = subparsers.add_parser("serve", help="run the wearable service")
    serve_parser.add_argument(
        "--simulate", action="store_true", help="use deterministic camera/model adapters"
    )
    serve_parser.add_argument("--verbose", action="store_true")
    serve_parser.add_argument(
        "--ready-file",
        type=Path,
        default=None,
        help="write simulator endpoint metadata after binding (test automation only)",
    )
    code_parser = subparsers.add_parser(
        "pairing-code", help="generate one short-lived local pairing code"
    )
    code_parser.add_argument("--ttl", type=int, default=None, help="lifetime in seconds")
    revoke_parser = subparsers.add_parser("revoke", help="revoke a phone credential")
    revoke_parser.add_argument("credential_id", help="credential UUID or 'all'")
    subparsers.add_parser("status", help="show non-secret local state")
    subparsers.add_parser("validate-model", help="load and validate the configured NCNN model")
    return parser


async def _run_service(config: ServiceConfig, *, ready_file: Path | None = None) -> None:
    config.prepare_directories()
    store = StateStore(config.state_file)
    pairing = PairingManager(store)
    if config.simulate:
        camera = SimulatedCamera()
        detector = SimulatedDetector()
    else:
        camera = Picamera2Camera(
            width=config.camera_width,
            height=config.camera_height,
            fps=config.camera_fps,
        )
        detector = NcnnYoloDetector(config.model_dir, num_threads=config.ncnn_threads)
    speech = EspeakSpeech() if config.enable_local_speech else NullSpeech()
    engine = AssistanceEngine(
        device_id=config.device_id,
        camera=camera,
        detector=detector,
        feedback=FeedbackPolicy(
            speech,
            max_announcements_per_minute=config.max_announcements_per_minute,
        ),
        store=store,
        nms_threshold=config.nms_threshold,
        frame_stride=config.frame_stride,
        max_camera_restarts=config.max_camera_restarts,
    )
    server = WearableWebSocketServer(config=config, engine=engine, pairing=pairing)
    mdns: MdnsAdvertiser | None = None
    stop_event = asyncio.Event()
    loop = asyncio.get_running_loop()
    for signum in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(signum, stop_event.set)
        except NotImplementedError:
            pass
    await engine.initialize()
    await server.start()
    if ready_file is not None:
        if not config.simulate:
            raise RuntimeError("--ready-file is only available with --simulate")
        ready_file.parent.mkdir(parents=True, exist_ok=True)
        temporary = ready_file.with_suffix(ready_file.suffix + ".tmp")
        temporary.write_text(
            json.dumps(
                {
                    "deviceId": config.device_id,
                    "host": config.bind_host,
                    "port": server.bound_port,
                    "path": "/wearable/v1",
                }
            ),
            encoding="utf-8",
        )
        temporary.replace(ready_file)
    if config.enable_mdns and config.port != 0:
        mdns = MdnsAdvertiser(
            host=config.bind_host,
            port=server.bound_port,
            device_id=config.device_id,
            device_name=config.device_name,
        )
        try:
            await mdns.start()
        except Exception as error:
            # Manual address/hostname remains available; discovery failure is visible.
            LOGGER.error("mDNS advertisement unavailable: %s", error)
            mdns = None
    stop_task = asyncio.create_task(stop_event.wait(), name="shutdown-signal")
    address_task = (
        asyncio.create_task(_wait_for_bind_address_change(config), name="bind-address-monitor")
        if config.auto_bind
        else None
    )
    restart_for_address_change = False
    try:
        waiters = {stop_task}
        if address_task is not None:
            waiters.add(address_task)
        completed, _ = await asyncio.wait(waiters, return_when=asyncio.FIRST_COMPLETED)
        restart_for_address_change = address_task is not None and address_task in completed
    finally:
        for task in (stop_task, address_task):
            if task is not None and not task.done():
                task.cancel()
        await asyncio.gather(
            *(task for task in (stop_task, address_task) if task is not None),
            return_exceptions=True,
        )
        if mdns:
            await mdns.close()
        await server.close()
        await engine.close()
        if ready_file is not None:
            ready_file.unlink(missing_ok=True)
    if restart_for_address_change:
        raise RuntimeError("private bind address changed; requesting bounded service restart")


async def _wait_for_bind_address_change(config: ServiceConfig) -> None:
    while True:
        await asyncio.sleep(5)
        try:
            current = select_private_bind_host()
        except ValueError:
            continue
        if current != config.bind_host:
            LOGGER.warning("private bind address changed; restarting service")
            return


def _store_for(config: ServiceConfig) -> StateStore:
    config.prepare_directories()
    return StateStore(config.state_file)


def main(argv: list[str] | None = None) -> None:
    args = _parser().parse_args(argv)
    simulate = bool(getattr(args, "simulate", False))
    config = ServiceConfig.from_env(simulate=simulate)
    config.prepare_directories()
    configure_logging(config.log_file, verbose=bool(getattr(args, "verbose", False)))
    if args.command == "serve":
        asyncio.run(_run_service(config, ready_file=args.ready_file))
        return
    store = _store_for(config)
    pairing = PairingManager(store)
    if args.command == "pairing-code":
        ttl = config.pairing_ttl_seconds if args.ttl is None else args.ttl
        if not 30 <= ttl <= 900:
            raise SystemExit("--ttl must be between 30 and 900 seconds")
        code, expires_at = pairing.create_code(ttl)
        # This is deliberately owner-requested stdout and is never sent to logs.
        print(code)
        print(f"Expires at Unix time (ms): {expires_at}")
    elif args.command == "revoke":
        if not pairing.revoke(args.credential_id):
            raise SystemExit("credential not found")
        print("Credential revoked.")
    elif args.command == "status":
        state = store.load()
        credentials = state.get("credentials", {})
        safe = {
            "schemaVersion": state.get("schemaVersion"),
            "pairingChallengeActive": bool(state.get("pairingChallenge")),
            "settings": state.get("settings"),
            "credentials": [
                {
                    "credentialId": credential_id,
                    "displayName": value.get("displayName"),
                    "createdAt": value.get("createdAt"),
                    "lastUsedAt": value.get("lastUsedAt"),
                    "revoked": value.get("revoked", False),
                }
                for credential_id, value in credentials.items()
            ],
        }
        print(json.dumps(safe, indent=2))
    elif args.command == "validate-model":
        detector = NcnnYoloDetector(config.model_dir, num_threads=config.ncnn_threads)
        try:
            detector.load()
            print(json.dumps(detector.model_description, indent=2))
        finally:
            detector.close()
    else:
        raise SystemExit(2)


if __name__ == "__main__":
    main(sys.argv[1:])
