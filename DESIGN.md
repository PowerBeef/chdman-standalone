---
name: Hunky
description: Blue Liquid Glass optical-console macOS CHD workbench for safe local disc archive workflows.
colors:
  surface: "oklch(10.5% 0.032 245)"
  glass-panel: "oklch(43% 0.105 218 / 34%)"
  glass-deep: "oklch(28% 0.085 230 / 38%)"
  glass-slot: "oklch(35% 0.09 222 / 34%)"
  glass-control: "oklch(50% 0.11 212 / 28%)"
  hairline: "oklch(70% 0.07 215 / 34%)"
  ink-primary: "oklch(96% 0.006 250)"
  ink-secondary: "oklch(78% 0.012 250)"
  ink-tertiary: "oklch(60% 0.014 250)"
  accent: "oklch(78% 0.155 210)"
  success: "oklch(75% 0.14 145)"
  caution: "oklch(79% 0.14 80)"
  critical: "oklch(66% 0.17 25)"
  redump: "oklch(72% 0.13 285)"
typography:
  title:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "15px"
    fontWeight: 700
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
    fontWeight: 500
    lineHeight: 1.25
    letterSpacing: "0"
  mono:
    fontFamily: "SF Mono, ui-monospace, monospace"
    fontSize: "10.5px"
    fontWeight: 400
    lineHeight: 1.3
    letterSpacing: "0"
rounded:
  xs: "4px"
  sm: "7px"
  md: "10px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "14px"
  lg: "20px"
components:
  primary-action:
    material: "glassProminent"
    tint: "{colors.accent}"
    textColor: "{colors.surface}"
    rounded: "{rounded.sm}"
    padding: "5px 12px"
    typography: "{typography.label}"
  queue-slot:
    material: "Liquid Glass"
    tint: "{colors.glass-slot}"
    textColor: "{colors.ink-primary}"
    rounded: "{rounded.md}"
    padding: "12px 14px"
  panel:
    material: "Liquid Glass"
    tint: "{colors.glass-panel}"
    textColor: "{colors.ink-primary}"
    rounded: "{rounded.md}"
    padding: "14px"
---

# Design System: Hunky

## 1. Overview

**Creative North Star: "Blue Liquid Console Workbench"**

Hunky should feel like a late optical-console service bay rendered through macOS 26 Liquid Glass: tactile enough to be fun, precise enough to trust with original files, and dense enough for real batch work. The app uses blue-cyan refractive panels, subtle console texture, small LEDs, disc bay language, and BIOS-style ready checks, but it keeps all safety-critical copy literal.

The system rejects brand-infringing console marks, casino-neon arcade styling, novelty labels on destructive actions, side-stripe accents, oversized empty-state heroes, and decorative motion that does not explain active work.

**Key Characteristics:**
- Persistent two-zone workbench: Disc Bay for intake and Save Path, Queue Deck for jobs.
- macOS 26 Liquid Glass is the primary surface system. Hunky does not carry a macOS 14 visual fallback.
- Generated emblem and subtle texture sit behind glass as atmosphere, not content.
- Queue rows read as glass job slots with platform, audit, action, progress, and output controls.
- Blue-cyan is visible and playful, but reserved for Start, active progress, running indicators, and focused operational state.
- Green, amber, red, and violet are reserved for real outcomes and Redump state.
- Monospace only for CRCs, paths, sizes, ETA, throughput, and raw `chdman` output.

## 2. Visual Language

### Theme Scene

A preservation hobbyist is batch-converting disc images at night on a Mac running macOS 26, with a game console open on the desk and a folder of dumps ready to verify. The dark optical-console workbench is forced by the scene, and Liquid Glass makes it feel luminous, blue, and tactile rather than heavy.

### Assets

- **Console emblem:** optical disc tray plus memory-card silhouette, no text, no real console logos. Use in the Disc Bay and rare explanatory surfaces only.
- **Workbench texture:** low-contrast graphite plastic with vents, panel seams, screw details, and scanline grain. Use behind Liquid Glass with low opacity so text remains first.

### Color Strategy

Committed product palette. Deep blue carries the window backdrop; blue-cyan Liquid Glass carries panels, slots, chips, and primary actions. Amber, red, green, and violet remain semantic and rare.

## 3. Typography

Use SF Pro for all UI. Use SF Mono only for telemetry and raw process output.

### Hierarchy
- **Deck Title** (15 px, bold): Disc Bay, Queue Deck, Ready Check.
- **Slot Title** (13 px, semibold): filenames and row primary labels.
- **Body** (13 px, regular): helper copy and sheet explanations, capped near 65-75ch.
- **Label** (10.5-11.5 px, medium): badges, section metadata, row labels, footer state.
- **Mono** (10.5 px): paths, CRCs, sizes, elapsed time, raw logs.

### Named Rules

**Literal Controls Rule.** Game-flavored section names are welcome; action buttons and warnings stay literal.

## 4. Components

### Workbench Shell

The main window always has a Disc Bay panel and a Queue Deck panel. Both are Liquid Glass surfaces grouped in one `GlassEffectContainer`. Empty state lives inside the Queue Deck, not as a centered hero. Disc Bay owns file intake and Save Path. Queue Deck owns jobs, ready checks, and run summaries.

### Buttons

Primary action uses `.glassProminent` with the blue-cyan accent and is reserved for Add, Run queue, Start Anyway, or active progress. Secondary buttons stay native and compact. Destructive or critical actions use red only when they are real.

### Queue Slots

Rows are rounded optical-console job slots made from blue-tinted Liquid Glass, not flat ledger rows. Use a disc/archive icon or progress ring at the left, filename as the strongest text, platform/format badges below, Ready Check status in the audit column, literal action controls, and visible result controls.

### Ready Check

Preflight is called Ready Check. Critical issues block with a sheet; caution-only issues surface inline first. Copy can mention discs and slots, but must plainly state missing references, wrong sizes, CRC mismatches, and risk.

### Settings

Do not ship a Settings window just to restate runtime facts. Keep Save Path in the Disc Bay and Queue menu. Bring Settings back only when there are real user-configurable preferences that affect runtime.

### Platform

Hunky targets macOS 26.0+ for native Liquid Glass. Do not add compatibility shims for earlier macOS versions unless the product target changes.

## 5. Do's and Don'ts

### Do:
- **Do** keep the app dark-only with a blue Liquid Glass optical-console palette.
- **Do** use texture and emblem as low-pressure atmosphere behind glass.
- **Do** make output destination and collision safety visible.
- **Do** keep queue rows dense enough for batch scanning.
- **Do** label icon-only controls with tooltips and accessibility labels.
- **Do** honor Reduce Motion for shimmer, pulse, and progress-ring movement.

### Don't:
- **Don't** use real console logos, controller-button glyphs that imply a specific brand, or trademarked hardware silhouettes.
- **Don't** rename core actions into jokes or game verbs that obscure behavior.
- **Don't** use side-stripe borders greater than 1 px as accents.
- **Don't** fake glass with custom blur stacks, gradient text, centered landing-page empty states, or repeated decorative card grids.
- **Don't** let texture, glow, or art reduce text contrast.
