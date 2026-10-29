#!/bin/sh
# Installed by install.sh as a NetworkManager dispatcher hook. NetworkManager
# invokes it as root when a Wi-Fi connection becomes available. No SSID,
# password, or client address is read or logged here.
set -eu

case "${1:-}:${2:-}" in
  wlan*:up|wl*:up)
    systemctl reset-failed ai-blind-assistant-pi.service
    systemctl --no-block restart ai-blind-assistant-pi.service
    ;;
esac
