#!/usr/bin/env bash
# Build gates for the Gamuroid melonDS DS core.
#
# Usage: scripts/gates.sh <framework dir> [<unstripped dylib>] [<expected option keys file>]
# Prints one line per gate and exits non-zero if any gate fails.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FW="$1"
BIN="$FW/melondsds.libretro"
UNSTRIPPED="${2:-$BIN}"
EXPECTED_KEYS="${3:-$ROOT/scripts/expected_option_keys.txt}"
FAIL=0

gate() { # name, pass(0/1), detail
    if [ "$2" -eq 0 ]; then echo "PASS  $1  ($3)"; else echo "FAIL  $1  ($3)"; FAIL=1; fi
}

# 1. Architecture and install name
ARCH=$(lipo -archs "$BIN")
[ "$ARCH" = "arm64" ]; gate "arch arm64" $? "$ARCH"
IDN=$(otool -D "$BIN" | tail -1)
[ "$IDN" = "@rpath/melondsds_libretro.framework/melondsds_libretro" ]; gate "install name" $? "$IDN"

# 2. CPU baseline (ARMv8.0 only; A8/A9 devices)
CPU=$(otool -tv "$BIN" | grep -c -w -E 'ldaprb|ldapr|eor3|bcax|casal|ldaddal|swpal')
[ "$CPU" -eq 0 ]; gate "CPU baseline (ldaprb|ldapr|eor3|bcax|casal|ldaddal|swpal)" $? "$CPU"

# 3. minos 15.0 and Info.plist MinimumOSVersion
MINOS=$(otool -l "$BIN" | awk '/LC_BUILD_VERSION/{f=1} f && /minos/{print $2; exit}')
[ "$MINOS" = "15.0" ]; gate "minos" $? "$MINOS"
PLIST_MIN=$(plutil -extract MinimumOSVersion raw "$FW/Info.plist")
[ "$PLIST_MIN" = "15.0" ]; gate "Info.plist MinimumOSVersion" $? "$PLIST_MIN"

# 4. No JIT: no MAP_JIT / pthread_jit_write_protect, no ARMJIT symbols.
#    The broad pattern also matches GPU::...VRAM_AOBJ/BOBJ (2D object VRAM), listed for the record.
JITSTR=$(strings -a "$BIN" | grep -c -E 'MAP_JIT|pthread_jit_write_protect')
[ "$JITSTR" -eq 0 ]; gate "no MAP_JIT/pthread_jit strings" $? "$JITSTR"
ARMJIT=$(nm -a "$UNSTRIPPED" | grep -c -E 'ARMJIT|pthread_jit|MAP_JIT|JitBlock|Compiler')
[ "$ARMJIT" -eq 0 ]; gate "no ARMJIT/JIT symbols (unstripped)" $? "$ARMJIT"
BROAD=$(nm -a "$UNSTRIPPED" | grep -i -E 'jit|MAP_JIT|pthread_jit' | grep -v -E 'VRAM_[AB]OBJ' | wc -l | tr -d ' ')
[ "$BROAD" -eq 0 ]; gate "broad 'jit' symbol grep minus VRAM_AOBJ/BOBJ (unstripped)" $? "$BROAD"
IMPORTS=$(nm -u "$BIN" | grep -c -E 'pthread_jit|mprotect|vm_protect|mmap$')
gate "imports: pthread_jit/mprotect/vm_protect/mmap (info)" 0 "$IMPORTS; $(nm -u "$BIN" | grep -E 'pthread_jit|mprotect|vm_protect|mmap$' | tr '\n' ' ')"

# 5. Forbidden strings
DENY='nintendo.*cdn|nus\.cdn'
BAD=$(strings -a "$BIN" | grep -ci -E "$DENY")
[ "$BAD" -eq 0 ]; gate "strings nintendo cdn" $? "$BAD"
BAD2=$(strings -a "$BIN" | grep -c -E 'custom_layout_config|slot\.gba|melonds_wfc_status|nintendowifi')
[ "$BAD2" -eq 0 ]; gate "strings custom_layout_config|slot.gba|melonds_wfc_status|nintendowifi" $? "$BAD2"
TMD=$(strings -a "$BIN" | grep -c -E 'Downloading title metadata|/ccs/download/')
[ "$TMD" -eq 0 ]; gate "no TMD download code path strings" $? "$TMD"

# 6. Exports: exactly the 25 retro_* plus the two gamuroid_net_state_* exports
EXP=$(nm -gU "$BIN" | awk '{print $3}' | sort)
diff <(echo "$EXP") <(sort "$ROOT/scripts/exports_gamuroid.txt") >/dev/null
gate "exports = 25 retro_* + gamuroid_net_state_get/listen" $? "$(echo "$EXP" | wc -l | tr -d ' ') exported"

# 7. Option keys (string scan, same method as for the old binary)
KEYS=$(strings -a "$BIN" | grep -E '^(melonds|gamuroid)_[a-z0-9_]+$' | sort -u)
if [ -f "$EXPECTED_KEYS" ]; then
    diff <(echo "$KEYS") "$EXPECTED_KEYS" >/dev/null
    gate "option keys = expected list" $? "$(echo "$KEYS" | wc -l | tr -d ' ') keys"
fi
LAYOUTKEY=$(echo "$KEYS" | grep -c -x gamuroid_screen_layout)
[ "$LAYOUTKEY" -eq 1 ]; gate "gamuroid_screen_layout declared" $? "$LAYOUTKEY"
# (count with grep -c: grep -q under pipefail can fail the pipeline through SIGPIPE in strings)
GUESS=$(strings -a "$BIN" | grep -c -x guess_username)
[ "$GUESS" -ge 1 ]; gate "username Guess token is upstream's (guess_username)" $? "$GUESS"

# 8. Slot-2 subsystems
# (the linker may tail-merge the ident "gba" into "nds|dsi|ids|gba", so accept it as a suffix)
SUB_GBA=$(strings -a "$BIN" | grep -c -E '(^|[|])gba$')
SUB_NOSAV=$(strings -a "$BIN" | grep -c -x 'gbanosav')
[ "$SUB_GBA" -ge 1 ] && [ "$SUB_NOSAV" -ge 1 ]; gate "subsystems gba/gbanosav present" $? "gba=$SUB_GBA gbanosav=$SUB_NOSAV"

# dSYM matches
if [ -d "$FW.dSYM" ]; then
    U1=$(xcrun dwarfdump --uuid "$BIN" | awk '{print $2}')
    U2=$(xcrun dwarfdump --uuid "$FW.dSYM" | awk '{print $2}')
    [ "$U1" = "$U2" ]; gate "dSYM UUID matches" $? "$U1"
fi

exit $FAIL
