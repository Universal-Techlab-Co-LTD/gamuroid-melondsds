#!/usr/bin/env bash
# Builds melondsds_libretro.dylib for iOS arm64 (Release, interpreter only, no OpenGL).
#
# Usage: scripts/build_ios.sh [--wrapper DIR] [--engine DIR] [--build DIR] [--exports FILE]
# Defaults: work/melonds-ds, work/melonDS, build-ios, scripts/exports_gamuroid.txt
# Output:   <build>/melondsds_libretro.dylib (path printed at the end)
#
# CPU baseline: -mcpu=apple-a7 (ARMv8.0) so the core runs on every iOS 15 device;
# tuning only through -mtune. Never raise -mcpu/-march (see gates.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WRAPPER="$ROOT/work/melonds-ds"
ENGINE="$ROOT/work/melonDS"
BUILD="$ROOT/build-ios"
EXPORTS="$ROOT/scripts/exports_gamuroid.txt"
DEPS="$ROOT/deps"

while [ $# -gt 0 ]; do
    case "$1" in
        --wrapper) WRAPPER="$(cd "$2" && pwd)"; shift 2 ;;
        --engine)  ENGINE="$(cd "$2" && pwd)"; shift 2 ;;
        --build)   BUILD="$2"; shift 2 ;;
        --exports) EXPORTS="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"; shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

# One heavy build at a time on this machine, and enough free space.
AVAIL_KB=$(df -k /System/Volumes/Data | awk 'NR==2 {print $4}')
if [ "$AVAIL_KB" -lt $((8 * 1024 * 1024)) ]; then
    echo "error: less than 8 GB free on /System/Volumes/Data" >&2
    exit 1
fi

if pgrep -x xcodebuild >/dev/null || pgrep -x ninja >/dev/null; then
    echo "error: another xcodebuild/ninja build is running; run one heavy build at a time" >&2
    exit 1
fi

CPU_FLAGS="-mcpu=apple-a7 -mtune=apple-a14"
# -g only adds debug info for the dSYM (package_framework.sh strips the shipped binary).
DEBUG_FLAGS="-g"

mkdir -p "$BUILD" "$DEPS"

cmake -S "$WRAPPER" -B "$BUILD" -G Ninja \
    --toolchain "$WRAPPER/cmake/toolchain/ios.toolchain.cmake" \
    -DPLATFORM=OS64 \
    -DDEPLOYMENT_TARGET=15.0 \
    -DENABLE_BITCODE=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_AS_SHARED_LIBRARY=ON \
    -DENABLE_JIT=OFF \
    -DENABLE_OPENGL=OFF \
    -DTRACY_ENABLE=OFF \
    -DBUILD_TESTING=OFF \
    -DFETCHCONTENT_BASE_DIR="$DEPS" \
    -DFETCHCONTENT_SOURCE_DIR_MELONDS="$ENGINE" \
    -DMELONDS_REPOSITORY_TAG="$(git -C "$ENGINE" rev-parse HEAD)" \
    -DPython3_EXECUTABLE=/usr/bin/python3 \
    -DCMAKE_C_FLAGS="$CPU_FLAGS $DEBUG_FLAGS" \
    -DCMAKE_CXX_FLAGS="$CPU_FLAGS $DEBUG_FLAGS -Wno-deprecated-declarations -Wno-unknown-attributes" \
    -DCMAKE_SHARED_LINKER_FLAGS="-Wl,-exported_symbols_list,$EXPORTS -Wl,-dead_strip -Wl,-object_path_lto,$BUILD/melondsds_lto.o" \
    -DCMAKE_MODULE_LINKER_FLAGS="-Wl,-exported_symbols_list,$EXPORTS -Wl,-dead_strip -Wl,-object_path_lto,$BUILD/melondsds_lto.o"

cmake --build "$BUILD" --target melondsds_libretro -- -j"$(sysctl -n hw.ncpu)"

OUT=$(find "$BUILD" -maxdepth 3 -name 'melondsds_libretro.dylib' -type f | head -1)
if [ -z "$OUT" ]; then
    echo "error: build produced no melondsds_libretro.dylib" >&2
    exit 1
fi
echo "BUILT: $OUT"
