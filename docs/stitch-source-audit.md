# Stitch Source Audit

Last reviewed: 2026-07-19

## Summary

The Stitch design reference is stored under `stitch/`. It contains ten screen directories. Each directory contains one `code.html` file and one `screen.png` reference image. No standalone Stitch CSS, JavaScript, JSON, SVG, font, model, label, Python, or Raspberry Pi files were found.

Original Stitch files were not edited during Module 3. New rendered reference screenshots were written only to `docs/rendered-stitch/`.

## Source Directories

| Directory | Files | Notes |
|---|---:|---|
| `stitch/about_screen/` | 2 | About page HTML and 706 x 1600 PNG reference. |
| `stitch/assistance_running_screen/` | 2 | Assistance-active page HTML and 706 x 1600 PNG reference. |
| `stitch/connection_error_screen/` | 2 | Connection-failed page HTML and 706 x 1600 PNG reference. |
| `stitch/connection_screen/` | 2 | Raspberry Cap connection page HTML and 706 x 1600 PNG reference. |
| `stitch/help_screen/` | 2 | Help carousel page HTML and 706 x 1600 PNG reference. |
| `stitch/home_screen/` | 2 | Home page HTML and 706 x 1600 PNG reference. |
| `stitch/mode_selection_screen/` | 2 | Mode-selection page HTML and 706 x 1600 PNG reference. |
| `stitch/permissions_screen/` | 2 | Camera-permission page HTML and 706 x 1600 PNG reference. |
| `stitch/settings_screen/` | 2 | Settings page HTML and 706 x 1600 PNG reference. |
| `stitch/splash_screen/` | 2 | Splash page HTML and 706 x 1600 PNG reference. |

Additional non-source metadata files found: `.DS_Store` at workspace root and `stitch/.DS_Store`.

## HTML Pages

| Screen ID | HTML file | Lines | HTML title | Primary purpose |
|---|---|---:|---|---|
| SCR-001 | `stitch/splash_screen/code.html` | 83 | `AI Blind Assistant - Welcome` | Welcome/startup entry. |
| SCR-002 | `stitch/permissions_screen/code.html` | 98 | `Permissions - Camera Access` | Camera permission rationale and action. |
| SCR-003 | `stitch/mode_selection_screen/code.html` | 110 | `AI Blind Assistant - Mode Selection` | Mobile versus Raspberry Cap selection. |
| SCR-004 | `stitch/home_screen/code.html` | 86 | `AI Blind Assistant` | Current mode/status and assistance actions. |
| SCR-005 | `stitch/assistance_running_screen/code.html` | 88 | `Assistance Active` | Running alert and stop controls. |
| SCR-006 | `stitch/connection_screen/code.html` | 104 | `Raspberry Cap - Connection` | Raspberry Pi wearable connection. |
| SCR-007 | `stitch/connection_error_screen/code.html` | 87 | `Connection Failed` | Raspberry Pi connection failure. |
| SCR-008 | `stitch/settings_screen/code.html` | 118 | Missing | Feedback and sensitivity settings. |
| SCR-009 | `stitch/help_screen/code.html` | 112 | Missing | Quick-start guide carousel. |
| SCR-010 | `stitch/about_screen/code.html` | 108 | Missing | About, offline, and accessibility summary. |

## CSS and JavaScript

| Category | Finding | Production migration action |
|---|---|---|
| Standalone CSS files | None found. | Recreate styles through Flutter theme tokens and widgets. |
| Standalone JavaScript files | None found. | No JavaScript should be migrated into Flutter. |
| Inline CSS | Every page defines `body { min-height: max(884px, 100dvh); }`; several pages add Lexend font-family and scrollbar hiding. | Replace fixed canvas assumptions with responsive Flutter layouts. |
| Inline JavaScript | Every page defines a small `tailwind.config` object. | Extract the values into Flutter tokens; do not run Tailwind at app runtime. |
| CDN script | Every page loads Tailwind from `https://cdn.tailwindcss.com?plugins=forms,container-queries`. | Prohibited for production UI; native Flutter must not depend on CDN. |

## Shared Tailwind Tokens Found

All ten pages define the same core extension:

| Token | Value | Flutter token |
|---|---|---|
| `primary` | `#25c0f4` | `AppColors.primary` |
| `background-light` | `#f5f8f8` | `AppColors.lightBackground` |
| `background-dark` | `#101e22` | `AppColors.darkBackground` |
| `fontFamily.display` | `Lexend` | Documented as design reference; not bundled yet. |
| `borderRadius.DEFAULT` | `0.5rem` / 8 px | `AppRadii.defaultRadius` |
| `borderRadius.lg` | `1rem` / 16 px | `AppRadii.large` |
| `borderRadius.xl` | `1.5rem` / 24 px | `AppRadii.extraLarge` |
| `borderRadius.full` | `9999px` | `AppRadii.full` |

## Rendering Evidence

Local rendering was attempted with Google Chrome headless at a 393 x 852 Android-style viewport. All ten pages produced PNG screenshots in `docs/rendered-stitch/`, but Chrome did not exit cleanly after capture and required forced termination. Therefore the render result is recorded as "rendered with forced termination", not a clean automated render pass.

| Screen ID | Rendered artifact | Result |
|---|---|---|
| SCR-001 | `docs/rendered-stitch/splash_screen-393x852.png` | Rendered with forced termination. |
| SCR-002 | `docs/rendered-stitch/permissions_screen-393x852.png` | Rendered with forced termination. |
| SCR-003 | `docs/rendered-stitch/mode_selection_screen-393x852.png` | Rendered with forced termination. |
| SCR-004 | `docs/rendered-stitch/home_screen-393x852.png` | Rendered with forced termination. |
| SCR-005 | `docs/rendered-stitch/assistance_running_screen-393x852.png` | Rendered with forced termination. |
| SCR-006 | `docs/rendered-stitch/connection_screen-393x852.png` | Rendered with forced termination. |
| SCR-007 | `docs/rendered-stitch/connection_error_screen-393x852.png` | Rendered with forced termination. |
| SCR-008 | `docs/rendered-stitch/settings_screen-393x852.png` | Rendered with forced termination. |
| SCR-009 | `docs/rendered-stitch/help_screen-393x852.png` | Rendered with forced termination. |
| SCR-010 | `docs/rendered-stitch/about_screen-393x852.png` | Rendered with forced termination. |

## External References

| Reference type | Location | Offline conflict |
|---|---|---|
| Tailwind CDN | All Stitch HTML files | Production Flutter must not load UI framework code from the network. |
| Google Fonts: Lexend | All Stitch HTML files | Production Flutter must bundle any selected font locally or use system fonts. |
| Google Fonts: Material Symbols Outlined | All Stitch HTML files | Production Flutter should use Flutter Material icons or a bundled icon font. |
| Remote images from `lh3.googleusercontent.com/aida-public/...` | Permissions, mode selection, connection, and about screens | Must be replaced by local licensed assets or native icon/shape compositions. |

## Content Conflicts Identified

| Source | Conflict | Resolution for Flutter migration |
|---|---|---|
| `permissions_screen` | Copy says the camera is for taking/sharing photos and profile personalization. | Replace with local assistive camera-detection rationale only. |
| `mode_selection_screen` | Mobile Mode copy mentions text recognition. | Remove OCR/text recognition from first production version unless later approved. |
| `assistance_running_screen` | Alert says "3 meters ahead". | Use estimated risk/proximity wording, not exact distance. |
| `connection_error_screen` | Copy says to check internet connection and shows `ERR_NETWORK_TIMED_OUT`. | Use local wearable connection copy and local error taxonomy. |
| `about_screen` | Uses `Lumina AI` and `Version 2.4.0`. | Use `AI Blind Assistant` and app metadata. |
| `about_screen` | Bottom nav includes History. | Do not expose History unless a future module adds that feature. |

## Preservation Evidence

- `find stitch -maxdepth 3 -type f -print` confirmed the original ten `code.html` files and ten `screen.png` files remain present.
- SHA-256 hashes were captured for all Stitch files during Module 3 for audit traceability.
- No files under `stitch/` were modified by this module.

