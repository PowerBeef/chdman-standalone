# Hunky

A native, self-contained macOS app for working with **CHD** (Compressed Hunks of Data) disk images — the lossless format used by MAME, RetroArch, and many other emulators.

Hunky is a SwiftUI front end for [`chdman`](https://docs.mamedev.org/tools/chdman.html), the official CHD tool from MAME. The `chdman` binary ships **inside the app bundle** — no Homebrew, no Terminal, no MAME install required.

> Apple Silicon only (arm64). macOS 14+.

## Features

- **Drop a folder of CDs and go.** Drag `.cue` / `.gdi` / `.iso` / `.toc` / `.chd` files (or folders) into the window. Hunky auto-detects what each file is and proposes the right action.
- **Four actions, one click:**
  - **Create CHD** — convert a CD image (`.cue`/`.gdi`/`.iso`/`.toc`) into a compressed `.chd`
  - **Extract** — round-trip a `.chd` back to `.cue` + `.bin`
  - **Info** — read the metadata, hash, compression, track layout
  - **Verify** — SHA1 integrity check
- **Live progress** parsed straight from `chdman` — no spinner-and-pray.
- **Collision-safe output** — never overwrites an existing file (`test.chd` becomes `test (2).chd`).
- **Offline Redump checks** for PS1, Sega Saturn, and Sega Dreamcast sheets — warns about swapped, duplicated, corrupted, or mismatched tracks without blocking conversion.
- **Configurable output folder**, or "same folder as source" by default.
- **Sequential queue** — drop a stack of CDs and let it grind.

## Install

Releases haven't been cut yet. To build from source:

### Prerequisites

- Xcode 16 or later
- [`xcodegen`](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen` or via [`mise`](https://mise.jdx.dev/))

### Build

```bash
git clone https://github.com/PowerBeef/hunky.git
cd hunky/app
xcodegen generate
xcodebuild -project Hunky.xcodeproj -scheme Hunky -configuration Release \
  -destination 'platform=macOS,arch=arm64' build
```

Or open `app/Hunky.xcodeproj` in Xcode and ⌘R.

The built `Hunky.app` lands in `~/Library/Developer/Xcode/DerivedData/Hunky-*/Build/Products/Release/`.

## Why this exists

`chdman` is a CLI tool. Most Mac users converting CDs for emulation don't want to run incantations like:

```
chdman createcd -i game.cue -o game.chd
```

They want to drop a file on a window and have it work. Existing macOS GUIs for `chdman` (e.g. [Swift-CHD](https://github.com/iTechMedic/Swift-CHD)) require you to `brew install rom-tools` first, which is a non-starter for non-developers. Hunky bundles `chdman` inside the `.app` so install = drag to `/Applications`, done.

## Project layout

```
hunky/
├── app/                          ← Xcode/SwiftUI project
│   ├── project.yml               ← xcodegen spec (source of truth)
│   ├── Info.plist
│   ├── Sources/Hunky/
│   │   ├── HunkyApp.swift        ← @main entry
│   │   ├── Core/
│   │   │   ├── ChdmanRunner.swift     ← Process wrapper + progress parser
│   │   │   ├── QueueController.swift  ← sequential job runner
│   │   │   └── FileItem.swift         ← per-file model
│   │   └── Views/                ← SwiftUI views
│   └── Resources/
│       ├── chdman                ← arm64 binary, bundled into the .app
│       ├── libSDL3.0.dylib       ← runtime dependency
│       └── redump/*.dat.gz       ← bundled offline Redump DAT catalogs
└── vendor/chdman/                ← the same binary, kept here as the source of truth
```

The `Hunky.xcodeproj` is generated from `project.yml`. Don't edit the project file directly — edit the YAML and re-run `xcodegen`.

## Where the chdman binary comes from

The bundled binary is `chdman 0.287` (Apple Silicon), pulled from [`emmercm/chdman-js`](https://github.com/emmercm/chdman-js), which builds clean static binaries from MAME upstream for several platforms. We vendor the binary directly so building Hunky doesn't require building all of MAME.

If you want to rebuild `chdman` yourself, the official path is:

```bash
git clone https://github.com/mamedev/mame.git
cd mame
make TOOLS=1 SUBTARGET=tiny -j$(sysctl -n hw.ncpu)
```

(Allocate ~700 MB and 20–40 minutes.) Drop the resulting `chdman` and any required dylibs into `app/Resources/` and rebuild.

## License

- Hunky source code (everything under `app/Sources/`): **BSD-3-Clause**, see [`LICENSE`](LICENSE).
- The bundled `chdman` binary is part of MAME and is distributed under MAME's BSD-3-Clause license.
- `libSDL3.0.dylib` is distributed under the [zlib license](https://www.libsdl.org/license.php).

## Credits

- `chdman` and CHD: Aaron Giles and the [MAME team](https://www.mamedev.org/).
- Prebuilt arm64 binary: [Christian Emmer's chdman-js](https://github.com/emmercm/chdman-js).
- Inspired by [namDHC](https://github.com/umageddon/namDHC) (Windows) and [Swift-CHD](https://github.com/iTechMedic/Swift-CHD) (macOS, requires Homebrew).
