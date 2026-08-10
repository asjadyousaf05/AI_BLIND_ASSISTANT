# Asset Inventory

Last reviewed: 2026-08-06

## Production Model Assets

| Asset | Size | SHA-256 | Status |
|---|---:|---|---|
| `mobile_app/assets/models/yolov8n_float32.tflite` | 12,765,643 bytes | `57a4e7d1aad385ed2d140d11da5406c1f0931d0696b1cc0dc73703051f545112` | Bundled, verified, registered through `assets/models/`. |
| `mobile_app/assets/models/coco_labels.txt` | 80 labels | `bd17f1ee35d5f3c862a4894605855abbb9dda4b0621fdb0ac4c2c8c7bb7e730a` | Bundled in official COCO order. |
| `mobile_app/assets/models/model_metadata.json` | Generated metadata | `0bc9389fb1756f51aa23b22d27da85cab1f4f31ff5b716ebc1567084ffba9d96` | Bundled and checked against native tensor metadata. |

The runtime never downloads these assets. Provenance and license details are in
`docs/model-integration.md`.

## Local Stitch Reference Assets

| Screen ID | Asset | Type | Dimensions | Production status |
|---|---|---|---|---|
| SCR-001 | `stitch/splash_screen/screen.png` | PNG reference | 706 x 1600 | Design reference only. |
| SCR-002 | `stitch/permissions_screen/screen.png` | PNG reference | 706 x 1600 | Design reference only. |
| SCR-003 | `stitch/mode_selection_screen/screen.png` | PNG reference | 706 x 1600 | Design reference only. |
| SCR-004 | `stitch/home_screen/screen.png` | PNG reference | 706 x 1600 | Design reference only. |
| SCR-005 | `stitch/assistance_running_screen/screen.png` | PNG reference | 706 x 1600 | Design reference only. |
| SCR-006 | `stitch/connection_screen/screen.png` | PNG reference | 706 x 1600 | Design reference only. |
| SCR-007 | `stitch/connection_error_screen/screen.png` | PNG reference | 706 x 1600 | Design reference only. |
| SCR-008 | `stitch/settings_screen/screen.png` | PNG reference | 706 x 1600 | Design reference only. |
| SCR-009 | `stitch/help_screen/screen.png` | PNG reference | 706 x 1600 | Design reference only. |
| SCR-010 | `stitch/about_screen/screen.png` | PNG reference | 706 x 1600 | Design reference only. |

## Module 3 Rendered Reference Assets

`docs/rendered-stitch/` contains 393 x 852 PNG screenshots for all ten Stitch pages. These files are documentation artifacts only and are not registered in `pubspec.yaml`.

## Remote Image References In Stitch

| Screen ID | Source file | Purpose in Stitch | Production action |
|---|---|---|---|
| SCR-002 | `permissions_screen/code.html` | Abstract camera lens background. | Replace with local licensed image or native icon/shape composition. |
| SCR-003 | `mode_selection_screen/code.html` | Mobile Mode card image. | Replace with local licensed image or app-owned illustration. |
| SCR-003 | `mode_selection_screen/code.html` | Raspberry Cap card image. | Replace with local licensed image or app-owned wearable illustration. |
| SCR-006 | `connection_screen/code.html` | Device thumbnail image. | Replace with local app-owned Pi/cap visual or icon. |
| SCR-010 | `about_screen/code.html` | Logo background image. | Replace with production app icon/logo asset. |

All remote image references use `https://lh3.googleusercontent.com/aida-public/...`. They must not become production runtime dependencies.

## Font References

| Font | Source | Status |
|---|---|---|
| Lexend | Google Fonts CSS in all Stitch HTML files | Not bundled locally. Treat as design reference only until font files and license are approved. |
| Material Symbols Outlined | Google Fonts CSS in all Stitch HTML files | Not bundled locally. Flutter Material icons are preferred for production. |

No local `.ttf`, `.otf`, `.woff`, or `.woff2` files were found.

## Icon References

Stitch uses these Material Symbol names:

`accessibility_new`, `account_circle`, `arrow_back`, `arrow_forward`, `bluetooth`, `bluetooth_searching`, `cell_tower`, `check_circle`, `cloud_off`, `directions_walk`, `grid_view`, `headset_mic`, `help`, `history`, `info`, `link`, `memory`, `menu`, `notifications_active`, `photo_camera`, `play_arrow`, `play_circle`, `refresh`, `sensors`, `settings`, `settings_voice`, `signal_cellular_1_bar`, `signal_cellular_3_bar`, `signal_cellular_4_bar`, `smartphone`, `stop`, `stop_circle`, `swap_horiz`, `visibility`, `volume_up`, `warning`, `wifi_off`.

Module 3 added `AppIcons` aliases for Flutter Material icon equivalents. Some exact Material Symbol variants may not exist in Flutter Material icons, so Module 4 should prioritize semantic meaning over exact glyph matching.

## Android Launcher Assets

Existing generated Flutter launcher icons remain under:

- `mobile_app/android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
- `mobile_app/android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
- `mobile_app/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
- `mobile_app/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
- `mobile_app/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`

These are default/generated assets and are not final production branding.

## Missing Production Assets

| Missing asset | Needed by | Status |
|---|---|---|
| Production app icon and launch branding | Release/demo polish | Missing. |
| Local replacement for Lexend, if selected | Final UI typography | Missing. |
| Local replacement for remote mode/permission/Pi/about images | Module 4 UI | Missing. |
| Raspberry Pi-side scripts/assets | Future Pi modules | Missing by design in Module 3. |

## Broken Or Risky Asset References

- Remote `lh3.googleusercontent.com` images are unavailable offline unless replaced.
- Google Fonts URLs are unavailable offline unless fonts/icons are bundled locally.
- HTML `data-alt` attributes on background `div` elements are not real accessible image alternatives.
- Stitch screenshots are source references, not production assets and should not be embedded as the app UI.
