# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

This file applies to the entire repository. It is a handoff guide for coding
agents working on Hunky, a native macOS SwiftUI app that bundles `chdman` for
CHD disk-image workflows.

## Project Summary

Hunky is an Apple Silicon, macOS 14+ SwiftUI front end for MAME's `chdman`.
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
- `app/Sources/Hunky/HunkyApp.swift`: SwiftUI app entry point and window setup.
- `app/Sources/Hunky/Core/`: app model, queue, disk inspection, Redump lookup,
  CRC32, and `chdman` process execution.
- `app/Sources/Hunky/Views/`: SwiftUI views for the drop zone, queue rows,
  main screen, and info sheet.
- `app/Resources/chdman`: bundled arm64 `chdman` executable.
- `app/Resources/libSDL3.0.dylib`: bundled runtime dependency for `chdman`.
- `app/Resources/redump/*.dat.gz`: bundled gzipped Redump DAT catalogs. Hunky
  currently ships PS1 (`psx`), Sega Saturn (`saturn`), and Sega Dreamcast
  (`dreamcast`) DATs for offline verification.
- `vendor/chdman/`: tracked copy of the bundled `chdman` binary and SDL dylib,
  kept as the binary source of truth.
- `scripts/fetch_sources.sh`: helper for fetching selected MAME source files
  and third-party dependencies for the standalone CMake build.

## Build And Verification Commands

Run app commands from `app/` unless noted otherwise.

```bash
xcodegen generate
xcodebuild -project Hunky.xcodeproj -scheme Hunky -configuration Debug -destination 'platform=macOS,arch=arm64' build
xcodebuild -project Hunky.xcodeproj -scheme Hunky -configuration Release -destination 'platform=macOS,arch=arm64' build
```

Useful inspection commands from the repository root:

```bash
xcodebuild -list -project app/Hunky.xcodeproj
file app/Resources/chdman app/Resources/libSDL3.0.dylib
otool -L app/Resources/chdman
app/Resources/chdman
```

The app has a `HunkyTests` unit-test target. For behavior changes, run the
test command when possible; for queue, process, or UI changes, also do a manual
smoke test with small sample `.cue`, `.gdi`, `.iso`, or `.chd` files when
available.

## Project Generation Rules

- Treat `app/project.yml` as authoritative.
- Do not manually edit `app/Hunky.xcodeproj/project.pbxproj` unless the user
  explicitly asks for a generated-project patch. Change `project.yml` and run
  `xcodegen generate`.
- Keep bundle resources declared in `project.yml`. If adding resources, make
  sure they are copied into the app bundle.
- The project targets Swift 5.10 and macOS 14.0.

## Runtime Asset Rules

- Hunky depends on the bundled `chdman` binary being present in the app bundle
  as resource name `chdman`.
- `chdman` currently links `@executable_path/libSDL3.0.dylib`; keep the dylib
  bundled beside the executable in the app resources.
- If updating `chdman` or SDL, update both `vendor/chdman/` and
  `app/Resources/` copies, then verify architecture and linkage with `file`
  and `otool -L`.
- The README says the bundled `chdman` is 0.287. The root CMake cache default
  still names 0.278 for standalone rebuilds. Be careful to keep version notes
  synchronized if touching binary provenance.
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
  syntax.
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

### CRC32

- `CRC32.file(at:)` is a pure Swift streaming IEEE CRC32 implementation.
- It reads in 1 MiB chunks and supports a cancellation closure. Preserve
  streaming behavior; do not load whole disc images into memory.

## UI Guidelines

- This is a compact utility app, not a marketing page. Keep the UI direct,
  quiet, and task-focused.
- Prefer SwiftUI system controls and SF Symbols, as the existing views do.
- Keep queue rows scannable: filename, type/platform chips, identity, Redump
  status, reference status, action, and result controls.
- Do not block the main thread during drag/drop, browse, hashing, DAT loading,
  or `chdman` execution.
- `DropZone` currently allows files, not directories, through the browse panel
  even though the README mentions folders. If implementing folder support,
  update both drag/drop and browse behavior plus documentation.

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
