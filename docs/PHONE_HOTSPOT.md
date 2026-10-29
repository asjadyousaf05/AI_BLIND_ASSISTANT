# Phone hotspot for Raspberry Pi Wearable Mode

Last reviewed: 2026-10-22

## Latest physical evidence: Pixel hotspot

Module 76 restores the service/model/runtime after the owner flashes fresh Pi OS.
The Pixel 1.4.18 app completes discovery/enrollment/authentication/settings sync
and reaches Running with Camera Active/Model Ready over its own 2.4 GHz hotspot.
Both laptop and Pi are clients; Pi inference requires no laptop relay. Existing
startup hooks and the Pi's current network profile auto-connect are restored.
Phone alerts need Wearable Mode visible. Owner confirms test audio and actual
object announcements work. Power quality and broader performance remain open.
[Exact results, DHCP topology and recovery](PIXEL_PI_RESTORE_2026-10-22.md).

## Decision and researched limits

Use the owner's **Android Personal Hotspot** as the primary private network for
Wearable Mode. The Pi joins it as a Wi-Fi client. The Pi's `AIBA_BIND_HOST=auto`
selects its current private address, and the service advertises
`_aiba-wearable._tcp`. The app performs bounded NSD discovery, then uses its
authenticated WebSocket protocol. The saved credential is tied to device ID,
not only the DHCP address; reconnect discovery can update the endpoint.

Android tethering uses DHCP for IPv4 clients. Therefore the Pi IP can still
change after hotspot restart. A fixed `192.168.x.x` address or a fixed Android
hotspot gateway would be an unsupported assumption. Discovery is the primary
address-independent path; `rpi3-ml.local` and the current private Pi address
are manual fallbacks. Android NSD documentation also requires a short-lived
multicast lock on older Android versions. The app now holds that lock only for
the bounded discovery window. Hotspot-host NSD/mDNS behavior varies by device
and must be checked on the target TECNO BG6; no software-only test proves it.

The ordinary Personal Hotspot is configured by the owner in Android Settings.
The app does not create or store the hotspot password. Android's local-only
hotspot API creates an app-owned hotspot with no Internet and a reservation
lifecycle; it is not the selected persistent user-managed connection. Do not
put the Pi on public/university Wi-Fi for first enrollment. The existing SSH
tunnel remains a separate diagnostic fallback, not part of this setup.

## Laptop and Pi on the same phone hotspot

The phone is the access point. Join **both** the laptop and Pi to its hotspot;
ordinary phone Wi-Fi can stay off. Concurrent Wi-Fi-station/hotspot support is
not required. Each client receives its own DHCP address. The app connects to
the Pi for Wearable Mode and to the laptop for optional Whisper/Ollama; both
services may use port 8765 because they run on different devices. USB debugging
is for installation/diagnosis, not a requirement for daily Pi use.

For laptop mode, keep the backend listening on the private LAN (`HOST=0.0.0.0`
by default), allow its trusted-LAN firewall traffic, and enter the laptop's
**current hotspot IP** under Connect Assistant with its one-time code. On macOS,
`ipconfig getifaddr en0` reports the Wi-Fi address when en0 is the Wi-Fi device.
Do not enter the phone gateway or the Pi IP in the laptop form. The updated form
restores saved pairing and no longer preselects the old university-network IP.

For direct Gemini mode, enter a personal key under Connect Assistant, review
its disclosure and opt in. Only conversation text goes to Google. Cellular
internet is needed for Gemini when the phone supplies the hotspot; local Pi and
laptop Ollama do not need it. Keep the laptop awake when using its services.

## One-time setup

1. In Android Settings, set a stable Personal Hotspot name and a strong
   password, then turn it on. Choose a **2.4 GHz** band and WPA2-compatible
   security for the project's Pi 3B. Disable automatic hotspot shutdown if
   the phone offers that setting. Keep the password out of this repository,
   terminal history, screenshots, and logs.
2. On the Pi console or SSH while it is reachable, connect it to the hotspot:

   ```sh
   sudo nmcli --ask dev wifi connect '<HOTSPOT_SSID>'
   ```

   `--ask` prompts for the password without putting it in the command line.
   Raspberry Pi OS NetworkManager owns the resulting Wi-Fi profile; the app
   never reads or copies that profile. If multiple known networks compete,
   find the new profile with `nmcli connection show` and give it higher
   autoconnect priority:

   ```sh
   sudo nmcli connection modify '<HOTSPOT_PROFILE>' connection.autoconnect yes connection.autoconnect-priority 100
   ```

3. Keep `AIBA_BIND_HOST=auto` and `AIBA_ENABLE_MDNS=true` in the installed Pi
   service environment. Deploy the matching Pi service using the repository's
   existing `raspberry_pi/scripts/deploy.sh` procedure. Restart the service
   after the Pi joins the hotspot. The installer adds a NetworkManager
   dispatcher hook that restarts the bounded systemd service whenever the Pi
   Wi-Fi link comes up. The running service separately detects address changes.
   The hook needs the
   standard Raspberry Pi OS NetworkManager dispatcher directory.
4. On the Pi, verify the hotspot network and service without printing secrets:

   ```sh
   nmcli -f GENERAL.CONNECTION,IP4.ADDRESS,IP4.GATEWAY device show wlan0
   systemctl status ai-blind-assistant-pi.service --no-pager
   ss -ltn '( sport = :8765 )'
   ```

5. In the app's Raspberry Pi screen, tap **Test Phone Audio** and confirm that
   you hear the test phrase. Enable Audio or Audio and vibration in Saved
   Settings for object announcements. Then tap **Connect & Start Detection**. The app
   searches first and selects the Pi only if exactly one wearable is found.
   If several are found, select the intended Pi explicitly. On an unclaimed Pi this is
   first-phone enrollment. Later sessions reuse the Keystore credential.

## Verified software improvements (Module 65)

Commands and heartbeats share one signed sequence. The app uses the Pi's hello
clock with monotonic elapsed time, so an offline Pi does not need its wall clock
to agree with the phone. Exact received timestamp text and consistent numeric
canonicalization prevent valid alerts being rejected by HMAC. The existing
freshness window, nonce authentication and replay checks remain in force.

Failed settings synchronization blocks the combined Start flow and retains the
recovery message. The phone-audio test works before connection; its completion
does not prove audibility at the user's media volume. Phone speech stops on
pause/stop/disconnect/background/mute, and Pi fallback stops before a connected
phone-target alert. mDNS is confined to the selected private interface and cleans
up failed registration. The Wi-Fi-up hook schedules restart without blocking
NetworkManager. See HOTSPOT_VERIFICATION_2026-10-09.md for evidence and open gates.

## Connection and recovery behavior

Connect & Start keeps one operation active through trust, authentication,
settings, and detection start. Repeated taps are ignored. A trusted Pi selection
reuses its credential, including after a manual address correction. Each retry
searches for the same device ID at its current DHCP address. Socket errors,
closed connections, and stale heartbeats start one bounded reconnect run.
After retry exhaustion use Retry or Connect again; authentication rejection
requires credential recovery. Hostname resolution also has a finite timeout.

Cancel Connection stops pending search/retry/start work. Backgrounding closes
the phone link and blocks new phone speech; the Pi retains any assistance it
already started. Foreground resume restores a desired connection once. A
command already acknowledged/applied on the Pi cannot be undone by cancellation.
If the Pi rebooted into idle state, tap Start Detection after reconnecting.

Manual fields and detailed hotspot setup are under **Connection options**.
Discovery resolves services serially and discards stale callbacks. These are
software checks; handset hotspot routing/multicast and speakers still require
the physical acceptance below.

## If search fails

1. Confirm that the phone hotspot shows the Pi as a connected client and the
   Pi reports an IPv4 address on `wlan0`. Confirm the service is listening on
   that same private address and port 8765.
2. Try the Pi hostname `rpi3-ml.local` under Connection options, in the manual address field. This is a
   fallback; Android's ordinary hostname resolver may not resolve `.local` on
   a hotspot even when NSD works.
3. If hostname lookup fails, enter the **current** `IP4.ADDRESS` from the Pi
   (without its `/24` suffix) under Connection options, in the manual address field. Repeat this after
   DHCP changes. Do not copy a stale address into source code.
4. If TCP 8765 cannot be reached from the phone, check hotspot client
   isolation, Pi service binding, and the Pi firewall. A same-SSID indication
   alone does not prove peer reachability. Use Mobile Mode while Wearable Mode
   is disconnected.

## Acceptance on the real phone and Pi

2026-10-19: physical TECNO BG6 hotspot discovery/enrollment/authentication/
settings/Running and retained trust after app replacement/Pi reboot are observed.
Owner confirms clear audio test and real object speech. Laptop pairing and a
typed Ollama reply also pass on this same hotspot. Detection speed remains
unaccepted: the owner's 5 V/2 A supply still produces current under-voltage/
throttling under load. See [exact evidence and remaining gates](HOTSPOT_AND_GEMINI_VERIFICATION_2026-10-19.md).

- With cellular data disabled, connect and authenticate on the hotspot.
- Restart the hotspot and Pi independently. Verify DHCP address changes are
  recovered by discovery or explicitly record the manual-address fallback.
- Test first enrollment, a second phone's rejection, credential persistence,
  phone priority audio, Pi speech fallback after disconnect, and no frame
  upload.
- Repeat with TalkBack and 2× text. Record actual results in
  `docs/PROJECT_STATUS.md`; do not infer hardware success from unit tests.

## Primary sources

- [Android tethering architecture: DHCP for IPv4 clients](https://source.android.com/docs/core/ota/modular-system/tethering)
- [Android Wi-Fi hotspot and device capabilities](https://source.android.com/docs/core/connect/wifi-softap)
- [Android NSD and multicast lock behavior](https://developer.android.com/reference/android/net/nsd/NsdManager)
- [Android local-only hotspot API](https://developer.android.com/develop/connectivity/wifi/localonlyhotspot)
- [Raspberry Pi OS Wi-Fi and NetworkManager setup](https://www.raspberrypi.com/documentation/computers/configuration.html)
- [Raspberry Pi Wi-Fi autoconnect priority and DHCP](https://www.raspberrypi.com/documentation/configuration/wireless/wireless-access-point.md)
- [Android 17 local-network permission migration](https://developer.android.com/privacy-and-security/local-network-permission)
