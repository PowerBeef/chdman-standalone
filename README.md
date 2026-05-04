# chdman-standalone

> Standalone build of MAME's `chdman` CHD management tool — extracted from [mamedev/mame](https://github.com/mamedev/mame) with only the required dependencies.

`chdman` is the official tool for creating, extracting, and managing **CHD (Compressed Hunks of Data)** files — the lossless disk image format used by MAME, RetroArch, and many other emulators.

## Why this repo?

The full MAME codebase is enormous (~700 MB). This repo provides:
- A `fetch_sources.sh` script that pulls **only** the needed files from the official MAME repo
- A standalone `CMakeLists.txt` build system (CMake + Ninja)
- Cross-platform support: **Linux**, **macOS**, **Windows** (MinGW/MSVC)

## Quick Start

### Prerequisites

- `git`
- `curl`
- `cmake >= 3.16`
- `ninja-build` (recommended) or `make`
- C++17-capable compiler (GCC 9+, Clang 10+, MSVC 2019+)
- `zlib` development headers

**macOS (Homebrew):**
```bash
brew install cmake ninja
```

**Linux (Debian/Ubuntu):**
```bash
sudo apt install cmake ninja-build build-essential zlib1g-dev
```

### 1. Fetch the MAME source files

```bash
git clone https://github.com/PowerBeef/chdman-standalone.git
cd chdman-standalone
bash scripts/fetch_sources.sh
```

To pin to a specific MAME version tag:
```bash
bash scripts/fetch_sources.sh mame0278
```

### 2. Build

```bash
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

The `chdman` binary will be in the `build/` directory.

### 3. (Optional) Install

```bash
cmake --install build --prefix /usr/local
```

## Project Structure

```
chdman-standalone/
  CMakeLists.txt          # Standalone CMake build
  scripts/
    fetch_sources.sh      # Fetches required files from mamedev/mame
  src/                    # Populated by fetch_sources.sh
    tools/chdman.cpp
    lib/util/             # CHD, compression, AVI, CD-ROM utilities
    osd/                  # OS-dependent layer (file I/O, platform)
    version.cpp
  3rdparty/               # Populated by fetch_sources.sh
    libflac/              # FLAC audio codec
    lzma/                 # LZMA/7-zip compression
    expat/                # XML parsing
    utf8proc/             # UTF-8 string processing
```

## Source Dependencies

The following files are pulled from `mamedev/mame`:

| Component | Files | Purpose |
|---|---|---|
| `src/tools/chdman.cpp` | 1 file | Main tool |
| `src/lib/util/` | ~50 files | CHD, cdrom, avhuff, hashing, I/O |
| `src/osd/` | ~20 files | Platform abstraction |
| `3rdparty/libflac` | full dir | FLAC audio |
| `3rdparty/lzma` | full dir | LZMA compression |
| `3rdparty/expat` | full dir | XML |
| `3rdparty/utf8proc` | full dir | UTF-8 |

## Common chdman Commands

```bash
# Create CHD from CUE/BIN (CD-ROM)
chdman createcd -i game.cue -o game.chd

# Create CHD from raw image
chdman createraw -i disk.img -o disk.chd --hunksize 512

# Extract CHD back to CUE/BIN
chdman extractcd -i game.chd -o game.cue -ob game.bin

# Verify CHD integrity
chdman verify -i game.chd

# Show CHD info
chdman info -i game.chd

# Copy/recompress CHD
chdman copy -i old.chd -o new.chd --compression zstd,zlib,lzma,huff
```

## License

This project's build scripts and tooling are provided under the **BSD-3-Clause** license.

All source code fetched from [mamedev/mame](https://github.com/mamedev/mame) remains under its original **BSD-3-Clause** license. See `LICENSE` for details.

## Credits

- Original `chdman` tool: Aaron Giles and the [MAME development team](https://github.com/mamedev/mame)
- Inspired by [charlesthobe/chdman](https://github.com/charlesthobe/chdman) (archived)
