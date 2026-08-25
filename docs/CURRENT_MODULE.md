# Current Module

Last updated: 2026-08-25

## Module

Module 58: Dynamic Pi Discovery and Public-WiFi Fallback

## Result

Removed the hardcoded Pi IP address and introduced a two-tier connection
strategy so the phone connects to the Pi regardless of DHCP changes.

1. Changed `WearableDefaults.host` from the static IP `10.141.17.148` to the
   Pi's stable mDNS hostname `rpi3-ml.local`. Android NSD resolves `.local`
   names automatically on the same LAN; the phone finds the Pi even when the
   Pi's DHCP address changes.
2. Added `raspberry_pi/scripts/reverse_tunnel.sh` — a POSIX shell script that
   opens an SSH reverse tunnel from Pi port 8765 to the owner's laptop port
   8765 (`autossh` with `ssh` fallback). When the Pi and phone are on public
   or client-isolated WiFi where mDNS is blocked, the user runs the tunnel on
   the Pi and enters the laptop's local IP in the app instead.
3. Added `raspberry_pi/systemd/ai-blind-assistant-tunnel.service` — an
   optional systemd unit to start the tunnel automatically on boot.
4. Updated `raspberry_pi/config/wearable.env.example` with two commented tunnel
   variables (`AIBA_TUNNEL_TARGET_USER`, `AIBA_TUNNEL_TARGET_HOST`).
5. Added an in-app `FeatureNoteCard` below the host field on the Raspberry Pi
   screen explaining the two tiers.
6. Updated the accessibility test `findsOneWidget` → `findsWidgets` for the
   default hostname now shown in both the field and guidance card.
7. No Linux credentials or hardcoded IPs are stored in Flutter or Android.
   Audio output remains phone-priority (Module 56 unchanged).

## Verification

- Dart formatting: 226 files checked, 0 changed.
- Flutter analyzer: 0 findings.
- Full Flutter suite: 318 passed, 0 failed.
- Pi Ruff: all checks passed.
- Pi pytest: 15 passed, 0 failed.

## Physical Blocker

Physical enrollment still requires network reachability. Module 58 removes the
static IP dependency; both the mDNS path (same LAN) and the tunnel path
(public WiFi) are code-complete and tested.

## Exact Next Action

Same WiFi as Pi (home router / personal hotspot):
1. `sh raspberry_pi/scripts/deploy.sh asjad rpi3-ml auto`
2. `ssh asjad@rpi3-ml sudo systemctl restart ai-blind-assistant-pi`
3. App host shows `rpi3-ml.local` — tap Connect & Start Detection.

Public/university WiFi:
1. Deploy as above.
2. Find laptop LAN IP: `ifconfig | grep inet`.
3. On Pi: `sh /opt/ai-blind-assistant/service/scripts/reverse_tunnel.sh asjad <LAPTOP_LAN_IP>`
4. In app: change host to `<LAPTOP_LAN_IP>`, tap Connect & Start Detection.

Record: enrollment, running detection, phone-speaker alert, TalkBack focus.
