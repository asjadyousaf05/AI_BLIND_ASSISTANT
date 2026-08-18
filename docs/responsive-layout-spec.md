# Responsive Layout Specification

Last reviewed: 2026-07-19

## Source Layout Findings

Stitch pages are designed as tall phone canvases. Each HTML file includes `min-height: max(884px, 100dvh)`, and most pages use `h-screen`, `min-h-screen`, `overflow-hidden`, fixed icon sizes, fixed action heights, and fixed footer/header bands.

This creates a clear visual reference, but native Flutter migration must not rely on a single fixed 884 px height. Large Android text, display-size settings, notches, navigation bars, landscape orientation, and smaller phones require adaptive layout.

## Rendered Reference Viewport

All ten Stitch pages produced reference screenshots at 393 x 852 px in `docs/rendered-stitch/`. Chrome required forced termination after writing each screenshot, so the screenshots are useful visual artifacts but not proof of a clean automated browser test.

## Flutter Breakpoints

| Class | Width | Intended behavior |
|---|---:|---|
| Compact phone | `<= 360 px` | Single-column content, reduced decorative image height, scroll enabled. |
| Standard phone | `361-430 px` | Match Stitch proportions closely; single-column layout. |
| Large phone/fold narrow pane | `431-600 px` | Center content with max-width constraints and maintain large touch targets. |
| Tablet/desktop preview | `> 600 px` | Center phone-first content up to `AppDimensions.screenMaxWidth`; avoid stretched buttons/cards. |

## General Layout Rules

- Use `SafeArea` around page-level layouts.
- Use `LayoutBuilder` and `ConstrainedBox` for content width.
- Prefer `SingleChildScrollView` or slivers where text can grow.
- Do not use `overflow-hidden` equivalents that clip content at large text scales.
- Keep primary actions near the bottom for phone ergonomics, but allow them to move below content when text grows.
- Use stable dimensions for icon buttons, dots, toggles, mode cards, and navigation items.
- Avoid relying on decorative backgrounds for comprehension.

## Screen-Level Responsive Notes

| Screen ID | Stitch layout | Flutter migration rule |
|---|---|---|
| SCR-001 | Centered hero and fixed bottom action. | Keep hero centered; allow text/action to scroll on compact screens. |
| SCR-002 | Square illustration, centered copy, fixed footer. | Reduce illustration before clipping text; footer buttons remain full width. |
| SCR-003 | Two stacked cards split vertically. | Use two cards stacked on phones; on very short screens, reduce image ratio and scroll. |
| SCR-004 | Two-column status grid and large vertical actions. | Keep status cards in two columns only if each remains readable; collapse if needed. |
| SCR-005 | Large alert panel with huge uppercase text. | Scale alert typography through text roles and allow wrapping; never hide stop control. |
| SCR-006 | Large connection visual, device card, footer actions, bottom nav. | Prioritize connection status, actions, then nav; reduce decorative visual first. |
| SCR-007 | Centered error illustration and footer actions. | Error message and recovery actions must remain visible with large text. |
| SCR-008 | Three-column sensitivity selector. | At large text or compact width, wrap sensitivity choices or use vertical radio cards. |
| SCR-009 | Horizontal full-width carousel. | Add explicit page controls and keep each step scrollable if text grows. |
| SCR-010 | Centered identity, feature cards, bottom nav. | Safety/about text should scroll; unsupported History nav must not occupy space. |

## Text Scaling

Flutter migration must test at least:

- Text scale 1.0.
- Text scale 1.3.
- Text scale 2.0 for representative screens.

Acceptance criteria:

- No important text clips.
- Primary controls remain reachable.
- Screen reader labels remain meaningful.
- Bottom navigation does not overlap content.
- Alert title and message wrap cleanly.

## Orientation

The FYP target is Android phone portrait first. Landscape should not crash or hide recovery actions. For landscape, Module 4 can center content in a scrollable column rather than designing a separate landscape-first layout.

