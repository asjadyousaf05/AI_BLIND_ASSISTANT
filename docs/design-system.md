# Design System

Last reviewed: 2026-07-19

## Purpose

This document translates the Stitch visual reference into a native Flutter design-token baseline. Stitch remains the visual source of truth, but production UI must use native Flutter widgets, local assets, and accessible semantics rather than WebView, CDN Tailwind, remote fonts, or remote images.

## Token Files

Module 3 added or updated these centralized Flutter theme files:

| File | Responsibility |
|---|---|
| `mobile_app/lib/app/theme/app_colors.dart` | Brand, surface, slate, state, and overlay color tokens. |
| `mobile_app/lib/app/theme/app_spacing.dart` | 4 px spacing scale based on Tailwind spacing used by Stitch. |
| `mobile_app/lib/app/theme/app_dimensions.dart` | Touch targets, icon sizes, content widths, and fixed-format UI dimensions. |
| `mobile_app/lib/app/theme/app_radii.dart` | 8, 16, 24, and pill radius tokens from Stitch. |
| `mobile_app/lib/app/theme/app_shadows.dart` | Shadow and primary-glow tokens matching Stitch `shadow-*` patterns. |
| `mobile_app/lib/app/theme/app_icons.dart` | Flutter Material icon aliases for the Material Symbols used in Stitch. |
| `mobile_app/lib/app/theme/app_motion.dart` | Bounded transition timing and active-press scale tokens. |
| `mobile_app/lib/app/theme/app_typography.dart` | Text-role sizes, weights, heights, and normalized letter spacing. |
| `mobile_app/lib/app/theme/app_theme.dart` | Material 3 light/dark theme composition from tokens. |

## Color Tokens

| Design role | Stitch source | Flutter token | Notes |
|---|---|---|---|
| Brand primary | `#25c0f4` | `AppColors.primary` | Cyan-blue used for primary actions, icons, borders, selected states, and alert accents. |
| Primary foreground | `text-background-dark` over primary | `AppColors.onPrimary` = `#06232D` | Dark text on cyan provides accessible button contrast. |
| Light background | `#f5f8f8` | `AppColors.lightBackground` | Main light-mode page background. |
| Dark background | `#101e22` | `AppColors.darkBackground` | Main dark-mode page background. |
| Slate neutral scale | Tailwind `slate-50` through `slate-900` classes | `AppColors.slate*` | Used for cards, borders, muted text, and secondary controls. |
| Success | `emerald-500` | `AppColors.success` = `#10B981` | Used for ready/connected states. |
| Warning | Not explicit as color; warning icon uses primary | `AppColors.warning` = `#F59E0B` | Reserved for estimated medium-risk states in later modules. |
| Error | Error screen uses primary icon plus neutral surface | `AppColors.error` = `#EF4444` | Reserved for failure states; error copy must also be textual. |
| Primary overlays | `primary/5`, `/10`, `/20`, `/30`, `/40` | `AppColors.primaryOverlay*` | Used for status panels, selected states, icon badges, glows, and focus/hover overlays. |

## Typography

Stitch references Lexend from Google Fonts. No Lexend files are currently bundled locally, so Flutter must not depend on the remote font. Module 3 keeps typography centralized and uses Material text styles with Stitch-like size and weight roles. A later module may bundle Lexend locally if license, file source, and asset registration are approved.

| Role | Flutter style | Source pattern |
|---|---|---|
| Hero alert/title | `displayLarge`, 48 px, weight 900 | `text-5xl font-black`, `text-[42px] font-bold` |
| Splash display | `displayMedium`, 42 px, weight 800 | Splash `AI Blind Assistant` title |
| Screen headline | `headlineLarge`, 32 px, weight 800 | Permission/about/page H1 patterns |
| Section headline | `headlineSmall`/`titleLarge`, 22-24 px, weight 700 | Settings, cards, help step headings |
| Body | `bodyLarge`, 16 px, height 1.4 | Permission, mode, and help body copy |
| Button/label | `labelLarge`, 16-18 px, weight 700 | Primary and secondary actions |

Stitch uses `tracking-tight`, `tracking-wide`, and `tracking-widest`. Flutter tokens normalize letter spacing to `0` so text remains readable and avoids clipping at large Android font scales.

## Spacing and Dimensions

The extracted spacing system uses a 4 px base scale:

| Token | Value | Stitch examples |
|---|---:|---|
| `space1` | 4 px | Small dots, inner toggle padding. |
| `space2` | 8 px | `gap-2`, default small gaps. |
| `space3` | 12 px | `gap-3`, badges. |
| `space4` | 16 px | `p-4`, `gap-4`, default page edge on some screens. |
| `space5` | 20 px | Mode-card content padding. |
| `space6` | 24 px | `p-6`, page sections, card padding. |
| `space8` | 32 px | `p-8`, large footer/header spacing. |
| `space16` | 64 px | Prominent control height. |
| `space20` | 80 px | Splash primary action height. |

Important dimension tokens:

| Token | Value | Use |
|---|---:|---|
| `minTouchTarget` | 48 px | Minimum accessible tappable target. |
| `primaryControlHeight` | 56 px | Standard action button. |
| `prominentControlHeight` | 64 px | Major action button. |
| `heroControlHeight` | 80 px | Splash/start primary action. |
| `screenMaxWidth` | 720 px | Upper bound for phone-first content. |
| `narrowContentMaxWidth` | 448 px | Permission/action forms. |
| `mediumContentMaxWidth` | 512 px | Error/about/help content. |

## Shape and Elevation

| Token | Value | Source |
|---|---:|---|
| `AppRadii.defaultRadius` | 8 px | Tailwind `rounded` / `rounded-lg` inner controls. |
| `AppRadii.large` | 16 px | Tailwind `rounded-lg`. |
| `AppRadii.extraLarge` | 24 px | Tailwind `rounded-xl`, dominant card/button shape. |
| `AppRadii.full` | 9999 px | Icon circles, pills, dots, badges. |
| `AppShadows.small` | Low neutral shadow | Stitch `shadow-sm`. |
| `AppShadows.large` | Card/action elevation | Stitch `shadow-lg`, `shadow-xl`. |
| `AppShadows.primaryGlow` | Cyan glow | `shadow-primary/20`, alert icon glow. |

## Motion

Stitch interaction motion is limited to hover transitions, active scale, and pulse indicators:

| Token | Value | Use |
|---|---:|---|
| `AppMotion.fast` | 150 ms | Hover/focus color transition. |
| `AppMotion.standard` | 250 ms | Standard control transition. |
| `AppMotion.slow` | 400 ms | Larger state transition. |
| `AppMotion.pulseCycle` | 1000 ms | Running/searching indicator pulse if enabled. |
| `AppMotion.activeScale` | 0.98 | Major button press state. |
| `AppMotion.strongerActiveScale` | 0.95 | Splash/home large action press state. |

Motion must be decorative only. Screen-reader announcements, audio, and haptics must not depend on visual animation.

## Icon Strategy

Stitch uses Google Material Symbols via a remote font. The native Flutter UI
maps those names to offline Flutter `Icons` aliases through `AppIcons`; future
screen changes must continue using the centralized aliases.

Production UI must use accessible labels for icon-only buttons and must not depend on Google Fonts network loading.

## Component Style Principles

- Prefer native Flutter controls with clear semantics.
- Keep action buttons large and predictable.
- Use selected state through more than color: border, icon, label, and semantic selected state.
- Replace exact-distance copy with risk/proximity categories.
- Keep Raspberry Pi UI visually present but behaviorally deferred until Mobile Mode is stable.
- Replace remote images with local licensed assets or native icon/shape compositions.
- Avoid fixed-height canvases in Flutter; use scrollable, safe-area-aware, text-scale-safe layouts.
