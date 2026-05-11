# AGENTS.md

This file provides guidance to coding agents working in this repository.

It applies to the entire repository. Hunky is a native macOS SwiftUI app that
bundles `chdman` for CHD disk-image workflows.

## Project Summary

Hunky is an Apple Silicon, macOS 26.0+ SwiftUI front end for MAME's `chdman`.
The app is intentionally self-contained: users should be able to drag the app
to `/Applications` and convert, extract, inspect, or verify CHDs without
installing Homebrew, MAME, or command-line tools.

The main product surface is the Swift app in `app/`. The root `CMakeLists.txt`
and `scripts/fetch_sources.sh` are for reconstructing a standalone `chdman`
from MAME sources; they are not part of the normal app build.

## Repository Layout

- `README.md`: user-facing project overview, install/build notes, and binary
  provenance.
- `app/project.yml`: XcodeGen project spec. This is the source of truth for
  the app project.
- `app/Hunky.xcodeproj`: generated project. Regenerate it from `project.yml`
  instead of hand-editing it.
- `app/Sources/Hunky/HunkyApp.swift`: SwiftUI app entry point, window setup,
  and `Settings` scene for the preferences window.
- `app/Sources/Hunky/Core/`: app model, queue, disk inspection, Redump lookup,
  CRC32, `chdman` process execution, `AppSettings` (UserDefaults persistence),
  and `AppIntegration` (notifications, dock badge, sound).
- `app/Sources/Hunky/Views/`: SwiftUI views organized by responsibility:
  - `ContentView.swift`: main workbench shell (~340 lines)
  - `Panels/DiscBayPanel.swift`, `Panels/QueueDeckPanel.swift`
  - `Sheets/TextOutputSheet.swift`, `Sheets/PreflightConfirmationSheet.swift`,
    `Sheets/CompletedRunChip.swift`
  - `Helpers/FilePicker.swift`, `Helpers/StatusBanner.swift`
  - `Settings/SettingsView.swift`: native macOS preferences window (⌘,)
- `app/Resources/chdman`: bundled arm64 `chdman` executable.
- `app/Resources/libSDL3.0.dylib`: bundled runtime dependency for `chdman`.
- `app/Resources/Art/`: bundled generated art for the retro console workbench,
  including the emblem and low-contrast console texture.
- `app/Resources/redump/*.dat.gz`: bundled gzipped Redump DAT catalogs. Hunky
  currently ships PS1 (`psx`), Sega Saturn (`saturn`), and Sega Dreamcast
  (`dreamcast`) DATs for offline verification.
- `vendor/chdman/`: tracked copy of the bundled `chdman` binary and SDL dylib,
  kept as the binary source of truth.
- `scripts/fetch_sources.sh`: helper for fetching selected MAME source files
  and third-party dependencies for the standalone CMake build.

## Build And Verification Commands

Prerequisites: Xcode with the macOS 26 SDK and `xcodegen`
(`brew install xcodegen`). No SPM, CocoaPods, or other package dependencies.

Run app commands from `app/` unless noted otherwise.

```bash
xcodegen generate
xcodebuild -project Hunky.xcodeproj -scheme Hunky -configuration Debug -destination 'platform=macOS,arch=arm64' build
xcodebuild -project Hunky.xcodeproj -scheme Hunky -configuration Release -destination 'platform=macOS,arch=arm64' build
xcodebuild -project Hunky.xcodeproj -scheme Hunky -destination 'platform=macOS,arch=arm64' test
```

Run a single test by appending `-only-testing:HunkyTests/<Class>/<method>` to
the `test` invocation. Existing suites live in `app/Tests/HunkyTests/`:
`CueSheetTests`, `DiscAuditTests`, `QueueControllerTests`, `RedumpAuditTests`.

Useful inspection commands from the repository root:

```bash
xcodebuild -list -project app/Hunky.xcodeproj
file app/Resources/chdman app/Resources/libSDL3.0.dylib
otool -L app/Resources/chdman
app/Resources/chdman
```

For behavior changes, run the test command when possible; for queue, process,
or UI changes, also do a manual smoke test with small sample `.cue`, `.gdi`,
`.iso`, or `.chd` files when available.

## Project Generation Rules

- Treat `app/project.yml` as authoritative.
- Do not manually edit `app/Hunky.xcodeproj/project.pbxproj` unless the user
  explicitly asks for a generated-project patch. Change `project.yml` and run
  `xcodegen generate`.
- Keep bundle resources declared in `project.yml`. If adding resources, make
  sure they are copied into the app bundle.
- The project targets Swift 5.10 and macOS 26.0.

## Runtime Asset Rules

- Hunky depends on the bundled `chdman` binary being present in the app bundle
  as resource name `chdman`.
- `chdman` currently links `@executable_path/libSDL3.0.dylib`; keep the dylib
  bundled beside the executable in the app resources.
- If updating `chdman` or SDL, update both `vendor/chdman/` and
  `app/Resources/` copies, then verify architecture and linkage with `file`
  and `otool -L`.
- The README says the bundled `chdman` is 0.287. The root CMake cache default
  still names 0.278 for standalone rebuilds. Keep version notes synchronized if
  touching binary provenance.
- `.gitignore` ignores `*.dylib` globally but explicitly unignores the bundled
  SDL dylibs. Preserve those exceptions.

## Core Architecture

### Queue And Model

- `QueueController` is `@Observable` and `@MainActor`. Mutate `items`,
  statuses, output URLs, and other UI-observed state on the main actor.
- `QueueController.add(urls:)` filters inputs through `InputKind.detect` and
  schedules the background disc audit for image sheets with references.
- Queue execution is sequential. Preserve this unless the user asks for
  parallel conversion; parallel `chdman` jobs can be disk-heavy and may hurt
  UX.
- `QueueController.makePlan(for:)` builds `chdman` argument arrays. Keep args
  as arrays passed to `Process`; do not build shell command strings.
- `uniqueURL(in:stem:ext:)` prevents overwriting user files. Preserve
  collision-safe output behavior.
- On cancellation, partially written output is best-effort removed. Be careful
  when changing output path planning so cancellation cleanup still targets only
  files Hunky created.

### chdman Execution

- `ChdmanRunner` wraps `Process`, captures stdout/stderr, and parses progress.
- `chdman` emits progress on stderr, often using carriage returns. Preserve
  `LineBuffer` behavior that treats both `\r` and `\n` as line breaks.
- `parsePercent(line:)` expects text like `12.3% complete`; keep parser changes
  tolerant of MAME output variations.
- Progress updates are throttled to ~5 Hz inside `ChdmanRunner` before
  forwarding to SwiftUI. Do not remove this throttle without profiling.
- `CancelToken` is shared across async/process boundaries and is marked
  `@unchecked Sendable`. Keep thread-safety if extending it.
- Do not assume `info` writes only to stdout; current code uses stdout if
  present, otherwise stderr.

### Disc Detection

- `FileItem` derives:
  - `references` from `.cue`, `.gdi`, and `.toc` sheet files.
  - `identity` from `.iso` or the first existing referenced data track.
  - no identity for `.chd`, because that would require temporary extraction.
- `DiscSheet` is intentionally lightweight. It finds CUE/GDI/TOC references,
  resolves them relative to the sheet, preserves order, and retains enough
  track metadata for audit warnings. It lets `chdman` understand the full sheet
  syntax. The `DiscSheet` enum lives in `app/Sources/Hunky/Core/CueSheet.swift`
  (with `typealias CueSheet = DiscSheet` kept for backwards compatibility); do
  not look for a `DiscSheet.swift` file.
- `DiscSheet.references(in:)` tries UTF-8 first and Latin-1 as a fallback. Keep
  this forgiving behavior for older sheet files.
- `DiscInspector` reads up to the first 1 MiB and detects ISO 9660 PVD data,
  PS1 boot IDs, Saturn headers, and Dreamcast headers. It supports common
  2048/2352/2336 sector layouts.
- Avoid expensive full-disc scans on the main actor. Large file reads and
  hashes belong off the main actor.

### Redump Verification

- `RedumpDatabase` is an actor that lazy-loads bundled DAT files from
  `app/Resources/redump/<platform>.dat.gz`.
- Platform-scoped verification currently maps detected PS1, Saturn, and
  Dreamcast discs to `psx`, `saturn`, and `dreamcast` DATs. Do not let a known
  platform fall back to an unrelated platform DAT.
- Matching is keyed by CRC32 plus size. Shared audio tracks can match multiple
  games, so callers receive all candidates and aggregate across bins.
- `FileItem.redumpAggregate` tries to find a consensus platform/game identity
  across all hashed references, then falls back to a partial best guess.
- `QueueController.scheduleDiscAudit(for:)` hashes referenced files on a
  detached utility task, then updates the live item on the main actor.
- File size lookup intentionally resolves symlinks. Do not replace it with
  `FileManager.attributesOfItem` unless you account for symlink-size pitfalls.
- `RedumpDatabase.gunzip(data:)` strips gzip headers and inflates the raw
  deflate payload using Apple's Compression framework. If DAT files grow beyond
  the fixed output buffer, update that logic deliberately.

### AppSettings And Persistence

- `AppSettings` is `@Observable` and stores preferences in `UserDefaults` under
  the key prefix `com.powerbeef.Hunky.settings.`. It supports `URL`, `Bool`,
  and `Action` (via `rawValue`) properties.
- `ContentView` initializes `queue.outputDirectory` from `settings.outputDirectory`
  on `onAppear` and writes back whenever the user picks or resets the path.
- `AppIntegration` handles `UNUserNotificationCenter` queue-completion
  notifications, `NSApp.dockTile.badgeLabel` updates, and `NSSound` feedback.

### CRC32

- `CRC32.file(at:)` is a pure Swift streaming IEEE CRC32 implementation.
- It reads in 1 MiB chunks and supports a cancellation closure. Preserve
  streaming behavior; do not load whole disc images into memory.

## UI Guidelines

- The aesthetic is Blue Liquid Console Workbench: dark-only, playful,
  optical-console-era, and rendered through macOS 26 Liquid Glass. Use
  blue-cyan refractive panels, subtle console texture, status LEDs, disc-bay
  language, and BIOS-style ready checks while keeping safety-critical copy
  literal.
- Hunky intentionally requires macOS 26.0+. Use real Liquid Glass APIs
  (`glassEffect`, `GlassEffectContainer`, and `.glassProminent`) directly; do
  not add macOS 14 compatibility shims unless the product target changes.
- Use the semantic design tokens in `HunkyTheme.swift` and the reusable glass
  helpers in `ConsoleArt.swift` (`liquidGlassPanel`, `liquidGlassChip`, and
  panel modifiers). Prefer these helpers over hand-combining opaque fills,
  strokes, shadows, and overlays at call sites.
- Keep the generated console texture behind glass at low opacity. It should add
  depth without hurting text contrast or making panes look muddy. Do not use
  brand-infringing console logos or platform marks.
- Blue/cyan is the primary and running-state family. Use `.glassProminent` for
  primary actions such as Add Files or Folders, Run queue, and Start Anyway.
  Keep secondary controls native, compact, and literal.
- `severityVerified` (green) is only for confirmed-positive outcomes: Redump
  CRC matches and successful job completion. Do not use it for "no warnings" or
  file-presence checks; those use `inkSecondary`.
- Always gate motion on `@Environment(\.accessibilityReduceMotion)`. Pass `nil`
  to `.animation(...)` and skip shimmer when reduceMotion is true.
- Chrome lives in the macOS toolbar (`HunkyApp` sets
  `.windowToolbarStyle(.unified(showsTitle: false))`, `ContentView` adds
  `.toolbar { }`). Keep toolbar controls standard and minimal: Add files/folders
  and More only. Do not add custom Run, Stop, or queue-count pills to the
  titlebar.
- The main window is a persistent workbench shell. Disc Bay owns file intake,
  drag/drop guidance, supported formats, Save Path, and readiness facts. Queue
  Deck owns queued jobs, warnings, run summaries, and Run/Stop controls.
- `ContentView` (~340 lines) composes `DiscBayPanel` and `QueueDeckPanel`.
  Keep extracted panel views under `Views/Panels/` instead of inlining large
  view builders back into `ContentView`.
- Queue rows use proportional widths shared via `QueueColumns` (Disc fluid;
  Audit, Action, and Status fixed). The pinned column header is rendered as a
  `Section` header in the queue list's `LazyVStack`, mixed-case (`Slot`,
  `Ready Check`, `Action`, `Status`). Rows should read as Liquid Glass
  optical-console job slots, not opaque ledger cards.
- Per-row column labels in body content are noise. The single
  `QueueColumnHeader` strip is the only place those names appear.
- The `DropZone` is a Disc Bay intake surface, not a centered landing-page
  hero. The whole window remains the drop target via `ContentView`'s `.onDrop`.
- For preflight, caution-only issues surface as the inline `cautionRibbon` in
  the queue list. Critical issues still show `PreflightConfirmationSheet` as a
  Ready Check modal.
- Sheets do not set explicit outer backgrounds. Let macOS render sheet chrome.
  Use Liquid Glass only for inner content groups and raw-output containers.
  Inside `TextOutputSheet`, the actual chdman output uses `HunkyType.mono`.
- Settings is a first-class window (⌘,) with three tabs: General, Appearance,
  and Advanced. It persists `outputDirectory`, default actions, sound, and
  confirmation toggles via `AppSettings` / `UserDefaults`.
- Queue Deck includes a collapsible search/filter bar that filters by filename,
  platform, status, and action. Filter state is local to the panel (not persisted).
- Right-click context menus on queue rows expose Retry, Remove, Show in Finder,
  Copy Error, View Log, and Change Action without requiring small icon-button hits.
- Do not block the main thread during drag/drop, browse, hashing, DAT loading,
  or `chdman` execution.

## Coding Style

- Match existing Swift formatting: 4-space indentation, concise `MARK`
  sections, small helper methods, and explicit switch handling.
- Keep comments only where they explain non-obvious disk formats, process
  behavior, or concurrency choices.
- Use `Foundation`, `SwiftUI`, `Observation`, `Compression`, and system APIs
  already present before adding dependencies.
- Keep UI-observed types compatible with Swift Observation (`@Observable`,
  `@Bindable`, `@State`) rather than introducing a different state framework.
- Avoid shelling out except for the bundled `chdman`; do not require Homebrew
  tools at runtime.

## Safety And User Data

- Never overwrite source images or existing outputs.
- Treat dropped files as user-owned data. Avoid deleting anything except
  best-effort cleanup of a partially written output file that Hunky planned and
  created during a cancelled job.
- Do not send disc names, hashes, or file metadata to network services. Current
  identification is offline by design.
- Keep the app self-contained. Runtime features should not require users to
  install MAME, `chdman`, `rom-tools`, or Homebrew.

## Standalone chdman Build Notes

The root CMake build is separate from the app. If the user asks to rebuild
`chdman` from MAME sources:

```bash
./scripts/fetch_sources.sh mame0287
cmake -B build -G Ninja
cmake --build build
```

That workflow may create `src/` and `3rdparty/` directories that are not part
of the checked-in Swift app structure. Confirm with the user before committing
large fetched source trees or generated build output.
