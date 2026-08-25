#!/bin/sh
# reverse_tunnel.sh — AI Blind Assistant Pi SSH Reverse Tunnel
#
# Opens a reverse SSH tunnel from this Pi to the owner's private laptop so
# the phone can reach the Pi wearable service (port 8765) via the laptop
# when the Pi and phone are on the same LAN but mDNS is not available
# (e.g. public WiFi with client isolation).
#
# SECURITY: The tunnel target MUST be a private-LAN address only.
# Never set AIBA_TUNNEL_TARGET_HOST to a public internet address.
# Port 8765 must never be exposed to the internet.
#
# Usage (manual):
#   export AIBA_TUNNEL_TARGET_USER=asjad
#   export AIBA_TUNNEL_TARGET_HOST=192.168.1.10   # your laptop's LAN IP
#   sh reverse_tunnel.sh
#
# Or pass arguments directly:
#   sh reverse_tunnel.sh asjad 192.168.1.10
#
# Usage (systemd): configure AIBA_TUNNEL_TARGET_USER and AIBA_TUNNEL_TARGET_HOST
# in /etc/ai-blind-assistant/wearable.env and enable ai-blind-assistant-tunnel.service.

set -eu

# -- Resolve configuration -----------------------------------------------

TUNNEL_USER="${1:-${AIBA_TUNNEL_TARGET_USER:-}}"
TUNNEL_HOST="${2:-${AIBA_TUNNEL_TARGET_HOST:-}}"
LOCAL_PORT="${AIBA_PORT:-8765}"

if [ -z "$TUNNEL_USER" ] || [ -z "$TUNNEL_HOST" ]; then
  echo "Error: tunnel user and host are required." >&2
  echo "Set AIBA_TUNNEL_TARGET_USER and AIBA_TUNNEL_TARGET_HOST in wearable.env" >&2
  echo "or pass them as arguments: $0 <SSH_USER> <LAPTOP_LAN_IP>" >&2
  exit 1
fi

# -- Safety: reject public addresses -------------------------------------
python3 - "$TUNNEL_HOST" <<'PY'
import ipaddress, sys
try:
    addr = ipaddress.ip_address(sys.argv[1])
except ValueError:
    # Hostname — allow but warn
    print(f"Note: {sys.argv[1]} is a hostname, not verified as private.", file=sys.stderr)
    sys.exit(0)
if not (addr.is_private or addr.is_loopback):
    print(f"ERROR: {sys.argv[1]} is not a private-LAN address. "
          "Never tunnel to a public internet address.", file=sys.stderr)
    sys.exit(1)
PY

# -- Open tunnel ---------------------------------------------------------
echo "Opening reverse tunnel: Pi:${LOCAL_PORT} -> ${TUNNEL_HOST}:${LOCAL_PORT} (via ${TUNNEL_USER}@${TUNNEL_HOST})"
echo "The phone should connect to ${TUNNEL_HOST}:${LOCAL_PORT} in the app."
echo "Press Ctrl+C to close the tunnel."

# Use autossh for resilient reconnect if available, otherwise plain ssh.
if command -v autossh >/dev/null 2>&1; then
  exec autossh \
    -M 0 \
    -o "ServerAliveInterval=30" \
    -o "ServerAliveCountMax=3" \
    -o "ExitOnForwardFailure=yes" \
    -o "BatchMode=yes" \
    -N \
    -R "${LOCAL_PORT}:127.0.0.1:${LOCAL_PORT}" \
    "${TUNNEL_USER}@${TUNNEL_HOST}"
else
  exec ssh \
    -o "ServerAliveInterval=30" \
    -o "ServerAliveCountMax=3" \
    -o "ExitOnForwardFailure=yes" \
    -o "BatchMode=yes" \
    -N \
    -R "${LOCAL_PORT}:127.0.0.1:${LOCAL_PORT}" \
    "${TUNNEL_USER}@${TUNNEL_HOST}"
fi
