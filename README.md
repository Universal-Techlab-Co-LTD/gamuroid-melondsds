# melonDS DS for Gamuroid (iOS)

Build workspace for the NDS core that Gamuroid ships as `Cores/melondsds.libretro.framework`.
It is built only from public upstream sources plus our own patches.

Licence: GPL-3.0 (wrapper, engine and our patches). The patches in `patches/` are the
corresponding source of our changes; published with the binary.

## Upstream pins (`scripts/pins.env`)

| Part | Repository | Pin |
|---|---|---|
| Wrapper | https://github.com/JesseTG/melonds-ds | tag `v1.4.0` = `f394adbacb5722ee97c1b37c8064da9a25818310` |
| Engine | https://github.com/JesseTG/melonDS (branch `jtg/fix-uninitialized-opengl`) | `16f127dbb587a73371827ce79689c5d237c4b59b` (tip on 2026-11-07; v1.4.0 names only the branch) |
| Other dependencies | as pinned by v1.4.0 `cmake/FetchDependencies.cmake` | fetched into `deps/` at configure time |

## Our patches (`patches/`, one commit each on branch `gamuroid` of the work trees)

| Patch | What |
|---|---|
| engine 0001 (C2) | `WifiAP::GetClientStatus()`, `Wifi::GetAPClientStatus()`: read-only association state of the emulated access point |
| wrapper 0001 (C4) | DSiWare TMD download (and the HTTP helper) behind CMake option `MELONDSDS_ENABLE_TMD_DOWNLOAD`, OFF: no request to Nintendo, no CDN URL in the binary; a DSiWare title without a local TMD fails with upstream's error |
| wrapper 0002 (C3) | After a DS-mode state load in Real/Relative start-time mode, the RTC date/time is set from the host clock; all other RTC registers keep the state's values; Absolute and Sync unchanged |
| wrapper 0003, 0004 (C2) | Exports `int gamuroid_net_state_get(void)` and `void gamuroid_net_state_listen(void (*)(int))`; listener called from `retro_run` only on change; 0 at each load; unload reports 0 if online; deinit forgets the listener |
| wrapper 0005 (C1) | Core option `gamuroid_screen_layout` (declared value `auto`), value `L1;canvas=WxH;upper=x,y,w,h|none;lower=x,y,w,h|none[;rev=n]`: screens drawn into the skin's boxes, pointer mapped into the lower box |

Not changed from upstream: DSi microphone (already in v1.4.0), the WFC DNS option
`melonds_firmware_wfc_dns` (the app supplies the IP), the Wiimmfi entry, the username option
(default `guess_username` = Guess), no GBA sidecar auto-load (upstream has none), JIT off
(upstream default on iOS; we also pass `ENABLE_JIT=OFF`).

## Build

```sh
scripts/fetch_sources.sh            # only on a fresh checkout: clone pins, apply patches
scripts/run_host_tests.sh           # parser + online-state unit tests (host clang, ASan/UBSan)
scripts/build_ios.sh                # -> build-ios/src/libretro/melondsds_libretro.dylib
scripts/package_framework.sh build-ios/src/libretro/melondsds_libretro.dylib out
scripts/gates.sh out/melondsds.libretro.framework build-ios/src/libretro/melondsds_libretro.dylib
```

`build_ios.sh`: CMake + Ninja, `cmake/toolchain/ios.toolchain.cmake` (PLATFORM=OS64), deployment
target 15.0, Release (melonDS's LTO), shared library, `ENABLE_JIT=OFF`, `ENABLE_OPENGL=OFF`,
`-mcpu=apple-a7 -mtune=apple-a14` (ARMv8.0 baseline), exported symbols limited to
`scripts/exports_gamuroid.txt`, `-dead_strip`, no code signing (Xcode signs on embed). It refuses to
start with less than 8 GB free or while another `xcodebuild`/`ninja` runs.

`package_framework.sh` gives the framework the app's layout: `melondsds.libretro` with install name
`@rpath/melondsds_libretro.framework/melondsds_libretro`, `Info.plist` (same keys, version 1.4.0,
MinimumOSVersion 15.0), local symbols stripped, dSYM next to it.

Identify a built core by SHA-256 and Mach-O UUID, never by `Info.plist`.
