# Agent Handoff

Last updated: 2026-08-25

## Current Result

Module 58 removes the hardcoded Pi IP and introduces two connection tiers:

1. **mDNS (same LAN):** `WearableDefaults.host` is now `rpi3-ml.local`. On any
   non-isolated LAN Android NSD resolves the hostname to the Pi's current IP
   automatically. No IP address management needed.
2. **SSH reverse tunnel (public WiFi):** `raspberry_pi/scripts/reverse_tunnel.sh`
   forwards Pi port 8765 → laptop port 8765 over SSH (`autossh` or `ssh -N -R`).
   The phone then connects to the laptop's LAN IP instead. This handles
   university/public WiFi with client isolation.

`ai-blind-assistant-tunnel.service` can start the tunnel automatically on boot.
`AIBA_TUNNEL_TARGET_USER` and `AIBA_TUNNEL_TARGET_HOST` in `wearable.env`
configure the target once.

No Linux credentials, SSH passwords, or IPs are stored in Flutter or Android.
The SSH tunnel uses `BatchMode=yes` (key auth only). Audio remains phone-priority
(Module 56 `VisionVoiceKernelV3` unchanged). All Module 57 enrollment/auth
protocol, credential, replay protection, and revocation behavior is unchanged.

Do NOT add the Linux login (`asjad` / `asjad`) to Android storage, protocol
data, tests, or release builds. First enrollment is trust-on-first-use and
belongs only on a private, owner-controlled network.

## Verification

- Dart format: 226 files, 0 changed.
- Flutter analyzer: 0 findings; Flutter suite: 318 passed, 0 failed.
- Pi Ruff: clean; Pi pytest: 15 passed, 0 failed.
- Physical enrollment, running detection, and phone-speaker audio remain
  pending physical deployment (network reachability required).

## Exact Next Action

**Same WiFi (home router / personal hotspot):**
1. `sh raspberry_pi/scripts/deploy.sh asjad rpi3-ml auto`
2. `ssh asjad@rpi3-ml sudo systemctl restart ai-blind-assistant-pi`
3. App host shows `rpi3-ml.local` — tap Connect & Start Detection.

**Public/university WiFi (client isolation):**
1. Deploy as above.
2. Find laptop's LAN IP: `ifconfig | grep inet` on the Mac.
3. On Pi: `sh /opt/ai-blind-assistant/service/scripts/reverse_tunnel.sh asjad <LAPTOP_LAN_IP>`
4. In app: change host field to `<LAPTOP_LAN_IP>`, tap Connect & Start Detection.

Record: first enrollment, authenticated detection running, phone-speaker alert,
second-phone rejection, disconnect fallback, Pi camera/NCNN logs, TalkBack focus.

