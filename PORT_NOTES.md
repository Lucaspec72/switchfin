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
  gates Switch 2 specifics. App source files: only `version.cpp` changed
  (see identity below).
- **Rebrand: "Switchfin NX2".** `PROJECT_NAME` becomes `SwitchfinNX2` for
  Switch 2 builds (target, `SwitchfinNX2.nro`, config dir
  `sdmc:/switch/SwitchfinNX2` — fully separate from an installed upstream
  Switchfin), while the homebrew-menu tile reads **"Switchfin NX2"**
  (NACP name, via a dedicated `NX2_TITLE`). Author (NACP) = **Lucaspec72**.
  Upstream identity/credits elsewhere are untouched.
- **Version: the port carries its own line, currently `1.0.3`** (upstream
  base is 0.9.5). NACP/display version = 1.0.3, shown by hbmenu and
  Settings → About. Tag NX2 releases `v1.0.0`, `v1.0.1`, `v1.0.2`, `v1.0.3`, … —
  they will always compare
  above upstream's 0.x line, and the version can't collide with upstream's
  own numbering.
- **GitHub links retargeted** (`config.hpp` `git_repo`): Switch 2 builds
  point at **`Lucaspec72/switchfin`** (Settings → GitHub link, update
  endpoints); upstream keeps `dragonflylee/switchfin` everywhere else.
- **AV1 preferred** on Switch 2: default transcode codec (`mpv_core.hpp`
  `VIDEO_CODEC`) is `av1` instead of `h264`, and the DirectPlay device
  profile lists `av1,h264,hevc,vp9` (the Switch 2 decodes AV1 in hardware).
  A codec explicitly chosen in Settings is honoured as before.
- **Self-update re-enabled (2026-11-17, v1.0.1)**: the updater now points at
  this fork (`Lucaspec72/switchfin`, via `config.hpp` `git_repo`) and
  expects an asset named `SwitchfinNX2.nro` on a `v1.0.x` tag. The download
  lands in `sdmc:/switch/SwitchfinNX2/` — so the app should be installed at
  `sdmc:/switch/SwitchfinNX2/SwitchfinNX2.nro` for the update to replace the
  file hbmenu launches (same store-style layout upstream's updater assumes
  for hb-appstore installs). `getPlatform()` returns "NX2" for this build
  (User-Agent / device label on the Jellyfin server).
- **Quit returns to hbmenu** (`borealis .../switch_platform.cpp`
  `exitToHomeMode`): upstream sets libnx's `__nx_applet_exit_mode` so the
  app exits to the console HOME menu; the NX2 build ignores it and keeps
  libounce's default (return to the homebrew menu that launched the NRO).
- **Identity summary:** Switch 2 builds are **Switchfin NX2 v1.0.x** by
  **Lucaspec72** (NACP), config dir `sdmc:/switch/SwitchfinNX2/`, GitHub
  links at `Lucaspec72/switchfin`; upstream's own identity/credits
  (title ids, package, README body) are untouched.

## Display resolution (Switch 2 native res)

Upstream's Switch 1 GLFW path renders a fixed 1280x720 window (Switch 1
panel size) — on the Switch 2's 1080p handheld display that showed up as a
720p box anchored bottom-left. `borealis .../glfw/glfw_video.cpp` has a
`__SWITCH2__` path that fixes this:
- constructor and `beginFrame()`: the GLFW window size is pinned to
  **1920x1080** (switch-glfw's fixed `FB_WIDTH`/`FB_HEIGHT`). `beginFrame()`
  still checks each frame and re-applies 1920x1080 if needed, because
  switch-glfw's own applet hook resizes the window to a hardcoded 1280x720 on
  undock. The framebuffer-size callback updates the borealis layout (virtual
  canvas = 1920x1080, scaleFactor 1 — same as docked Switch 1).

Why not `appletGetDefaultDisplayResolution()` (the initial 1.0.0 approach)?
`switch-glfw`'s Switch backend does **not** resize its framebuffer on
`glfwSetWindowSize(w, h)` — it hardcodes the native NWindow to 1920x1080 and
sets a **bottom-left crop** of it (`nwindowSetCrop(nwin, 0, 1080-h, w, 1080)`);
VI2 scales the whole 1920x1080 framebuffer to the attached display. The applet
call reports 1280x720 when docked to a 720p TV, so using it sized the crop to
720p and the UI ended up as a small box in the bottom-left corner — the same
failure mode as the original hardcoded-720p build. Rendering at the full
1920x1080 keeps the image filling 720p/1080p/4K displays alike (VI2 does the
scaling), and avoids asking switch-glfw for a size above its 1920x1080 cap.

Note: the UI (nanovg over GL) draws at 1920x1080; at 4K docked VI2 upscales
it (native 4K rendering is impossible with switch-glfw's fixed framebuffer).
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
   elf2nro commands — they exist in the devkit image regardless of target);
   Switch 2 identity block (version 1.0.x, `SwitchfinNX2`, "Switchfin NX2",
   author).
3. `app/src/utils/version.cpp`: `getPlatform()` returns "NX2"; the updater
   is active and points at the fork's releases (see identity section).
3. `app/include/utils/config.hpp`: `git_repo` = `Lucaspec72/switchfin` for
   Switch 2 builds (upstream default kept elsewhere).
4. `app/include/view/mpv_core.hpp` + `app/src/activity/player_view.cpp`:
   default transcode codec AV1 + DirectPlay profile `av1,h264,hevc,vp9` on
   Switch 2 (Switch 1 keeps `h264` / `h264,hevc,av1,vp9`).
5. `portns2.ps1`: Docker build wrapper (this file's subject).
6. `README.md`: AI-port disclaimer + Switch 2 build section;
   `CHANGELOG-NX2.md` for port release notes.
7. `.gitignore`: `build_ns2/`, `ns2/` (cache + build artifacts).

App/borealis C++ source changes: only `library/borealis .../glfw/glfw_video.cpp`
(the Switch 2 window-size fix — see the display-resolution section above).
App source files remain untouched; the app's `CMakeLists.txt` was edited for
the version lines only.

## Build status log

- **v1.0.3 (2026-11-21): BUILDS** with `ounce-devkit-20261117` — version bump
  for the docked-720p display fix (`glfw_video.cpp` pins the GLFW window to
  switch-glfw's 1920x1080 framebuffer; no `appletGetDefaultDisplayResolution`
  query). `SwitchfinNX2.nro` rebuilt from a clean `glfw_video.o` recompile.
- **v1.0.2 (2026-11-20): BUILDS** with `ounce-devkit-20261117` — adds the
  touchscreen fix (`hidSetTouchScreenOutputRanges(1920, 1080)` at the top of
  `app/src/main.cpp`, `__SWITCH2__`-only, before `brls::Application::init()`).
  That API landed in libounce on 2026-11-14, so the older `20261114` devkit
  snapshot cannot build this version; use a devkit from 2026-11-17 or later.
- **SwitchfinNX2.nro: BUILDS.** `build_ns2/SwitchfinNX2.nro` (~42.7 MB) via
  `.\portns2.ps1 build` (2026-11-17, first try beyond toolchain plumbing:
  one fix needed — the borealis Switch 2 branch needs `-I portlibs/switch/include`
  back in the flags for the GLFW headers; it lands after libounce/switch2's
  `-isystem` dirs so OunceVK headers still win).
- **Link verified** (`nm` on the final ELF): 0 undefined symbols; 384
  mimalloc symbols (so `-lnx` = libounce), 1205 zink/nvk symbols (OunceVK GL
  in the binary), glfw/mpv/egl all present. No deko3d symbols anywhere.
- **Compile-clean against libounce (at v1.0.0, zero app source edits):** all of borealis
  `lib/platforms/switch/*` (platform/input/ime/font/audio) and the whole app
  compiled unchanged; libpulsar (audren API) compiles against libounce
  headers too.
- **TESTED ON CONSOLE (2026-11-17): WORKING.** UI renders fullscreen at the
  native display resolution (native-res fix confirmed necessary — the 720p
  Switch 1 window path rendered as a box on the Switch 2 display), exit
  returns to hbmenu, playback works. The porter reports it working fine
  overall; treat remaining edge cases (4K docked performance, hardware
  decode vs software fallback, exotic codecs) as unexplored details rather
  than blockers.

## On-console results + remaining unknowns

Tested on real hardware by the porter — works well overall. Items below are
unexplored details, not known problems:

- [ ] **4K docked rendering**: the UI renders at the display's native
      resolution (1080p handheld confirmed). 4K docked performance via
      Zink/NVK is unmeasured; if heavy, cap the queried resolution to 1080p
      (one-line change in `glfw_video.cpp`, both `__SWITCH2__` spots).
- [ ] **Hardware decode**: upstream's ffmpeg is built with `--enable-nvtegra`
      (Switch 1 NVDEC hwaccel); on Switch 2 the decode service is the new
      `viddec` (switch2/services/viddec.h). The nvtegra path likely falls
      back to software decode — fine at 1080p on the A78C; a proper port
      could wire mpv/ffmpeg to libounce's `VideoDecoder` later.
- [ ] **pl:u shared fonts** (`switch_font.cpp`, `config.cpp`): CJK text
      depends on `plGetSharedFontByType`; if shared fonts ever change on a
      future Switch 2 firmware, bundled fonts in romfs would be the fallback.
- [ ] **Overclock** (`overclock.cpp`, pcv/clkrst): Switch 1 clock services;
      expected to fail silently on Switch 2 (`R_FAILED` paths) — hiding the
      UI cell is optional polish.
- [ ] **WebApplet browser** (`webPageCreate`): present in libounce headers;
      runtime behaviour unverified.
- [ ] **libretro-common `features_cpu.c`** hardcodes 4 CPU cores for the
      "number of cores" query; Switch 2 has 8. Cosmetic/threads only.
