#!/usr/bin/env bash
# fetch_sources.sh
# Fetches the required MAME source files for a standalone chdman build.
# Usage: ./scripts/fetch_sources.sh [MAME_TAG]
# Example: ./scripts/fetch_sources.sh mame0278
#
# Requires: git (for sparse checkout) or curl

set -e

MAME_TAG=${1:-master}
MAME_REPO="https://github.com/mamedev/mame"
RAW_BASE="https://raw.githubusercontent.com/mamedev/mame/${MAME_TAG}"

echo "Fetching sources from mamedev/mame @ ${MAME_TAG}..."

# Helper: download a file from MAME raw
fetch_file() {
  local remote_path="$1"
  local local_path="$2"
  mkdir -p "$(dirname "$local_path")"
  echo "  Fetching: $remote_path"
  curl -fsSL "${RAW_BASE}/${remote_path}" -o "$local_path"
}

# ---- src/tools ----
fetch_file "src/tools/chdman.cpp"             "src/tools/chdman.cpp"

# ---- src/version.cpp ----
fetch_file "src/version.cpp"                  "src/version.cpp"

# ---- src/lib/util ----
LIB_UTIL_FILES=(
  avhuff.cpp avhuff.h
  aviio.cpp aviio.h
  bitmap.cpp bitmap.h
  bitstream.h
  cdrom.cpp cdrom.h
  chd.cpp chd.h
  chdcodec.cpp chdcodec.h
  corefile.cpp corefile.h
  corealloc.cpp corealloc.h
  corestr.cpp corestr.h
  coretmpl.h
  coreutil.cpp coreutil.h
  delegate.cpp delegate.h
  dvdrom.cpp dvdrom.h
  endianness.h
  flac.cpp flac.h
  harddisk.cpp harddisk.h
  hash.cpp hash.h
  hashing.cpp hashing.h
  huffman.cpp huffman.h
  ioprocs.cpp ioprocs.h
  ioprocsfill.h
  ioprocsfilter.cpp ioprocsfilter.h
  ioprocsvec.h
  lrucache.h
  md5.cpp md5.h
  multibyte.h
  notifier.h
  opresolv.cpp opresolv.h
  options.cpp options.h
  path.cpp path.h
  png.cpp png.h
  strformat.cpp strformat.h
  unicode.cpp unicode.h
  unzip.cpp unzip.h
  utf8.h
  utilfwd.h
  vbiparse.cpp vbiparse.h
  vecstream.cpp vecstream.h
  xmlfile.cpp xmlfile.h
  zippath.cpp zippath.h
)
for f in "${LIB_UTIL_FILES[@]}"; do
  fetch_file "src/lib/util/$f" "src/lib/util/$f"
done

# ---- src/osd headers ----
OSD_FILES=(
  osdcore.h
  osdfile.h
  osdcomm.h
  osdsync.h
  osdnet.h
  osdproc.h
  osdmem.h
  abi.h
)
for f in "${OSD_FILES[@]}"; do
  fetch_file "src/osd/$f" "src/osd/$f"
done

# ---- src/osd/modules/lib ----
fetch_file "src/osd/modules/lib/osd_getenv.cpp" "src/osd/modules/lib/osd_getenv.cpp"
fetch_file "src/osd/modules/lib/osd_getenv.h"   "src/osd/modules/lib/osd_getenv.h"

# ---- Platform OSD implementations ----
# SDL/POSIX (Linux/macOS)
SDL_OSD_FILES=(
  sdl/sdlfile.cpp sdl/sdlfile.h
  sdl/sdlptty.cpp sdl/sdlptty_unix.cpp
  sdl/sdlos.cpp
  posix/posixsocket.cpp
  posix/posixptty.cpp
)
for f in "${SDL_OSD_FILES[@]}"; do
  fetch_file "src/osd/$f" "src/osd/$f" 2>/dev/null || echo "    (skipped $f - may not exist)"
done

# macOS
MAC_OSD_FILES=(
  mac/macfile.cpp mac/macfile.h
  mac/macdir.cpp
)
for f in "${MAC_OSD_FILES[@]}"; do
  fetch_file "src/osd/$f" "src/osd/$f" 2>/dev/null || echo "    (skipped $f - may not exist)"
done

# Windows
WIN_OSD_FILES=(
  windows/winfile.cpp windows/winfile.h
  windows/windir.cpp
  windows/winutil.cpp windows/winutil.h
  windows/wintimer.cpp
  windows/osdsync.cpp
  windows/winsocket.cpp
)
for f in "${WIN_OSD_FILES[@]}"; do
  fetch_file "src/osd/$f" "src/osd/$f" 2>/dev/null || echo "    (skipped $f - may not exist)"
done

# ---- 3rdparty: use sparse git checkout (more reliable) ----
echo ""
echo "Fetching 3rdparty dependencies via git sparse checkout..."
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

git clone --depth=1 --filter=blob:none --sparse "${MAME_REPO}" "$TMP_DIR/mame" 2>/dev/null
pushd "$TMP_DIR/mame" > /dev/null
git sparse-checkout set \
  3rdparty/libflac \
  3rdparty/lzma \
  3rdparty/expat \
  3rdparty/utf8proc
popd > /dev/null

echo "Copying 3rdparty directories..."
mkdir -p 3rdparty
cp -r "$TMP_DIR/mame/3rdparty/libflac"  3rdparty/
cp -r "$TMP_DIR/mame/3rdparty/lzma"     3rdparty/
cp -r "$TMP_DIR/mame/3rdparty/expat"    3rdparty/
cp -r "$TMP_DIR/mame/3rdparty/utf8proc" 3rdparty/

echo ""
echo "Done! All sources fetched."
echo "You can now build with:"
echo "  cmake -B build -G Ninja"
echo "  cmake --build build"
