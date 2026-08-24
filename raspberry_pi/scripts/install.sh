#!/bin/sh
set -eu

usage() {
  echo "Usage: sudo $0 [--bind-host AUTO_OR_PRIVATE_IP] [--model-source DIR] [--model-checksums FILE] [--wheelhouse DIR] [--start]"
}

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this installer with sudo." >&2
  exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SOURCE_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
BIND_HOST=auto
MODEL_SOURCE=
MODEL_CHECKSUMS=$SOURCE_ROOT/model/SHA256SUMS
WHEELHOUSE=
START_SERVICE=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --bind-host)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      BIND_HOST=$2
      shift 2
      ;;
    --model-source)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      MODEL_SOURCE=$2
      shift 2
      ;;
    --model-checksums)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      MODEL_CHECKSUMS=$2
      shift 2
      ;;
    --wheelhouse)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      WHEELHOUSE=$2
      shift 2
      ;;
    --start)
      START_SERVICE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

python3 - "$BIND_HOST" <<'PY'
import ipaddress
import sys

if sys.argv[1].casefold() != "auto":
    address = ipaddress.ip_address(sys.argv[1])
    if not (address.is_loopback or (address.is_private and not address.is_unspecified)):
        raise SystemExit("--bind-host must be auto, loopback, or a concrete private-LAN IP")
PY

if [ -n "$MODEL_SOURCE" ]; then
  for name in model.ncnn.param model.ncnn.bin metadata.yaml; do
    if [ ! -f "$MODEL_SOURCE/$name" ]; then
      echo "Missing model artifact: $MODEL_SOURCE/$name" >&2
      exit 1
    fi
  done
  if [ ! -f "$MODEL_CHECKSUMS" ]; then
    echo "Missing model checksum manifest: $MODEL_CHECKSUMS" >&2
    exit 1
  fi
  (
    cd "$MODEL_SOURCE"
    sha256sum -c "$MODEL_CHECKSUMS"
  )
fi

STAMP=$(date +%Y%m%d-%H%M%S)
INSTALL_ROOT=/opt/ai-blind-assistant
SERVICE_DIR=$INSTALL_ROOT/service
VENV_DIR=$INSTALL_ROOT/venv
MODEL_DIR=$INSTALL_ROOT/model
STATE_DIR=/var/lib/ai-blind-assistant/state
LOG_DIR=/var/log/ai-blind-assistant
CONFIG_DIR=/etc/ai-blind-assistant
UNIT_PATH=/etc/systemd/system/ai-blind-assistant-pi.service

if ! id aiba >/dev/null 2>&1; then
  useradd --system --home-dir /var/lib/ai-blind-assistant --create-home --shell /usr/sbin/nologin aiba
fi
for group_name in video audio; do
  if getent group "$group_name" >/dev/null 2>&1; then
    usermod -a -G "$group_name" aiba
  fi
done

install -d -m 0755 "$INSTALL_ROOT"
install -d -o aiba -g aiba -m 0700 "$STATE_DIR" "$LOG_DIR"
install -d -o root -g aiba -m 0750 "$CONFIG_DIR"
install -d -o root -g aiba -m 0750 "$MODEL_DIR"

if [ -d "$SERVICE_DIR" ]; then
  mv "$SERVICE_DIR" "$SERVICE_DIR.backup-$STAMP"
fi
install -d -m 0755 "$SERVICE_DIR"
cp -R "$SOURCE_ROOT"/. "$SERVICE_DIR"/
find "$SERVICE_DIR" -type d -exec chmod 0755 {} \;
find "$SERVICE_DIR" -type f -exec chmod 0644 {} \;
chmod 0755 "$SERVICE_DIR/scripts"/*.sh "$SERVICE_DIR/scripts"/*.py

if [ -d "$VENV_DIR" ]; then
  mv "$VENV_DIR" "$VENV_DIR.backup-$STAMP"
fi
python3 -m venv --system-site-packages "$VENV_DIR"
if [ -n "$WHEELHOUSE" ]; then
  "$VENV_DIR/bin/python" -m pip install --no-index --find-links "$WHEELHOUSE" "$SERVICE_DIR"
else
  "$VENV_DIR/bin/python" -m pip install "$SERVICE_DIR"
fi

if [ -n "$MODEL_SOURCE" ]; then
  for name in model.ncnn.param model.ncnn.bin metadata.yaml; do
    if [ -f "$MODEL_DIR/$name" ]; then
      cp -p "$MODEL_DIR/$name" "$MODEL_DIR/$name.backup-$STAMP"
    fi
    install -o root -g aiba -m 0640 "$MODEL_SOURCE/$name" "$MODEL_DIR/$name"
  done
fi

ENV_PATH=$CONFIG_DIR/wearable.env
if [ -f "$ENV_PATH" ]; then
  cp -p "$ENV_PATH" "$ENV_PATH.backup-$STAMP"
fi
sed "s/^AIBA_BIND_HOST=.*/AIBA_BIND_HOST=$BIND_HOST/" \
  "$SERVICE_DIR/config/wearable.env.example" > "$ENV_PATH"
chown root:aiba "$ENV_PATH"
chmod 0640 "$ENV_PATH"

if [ -f "$UNIT_PATH" ]; then
  cp -p "$UNIT_PATH" "$UNIT_PATH.backup-$STAMP"
fi
install -o root -g root -m 0644 \
  "$SERVICE_DIR/systemd/ai-blind-assistant-pi.service" "$UNIT_PATH"
systemctl daemon-reload
systemctl enable ai-blind-assistant-pi.service

if ! "$VENV_DIR/bin/python" -c 'import picamera2' >/dev/null 2>&1; then
  echo "WARNING: Picamera2 is unavailable. Install the OS-supported python3-picamera2 package." >&2
fi
if ! "$VENV_DIR/bin/python" -c 'import ncnn' >/dev/null 2>&1; then
  echo "WARNING: NCNN Python bindings are unavailable. Install a compatible aarch64 binding before starting." >&2
fi
if ! command -v espeak-ng >/dev/null 2>&1; then
  echo "WARNING: espeak-ng is unavailable. Install it or set AIBA_ENABLE_LOCAL_SPEECH=false." >&2
fi

if [ "$START_SERVICE" = true ]; then
  systemctl restart ai-blind-assistant-pi.service
fi

echo "Installed AI Blind Assistant Pi service."
echo "Bind address: $BIND_HOST"
echo "The first phone can enroll directly when AIBA_ALLOW_FIRST_CLIENT_ENROLLMENT=true."
echo "Reset trusted phones with: sudo -u aiba $VENV_DIR/bin/ai-blind-pi revoke all"
echo "Check status with: systemctl status ai-blind-assistant-pi.service"
