# AI Blind Assistant Raspberry Pi wearable service

This directory contains the offline Raspberry Pi 3B service controlled by the
Flutter application. It loads the finalized YOLOv8n Open Images V7 NCNN model
once, captures the OV5647 through Picamera2, drops stale frames through a
one-slot queue, owns local speech feedback, and exchanges compact authenticated
events over the local network. Camera frames are neither transmitted nor saved.

The production model is external to the repository. See `model/README.md` for
the required three-file artifact set, tensor contract, label source, license,
and verified hashes. Do not install PyTorch or Ultralytics on the Pi.
Linux aarch64 installs pin the official NCNN Python runtime at
`ncnn==1.0.20260526`; other development platforms use the simulated adapter.

For an isolated software-only run:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -e '.[test]'
AIBA_BIND_HOST=127.0.0.1 AIBA_PORT=8765 \
  AIBA_STATE_DIR="$PWD/var/state" AIBA_LOG_DIR="$PWD/var/logs" \
  AIBA_ENABLE_MDNS=false AIBA_ENABLE_LOCAL_SPEECH=false \
  .venv/bin/ai-blind-pi pairing-code
AIBA_BIND_HOST=127.0.0.1 AIBA_PORT=8765 \
  AIBA_STATE_DIR="$PWD/var/state" AIBA_LOG_DIR="$PWD/var/logs" \
  AIBA_ENABLE_MDNS=false AIBA_ENABLE_LOCAL_SPEECH=false \
  .venv/bin/ai-blind-pi serve --simulate
```

Production installation, pairing, service management, security boundaries,
and camera tests are documented in `../docs/wearable-mode.md`.
