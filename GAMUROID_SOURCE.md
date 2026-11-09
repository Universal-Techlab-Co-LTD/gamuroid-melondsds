# melonDS DS (Nintendo DS libretro core) source as shipped in Gamuroid 3.8.0

This repository is the corresponding source of the GPL-3.0-or-later component `melondsds.libretro`
(Nintendo DS / DSi libretro core) shipped inside the Gamuroid iOS app, version 3.8.0.
It is a *patch-and-pin* repository: it does not copy the upstream code, it names the exact public upstream commits and holds
Gamuroid's patches and build scripts. Together with the two upstream commits below that is the complete corresponding source.
It does NOT contain the Gamuroid app itself.

| Item | Value |
|---|---|
| Component | `melondsds.libretro` (melonDS DS wrapper + melonDS engine) |
| Licence | GPL-3.0-or-later (wrapper, engine, and Gamuroid's patches); full text in `LICENSE` (copied unchanged from the wrapper at `v1.4.0`) |
| Upstream wrapper | https://github.com/JesseTG/melonds-ds, tag `v1.4.0` = `f394adbacb5722ee97c1b37c8064da9a25818310` |
| Upstream engine | https://github.com/JesseTG/melonDS, branch `jtg/fix-uninitialized-opengl`, commit `16f127dbb587a73371827ce79689c5d237c4b59b` |
| Other dependencies | fetched at configure time; full commit ids in `scripts/pins.env` (`DEP_*`) |
| Shipped from (informational) | Gamuroid's private build workspace `melondsds-gamuroid`, commit `2332341`; not fetchable. This repository holds that commit's patches and scripts plus a text-only change to `scripts/gates.sh` (no code change), so nothing else is needed to rebuild |
| Binary it builds | `melondsds.libretro`, SHA-256 `cb5a71284a2520e296a8efef9bbdfa16b8d8a8a372fb3b20bb66e87526d614ad`, Mach-O UUID `96E5C976-FC24-3EAD-8B19-9F694C2E8283`, 2,807,752 bytes |

## Build recipe

Toolchain used: Xcode (iPhoneOS SDK), CMake, Ninja, Python 3, deployment target iOS 15.0, arm64 (`-mcpu=apple-a7 -mtune=apple-a14`).

```sh
git clone https://github.com/Universal-Techlab-Co-LTD/gamuroid-melondsds
cd gamuroid-melondsds && git checkout gamuroid-3.8.0
scripts/fetch_sources.sh        # clones the two upstream commits into work/ and applies patches/ as commits on branch "gamuroid"
scripts/run_host_tests.sh       # optional: parser and online-state unit tests on the host
scripts/build_ios.sh            # -> build-ios/.../melondsds_libretro.dylib (Release, ENABLE_JIT=OFF, ENABLE_OPENGL=OFF)
scripts/package_framework.sh build-ios/src/libretro/melondsds_libretro.dylib out
scripts/gates.sh out/melondsds.libretro.framework build-ios/src/libretro/melondsds_libretro.dylib
```

`build_ios.sh` uses the dependency tags of the wrapper's own `cmake/FetchDependencies.cmake`; `scripts/pins.env` lists the full commit
ids those resolved to (looked up 2026-11-09). The binary is not guaranteed to be bit-identical across machines; compare exports
(`scripts/exports_gamuroid.txt`) and the gates.

## Gamuroid modifications (the patches in `patches/`)

- engine 0001 (C2): read-only accessor for the emulated access point's client association state.
- wrapper 0001 (C4): no DSiWare TMD download from Nintendo servers (CMake option `MELONDSDS_ENABLE_TMD_DOWNLOAD`, OFF).
- wrapper 0002 (C3): RTC resynchronised to the host clock after a DS-mode state load.
- wrapper 0003, 0004 (C2): exports `gamuroid_net_state_get` / `gamuroid_net_state_listen` (online-state reporting to the host).
- wrapper 0005 (C1): core option `gamuroid_screen_layout` (screens drawn into host-defined boxes).
- Build scripts, export list, option-key list and release gates in `scripts/`; host unit tests in `tests/`.

Upstream copyright and licence headers are unchanged (they are in the upstream commits named above).
