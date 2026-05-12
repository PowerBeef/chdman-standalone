---
name: Hunky
description: Native macOS 26 Liquid Glass CHD utility with subtle optical-disc cues.
colors:
  surface: "oklch(10.5% 0.032 245)"
  sidebar: "oklch(24% 0.040 235 / 34%)"
  glass-panel: "oklch(42% 0.070 218 / 24%)"
  glass-deep: "oklch(26% 0.050 238 / 28%)"
  glass-row: "oklch(24% 0.032 235 / 24%)"
  glass-control: "oklch(48% 0.052 232 / 22%)"
  hairline: "oklch(70% 0.070 215 / 34%)"
  ink-primary: "oklch(96% 0.006 250)"
  ink-secondary: "oklch(84% 0.012 250)"
  ink-tertiary: "oklch(72% 0.014 250)"
  accent: "oklch(78% 0.155 210)"
  success: "oklch(74% 0.130 145)"
  caution: "oklch(76% 0.140 55)"
  critical: "oklch(66% 0.160 25)"
  redump: "oklch(72% 0.130 285)"
typography:
  title:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "15px"
    fontWeight: 600
    lineHeight: 1.25
    letterSpacing: "0"
  body:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.35
    letterSpacing: "0"
  label:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "11.5px"
    fontWeight: 400
    lineHeight: 1.25
    letterSpacing: "0"
  mono:
    fontFamily: "SF Mono, ui-monospace, monospace"
    fontSize: "10.5px"
    fontWeight: 400
    lineHeight: 1.3
    letterSpacing: "0"
rounded:
  sm: "8px"
  md: "12px"
  lg: "18px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "14px"
  lg: "22px"
components:
  primary-action:
    material: "glassProminent"
    tint: "{colors.accent}"
    typography: "{typography.label}"
  queue-row:
    material: "Liquid Glass"
    tint: "{colors.glass-row}"
    separator: "{colors.hairline}"
  sidebar-group:
    material: "Liquid Glass"
    tint: "{colors.glass-control}"
---

# Design System: Hunky

## 1. Overview

**Creative North Star: "Native Liquid Glass Disc Utility"**

Hunky should feel like the generated reference mockup: a first-party macOS 26 SwiftUI utility for local disc archive work with a titled unified toolbar, queue controls/search in chrome, a left Disc Bay sidebar, and a right table-like queue list. Liquid Glass surfaces stay quiet enough for filenames, paths, audit results, and progress to read immediately.

The app can still wink at optical game preservation through small disc glyphs, blue status dots, and a Save Path memory-card hint. Those details are secondary. Hunky is not a console dashboard, game launcher, arcade UI, or custom skinned window.

**Key Characteristics:**
- Full-window split surface: Disc Bay and Save Path on the left, queue rows on the right.
- Unified toolbar owns title, Add, Run/Stop, More, queue filter affordance, and search.
- macOS 26 Liquid Glass is the surface system; do not add legacy visual shims.
- Blue-cyan is reserved for primary actions, focus, and running progress.
- Queue rows behave like a list/table: filename/source path, status, and progress/result affordance.
- Generated art remains bundled but should sit near zero opacity or outside the primary hierarchy.
- Safety-critical copy stays literal and unplayful.

## 2. Visual Language

### Theme Scene

A Mac user is cleaning up a folder of disc images. They need a calm utility that makes file intake, output destination, audit warnings, and queue progress obvious. The subtle gaming influence comes from the media itself: optical-disc icons, tiny status lights, and CHD archive language.

### Assets

- **Emblem:** keep bundled for rare supporting surfaces, but do not place it in the main hierarchy.
- **Texture:** keep behind glass at near-zero opacity. It should be felt only as depth, never read as vents, scanlines, or decoration.

### Color Strategy

Use dark graphite blue as the window base. Liquid Glass panels get a soft blue tint. Cyan is the only primary accent. Green, amber, red, and violet remain semantic and rare: success, caution, critical, and Redump state.

## 3. Typography

Use SF Pro for all interface text. Use SF Mono only for paths, CRCs, sizes, raw `chdman` output, and other machine-readable telemetry.

### Hierarchy
- **Screen title** (22 px, bold): Queue.
- **Section title** (15 px, semibold): Disc Bay, Save Path.
- **Row title** (15 px, semibold): filenames.
- **Body** (13 px, regular): guidance and sheet explanations.
- **Label** (10.5-12 px): table headers, metadata, footer state.
- **Mono** (10.5 px): paths, CRCs, sizes, elapsed time, raw logs.

## 4. Components

### Main Shell

The window uses a persistent split layout as the content surface directly under the unified toolbar. Do not place the split view inside a floating inset card or add an outer panel border; the window/content clipping is the frame. The left sidebar owns intake, Save Path, and supported formats. The right queue area owns warnings, rows, and run summaries. The empty queue state appears inside the queue table area, not as a centered landing-page hero.

### Toolbar

Keep the macOS unified toolbar native and reference-matched: visible `Hunky` title, Add, Run/Stop, More, queue filter affordance, and search. Do not re-hide Run/Stop or search inside the content area.

### Buttons

Use `.glassProminent` only for primary actions such as Run Queue and Start Anyway. Add Files is a wide, quiet glass control in the sidebar and should not show an always-on cyan outline. Secondary controls stay compact and native.

### Queue Rows

Rows should read as a native list with clear separators and the reference columns: `Name`, `Status`, `Progress`. Avoid ornate borders, bevel overlays, heavy chips, large badges, and decorative slot framing. Default row content should show filename/source identity, concise status, and progress/result affordance. Put expanded references, action changes, logs, and errors behind disclosure or context actions.

### Ready Check

Ready Check remains the preflight language. Critical issues block with a sheet; caution-only issues surface inline first. Copy must plainly state missing references, size mismatches, CRC mismatches, and output risks.

### Sheets And Settings

Let macOS render sheet and settings chrome. Use grouped native forms, simple Liquid Glass inner groups only when they improve clarity, and mono only for raw output or paths.

## 5. Do's And Don'ts

### Do:
- **Do** make the UI feel like a native SwiftUI Mac utility first.
- **Do** use subtle blue Liquid Glass depth without reducing contrast.
- **Do** keep output destination and collision safety visible.
- **Do** keep row scanning efficient at minimum width and wide sizes.
- **Do** label icon-only controls with help and accessibility labels.
- **Do** honor Reduce Motion for shimmer, pulse, and progress-ring movement.

### Don't:
- **Don't** use console-dashboard structure, arcade neon, controller glyphs, fake hardware panels, or brand-infringing console marks.
- **Don't** rename core actions into game verbs.
- **Don't** use large decorative art in the main layout.
- **Don't** fake glass with custom blur stacks, heavy glows, or opaque cards.
- **Don't** let texture, tint, or animation compete with filenames and warnings.
