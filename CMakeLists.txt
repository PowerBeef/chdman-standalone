cmake_minimum_required(VERSION 3.16)
project("chdman-standalone")

# Get version from MAME tags or set manually
set(MAME_VERSION "0.278" CACHE STRING "MAME version this was extracted from")

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Platform definitions
if(WIN32)
  add_compile_definitions(
    X64_WINDOWS_ABI
    CRLF=3
    OSD_WINDOWS
    WIN32
    _WIN32
    _CRT_NONSTDC_NO_DEPRECATE
    _CRT_SECURE_NO_DEPRECATE
  )
else()
  add_compile_definitions(
    CRLF=2
  )
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  add_compile_definitions(OSD_MAC)
endif()

# --- 3rd party dependencies ---
find_package(ZLIB REQUIRED)
find_package(Threads REQUIRED)

# libflac
add_subdirectory(3rdparty/libflac)

# utf8proc
add_library(utf8proc STATIC 3rdparty/utf8proc/utf8proc.c)
target_include_directories(utf8proc PUBLIC 3rdparty/utf8proc)

# expat
add_library(expat STATIC
  3rdparty/expat/lib/xmlparse.c
  3rdparty/expat/lib/xmlrole.c
  3rdparty/expat/lib/xmltok.c
)
target_include_directories(expat PUBLIC 3rdparty/expat/lib)
target_compile_definitions(expat PRIVATE XML_STATIC HAVE_MEMMOVE)

# 7-zip
file(GLOB 7Z_SOURCES "3rdparty/lzma/C/*.c")
add_library(7z STATIC ${7Z_SOURCES})
target_include_directories(7z PUBLIC 3rdparty/lzma/C)
target_compile_definitions(7z PRIVATE _7ZIP_ST)

# --- libocore (OSD core) ---
set(OCORE_SOURCES
  src/osd/modules/lib/osd_getenv.cpp
)
if(WIN32)
  list(APPEND OCORE_SOURCES
    src/osd/windows/winutil.cpp
    src/osd/windows/osdsync.cpp
    src/osd/windows/winsocket.cpp
    src/osd/windows/winfile.cpp
    src/osd/windows/windir.cpp
    src/osd/windows/wintimer.cpp
  )
elseif(APPLE)
  list(APPEND OCORE_SOURCES
    src/osd/mac/macfile.cpp
    src/osd/mac/macdir.cpp
    src/osd/posix/posixsocket.cpp
    src/osd/posix/posixptty.cpp
    src/osd/sdl/sdlfile.cpp
    src/osd/sdl/sdlptty.cpp
    src/osd/sdl/sdlos.cpp
  )
else()
  list(APPEND OCORE_SOURCES
    src/osd/sdl/sdlfile.cpp
    src/osd/sdl/sdlptty.cpp
    src/osd/sdl/sdlos.cpp
    src/osd/posix/posixsocket.cpp
    src/osd/posix/posixptty.cpp
  )
endif()
add_library(ocore STATIC ${OCORE_SOURCES})
target_include_directories(ocore PUBLIC
  src/osd
  src/lib/util
  3rdparty
)
target_link_libraries(ocore PRIVATE Threads::Threads ZLIB::ZLIB)

# --- libutils ---
add_library(utils STATIC
  src/lib/util/avhuff.cpp
  src/lib/util/aviio.cpp
  src/lib/util/bitmap.cpp
  src/lib/util/cdrom.cpp
  src/lib/util/chd.cpp
  src/lib/util/chdcodec.cpp
  src/lib/util/corefile.cpp
  src/lib/util/corestr.cpp
  src/lib/util/coreutil.cpp
  src/lib/util/dvdrom.cpp
  src/lib/util/flac.cpp
  src/lib/util/harddisk.cpp
  src/lib/util/hash.cpp
  src/lib/util/hashing.cpp
  src/lib/util/huffman.cpp
  src/lib/util/ioprocs.cpp
  src/lib/util/ioprocsfilter.cpp
  src/lib/util/md5.cpp
  src/lib/util/path.cpp
  src/lib/util/png.cpp
  src/lib/util/strformat.cpp
  src/lib/util/unicode.cpp
  src/lib/util/unzip.cpp
  src/lib/util/vbiparse.cpp
  src/lib/util/xmlfile.cpp
  src/lib/util/zippath.cpp
)
target_include_directories(utils PUBLIC
  src/lib/util
  src/osd
  3rdparty
  3rdparty/libflac/include
)
target_link_libraries(utils PUBLIC ocore flac ZLIB::ZLIB utf8proc)

# --- chdman executable ---
add_executable(chdman
  src/tools/chdman.cpp
  src/version.cpp
)
target_include_directories(chdman PRIVATE
  src/osd
  src/lib/util
  3rdparty
  3rdparty/libflac/include
)
target_compile_definitions(chdman PRIVATE
  BARE_BUILD_VERSION="${MAME_VERSION}-standalone"
  BARE_VCS_REVISION="mame${MAME_VERSION}"
)
target_link_libraries(chdman PRIVATE utils ocore expat 7z ZLIB::ZLIB flac utf8proc Threads::Threads)

if(UNIX)
  target_link_libraries(chdman PRIVATE util)
elseif(WIN32)
  target_link_libraries(chdman PRIVATE user32 winmm advapi32 shlwapi wsock32 ws2_32 psapi iphlpapi shell32 userenv)
endif()

if(MINGW)
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static")
endif()

install(TARGETS chdman DESTINATION bin)
