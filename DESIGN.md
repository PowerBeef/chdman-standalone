---
name: Hunky
description: Native macOS CHD queue utility for safe local disc archive workflows.
colors:
  surface: "oklch(18% 0.006 250)"
  surface-raised: "oklch(22% 0.007 250)"
  surface-row: "oklch(20% 0.006 250)"
  surface-sunken: "oklch(16% 0.006 250)"
  hairline: "oklch(34% 0.006 250 / 62%)"
  ink-primary: "oklch(96% 0.004 250)"
  ink-secondary: "oklch(74% 0.005 250)"
  ink-tertiary: "oklch(56% 0.006 250)"
  accent: "oklch(72% 0.105 220)"
  success: "oklch(74% 0.13 145)"
  caution: "oklch(78% 0.12 80)"
  critical: "oklch(66% 0.16 25)"
  redump: "oklch(70% 0.11 285)"
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
  xs: "3px"
  sm: "5px"
  md: "8px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "14px"
  lg: "20px"
components:
  button-primary:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.surface-sunken}"
    rounded: "{rounded.sm}"
    padding: "4px 10px"
    typography: "{typography.label}"
  queue-row:
    backgroundColor: "{colors.surface-row}"
    textColor: "{colors.ink-primary}"
    rounded: "0"
    padding: "12px 16px"
  chip-neutral:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.ink-secondary}"
    rounded: "{rounded.xs}"
    padding: "2px 6px"
---

# Design System: Hunky

## 1. Overview

**Creative North Star: "The Workbench Ledger"**

Hunky should feel like a native Mac workbench for disc archive jobs: dense enough for real batch work, calm enough to trust with original files, and specific enough to make Redump and `chdman` state legible. The interface uses a restrained dark graphite base because users may run long conversions in evening or low-light desk setups, but it should never read as a neon gaming surface.

The system rejects terminal cosplay, decorative motion, bordered drop-target rectangles, uppercase tracked banners, and side-stripe accents. It earns personality through precise state language, compact disc metadata, and careful progress feedback.

**Key Characteristics:**
- Native macOS toolbar and settings behavior.
- Flat-by-default queue rows with 1 pt separators.
- Accent only for primary actions and active running state.
- Severity colors only for verified success, caution, critical errors, and Redump outcomes.
- Monospace only for CRCs, paths, sizes, and raw `chdman` output.

## 2. Colors

The palette is restrained graphite with a small cyan accent and semantic state colors.

### Primary
- **Workbench Cyan** (`oklch(72% 0.105 220)`): Primary run action, active progress, running indicators, and focused operational state.

### Secondary
- **Redump Violet** (`oklch(70% 0.11 285)`): Confirmed Redump catalog matches only. Do not use it as decoration.

### Tertiary
- **Platform Marks** (`oklch` family, reduced chroma): Small platform dots or badges inside row metadata. Never use platform colors as row stripes.

### Neutral
- **Graphite Surface** (`oklch(18% 0.006 250)`): Window background.
- **Raised Graphite** (`oklch(22% 0.007 250)`): Toolbar chips, controls, and grouped settings surfaces.
- **Sunken Graphite** (`oklch(16% 0.006 250)`): Column headers, progress tracks, and compact metadata wells.
- **Quiet Ink** (`oklch(96% 0.004 250)` through `oklch(56% 0.006 250)`): Text hierarchy from primary labels to tertiary metadata.

### Named Rules

**The State Rarity Rule.** Green, amber, red, violet, and cyan appear only when they explain a state or an available action. If a color does not change what the user understands or does next, remove it.

## 3. Typography

**Display Font:** SF Pro (system fallback)
**Body Font:** SF Pro (system fallback)
**Label/Mono Font:** SF Mono only for technical data

**Character:** Native, compact, and unshowy. Type should make filenames and queue states easy to scan without turning the app into a terminal.

### Hierarchy
- **Display** (semibold, 22 px, 1.2): Empty-state headline only.
- **Headline** (semibold, 15 px, 1.25): Queue overview, sheet titles, settings title.
- **Title** (medium or semibold, 13 px, 1.3): Row primary filename and section labels.
- **Body** (regular, 13 px, 1.35): Descriptive copy, modal paragraphs, settings descriptions. Cap prose at 65-75ch where practical.
- **Label** (regular or medium, 10.5-11.5 px, 0 letter spacing): Column headers, chips, row metadata, small controls. Use mixed case.

### Named Rules

**The No Terminal Banner Rule.** No uppercase tracked labels for app chrome, row headers, chips, or empty states.

## 4. Elevation

Hunky uses tonal layering and hairlines, not shadows, for depth. Resting rows are flat. Hover and running states change tone subtly; modal and sheet depth comes from macOS sheet chrome.

### Named Rules

**The Flat Queue Rule.** Queue rows never become cards and never receive side-stripe accents. The row divider is the structure.

## 5. Components

### Buttons
- **Shape:** Small native-radius rectangles (5-6 px) or system bordered buttons.
- **Primary:** Workbench Cyan for Run queue only, with dark text for contrast.
- **Hover / Focus:** Use native focus where possible. Keep custom focus visible and stateful.
- **Secondary / Ghost:** Neutral icon or text buttons, visible at rest, with tooltips for icon-only controls.

### Chips
- **Style:** Neutral graphite fill, mixed-case or short uppercase acronyms with no letter spacing.
- **State:** Platform badges use a small colored dot plus text. Format chips are quiet metadata, not status.

### Cards / Containers
- **Corner Style:** Avoid cards in the queue. Settings groups and transient summaries may use 8 px radius.
- **Background:** Use raised or sunken graphite only when grouping reduces scanning cost.
- **Shadow Strategy:** No decorative shadows.
- **Border:** 1 pt hairlines only.
- **Internal Padding:** 8-16 px depending on density.

### Inputs / Fields
- **Style:** Use native macOS controls when a setting is interactive.
- **Focus:** Preserve system focus rings.
- **Error / Disabled:** Disabled controls should be obvious and should not imply inactive preferences affect runtime.

### Navigation
- **Style:** Native unified toolbar. Add, output, run, stop, overflow, and summary should sit in toolbar chrome, not a custom in-window titlebar.

### Queue Rows

Rows carry the product. Filename and status are primary; audit and action are secondary until they require attention. Keep actions visible, keep warnings readable, and collapse detailed reference lists behind a disclosure.

## 6. Do's and Don'ts

### Do:
- **Do** keep Hunky dark-only for v1 with a restrained graphite palette.
- **Do** use accent for Run queue, progress, and active running state.
- **Do** use severity colors only for confirmed success, caution, critical failure, and Redump findings.
- **Do** keep queue rows flat with 1 pt separators.
- **Do** keep icon-only controls labeled with tooltips and accessibility labels.

### Don't:
- **Don't** use side-stripe borders greater than 1 px as row, card, callout, or alert accents.
- **Don't** use uppercase tracked headers or chip text.
- **Don't** use bordered drop-target rectangles as the empty state.
- **Don't** use decorative spin, shimmer, glow, or shadow unless it conveys active work.
- **Don't** show settings controls that persist but do not affect runtime behavior.
