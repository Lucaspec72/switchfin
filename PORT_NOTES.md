# Switchfin Switch 2 (NS2) port — PORT NOTES

**What:** Switchfin (Jellyfin client for PC/PS4/PSVita/Switch) ported to
**Switch 2** on top of the libounce runtime + OunceVK graphics stack
(libnx-compatible API; graphics = Zink/NVK GL via EGL). The port reuses the
upstream **Switch (PLATFORM_SWITCH)** code paths almost verbatim — the app code
is untouched; only the build system grew a `PLATFORM_SWITCH2` branch.

Upstream: https://github.com/dragonflylee/switchfin — this tree carries the
port on top of upstream commit `90dd8ea` (dev branch).

## Build

```powershell
.\portns2.ps1 build      # -> build_ns2/Switchfin.nro
.\portns2.ps1 clean
.\portns2.ps1 shell      # interactive bash in the build container
```

Requirements: Docker Desktop running + the Switch 2 devkit drop
(`ounce-devkit-<date>` with `libounce/`, `portlibs/switch2/`,
`switch2vars.sh`) — found automatically in the repo folder or any parent
directory, or via `$env:SWITCH2_DEVKIT` (needed when the repo lives outside
the NS2 Porting workspace tree, as here).

The first run downloads six prebuilt portlib packages (git-ignored under
`ns2/cache/`) from upstream's `switch-portlibs` GitHub release; every build
`pacman -U`s them into the image's `portlibs/switch` (takes a few seconds,
containers are `--rm`).

## Design decisions

- **`PLATFORM_SWITCH2` keeps `-D__SWITCH__` defined.** All app and borealis
  Switch code paths (`__SWITCH__` gates) compile unchanged; `__SWITCH2__`
  (added automatically by the libounce toolchain, and in borealis' branch)
  gates Switch 2 specifics. App source files did not need any edits.
- **Identity:** the Switch 2 NRO's homebrew-menu author (NACP) is
  **Lucaspec72** (the porter); the app title stays "Switchfin" and all
  upstream identity/credits (title id, package name, README) are untouched.
- **Graphics: the borealis GLFW + mpv-OpenGL path.** On Switch the borealis
  GLFW branch requests **GL 4.3 core** through devkitPro's `switch-glfw`
  (3.3.4, whose Switch backend needs only `applet*`/`hid*`/`nwindow*`/EGL —
  all present in libounce/OunceVK). Link line `glfw3 EGL glapi drm_nouveau nx m`
  resolves on Switch 2 as: `libEGL.a` → OunceVK Zink/NVK stub,
  `libglapi.a`/`libdrm_nouveau.a` → the empty Switch 2 shadow archives,
  `libnx` → libounce, `libglfw3.a` → Switch 1 portlib (static, CPU-agnostic
  ARMv8 code runs fine on the A78C).
- **mpv: the "opengl-driver" libmpv 0.36.0** from upstream's
  `switch-portlibs` release (the deko3d variant is Switch 1 only). Verified
  with `nm`: **no deko3d symbols** in libmpv or libavcodec — the GL render
  path (`mpv_core.cpp` `MPV_RENDER_API_TYPE_OPENGL` branch, already taken on
  non-deko3d Switch builds) needs only EGL/GL function pointers, so the whole
  video stack is driver-agnostic.
- **Portlibs = upstream's own prebuilt packages**, i.e. exactly what the
  upstream CI installs for the Switch build: `mbedtls 3.6.7`, `libssh2 1.11.1`,
  `dav1d 1.5.4`, `curl 8.23.0`, `ffmpeg 7.1.5`, `libmpv 0.36.0`. The
  devkita64 image already ships `switch-glfw`, `switch-libwebp`, `libass`,
  and the rest of the closure.
- **Disabled for Switch 2 (v1):** `USE_LIBUSBHSFS` (USB drives; libnx USB
  stack rebuild unknown), `USE_MUPDF` (ebook reader; optional), `BUILTIN_NSP`
  (forwarder NSP). None are required for the main client.
- **libpulsar kept.** Its audren player code is dead in borealis (all calls
  commented out); it compiles against libounce's audren headers. If that ever
  breaks, drop `lib/extern/switch-libpulsar` sources for Switch 2.

## What changed vs upstream

1. `library/borealis` (submodule, branch `switch2`, based on upstream pin
   `0303fe7f`):
   - `cmake/commonOption.cmake`: `PLATFORM_SWITCH2` option; map link option
     included.
   - `cmake/toolchain.cmake`: `PLATFORM_SWITCH2` branch — includes
     `$DEVKITPRO/libounce/cmake/Switch2.cmake` instead of devkitPro's
     `Switch.cmake`, defines `-D__SWITCH__ -D__SWITCH2__`, defaults GLFW on.
     Note: unlike the Switch 1 branch it adds **no** `-I` for libnx/switch
     portlibs — libounce's platform file puts libounce + switch2 portlibs
     headers first, and everything else comes from `.pc` files.
   - `library/CMakeLists.txt`: the Switch platform branch (switch sources +
     switch-libpulsar + GLFW/GL driver) is now taken for
     `PLATFORM_SWITCH OR PLATFORM_SWITCH2`, with `-D__SWITCH2__` added to the
     Switch 2 defines.
2. Top-level `CMakeLists.txt`: `switch_wrapper.c` compiled for Switch 2 as
   well; the `.nro` creation target runs for Switch 2 too (same nacptool /
   elf2nro commands — they exist in the devkit image regardless of target).
3. `portns2.ps1`: Docker build wrapper (this file's subject).
4. `README.md`: AI-port disclaimer + Switch 2 build section.
5. `.gitignore`: `build_ns2/`, `ns2/` (cache + build artifacts).

App/borealis C++ source files: **zero changes so far.**

## Build status log

- **Switchfin.nro: BUILDS.** `build_ns2/Switchfin.nro` (~42.7 MB) via
  `.\portns2.ps1 build` (2026-11-17, first try beyond toolchain plumbing:
  one fix needed — the borealis Switch 2 branch needs `-I portlibs/switch/include`
  back in the flags for the GLFW headers; it lands after libounce/switch2's
  `-isystem` dirs so OunceVK headers still win).
- **Link verified** (`nm` on the final ELF): 0 undefined symbols; 384
  mimalloc symbols (so `-lnx` = libounce), 1205 zink/nvk symbols (OunceVK GL
  in the binary), glfw/mpv/egl all present. No deko3d symbols anywhere.
- **Compile-clean against libounce, zero source edits:** all of borealis
  `lib/platforms/switch/*` (platform/input/ime/font/audio) and the whole app
  compiled unchanged; libpulsar (audren API) compiles against libounce
  headers too.
- **First on-console test is the next milestone** — see the open-risks
  checklist below (GL 4.3 core via Zink/NVK, nvtegra hwdec fallback to
  software, pl:u shared fonts, audren).

## Open risks / on-console TODO (first Switchfin.nro test)

- [ ] **GL 4.3 core via Zink/NVK**: borealis requests a 4.3 core context;
      OunceVK is Zink over NVK. If the context comes back lower/fails, add a
      `USE_GLES3` fallback (GLES 3.1, borealis + nanovg already support it).
- [ ] **nvtegra hardware decode**: upstream's ffmpeg is built with
      `--enable-nvtegra` (Switch 1 NVDEC hwaccel). On Switch 2 the decode
      service is the new `viddec` (switch2/services/viddec.h) — the nvtegra
      hwaccel will likely fail at runtime and fall back to software decode.
      An A78C at 1080p H.264/HEVC software decode should be workable; AV1 via
      dav1d is software too. A proper port would wire mpv/ffmpeg to the
      `VideoDecoder` (libounce switch2/video/decoder.h) later.
- [ ] **pl:u shared fonts** (`switch_font.cpp`, `config.cpp`): if shared
      fonts are gone on the Switch 2 OS, CJK text falls back to bundled
      fonts; verify `plGetSharedFontByType` behaviour on console.
- [ ] **audren**: mpv audio goes through the audren shim (via ffmpeg
      libavdevice? — verify which output mpv uses). If audren doesn't work on
      Switch 2, port to `audu` (switch2/services/audu.h).
- [ ] **`__nx_applet_exit_mode`** (`switch_platform.cpp`): libnx crt
      internal; link verifies it exists in libounce, semantics untested.
- [ ] **Overclock** (`overclock.cpp`, pcv/clkrst): Switch 1 clock services.
      Expect silent failure on Switch 2 (no crash expected — `R_FAILED`
      checks); hiding the UI cell is optional polish.
- [ ] **nxlink** (`switch_wrapper.c`, DEBUG only): stdout debug should work
      via socket/bsd as on Switch 1.
- [ ] **Self-update** (`version.cpp`): `romfsExit()` + nro rename over its
      own file — verify romfs semantics under libounce.
- [ ] **WebApplet browser** (`webPageCreate`): present in libounce headers;
      runtime behaviour unknown.
- [ ] **libretro-common `features_cpu.c`** hardcodes 4 CPU cores for the
      "number of cores" query; Switch 2 has 8. Cosmetic/threads only.
