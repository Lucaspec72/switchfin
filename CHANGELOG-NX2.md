# Switchfin NX2 — changelog

Unofficial Switch 2 port of [Switchfin](https://github.com/dragonflylee/switchfin)
(based on upstream 0.9.5). Ported by Lucaspec72. Version numbering is
independent from upstream and starts at 1.0.0.

## v1.0.2 (2026-11-20)

### Fixed

- **Touchscreen input mapping**: call `hidSetTouchScreenOutputRanges(1920, 1080)`
  at startup so touches are reported in the coordinate range the UI expects.
  Requires a libounce devkit build from 2026-11-14 or later (the older
  `ounce-devkit-20261114` snapshot predates that API).

## v1.0.1 (2026-11-17)

### Added

- **In-app self-update** (Settings → Others): checks this repository's
  releases and downloads the new `SwitchfinNX2.nro` into the app's config
  dir, then exits so you can relaunch. Releases must carry the asset
  `SwitchfinNX2.nro` and tags `v1.0.x`.

### Changed

- **AV1 preferred**: default transcode codec is now AV1 instead of H.264,
  and the DirectPlay device profile advertises `av1,h264,hevc,vp9` — the
  Switch 2 decodes AV1 in hardware (dav1d software fallback is built in).
  A codec explicitly chosen in Settings → Playback is honoured as before.
- GitHub links now point at `Lucaspec72/switchfin` instead of the original
  project (Settings → GitHub and any update endpoints).

### Install note

Updates land in `sdmc:/switch/SwitchfinNX2/`, so with this release move
your NRO to `sdmc:/switch/SwitchfinNX2/SwitchfinNX2.nro` — after that,
future in-app updates replace the file hbmenu launches automatically.

## v1.0.0 (2026-11-17)

Initial release: Switch 2 (libounce / OunceVK) support for the full
Switchfin client — servers, libraries, playback (mpv), downloads, Live TV,
danmaku — rendered at the display's native resolution (1080p handheld, up
to 4K docked). Homebrew tile: **"Switchfin NX2"**, quit returns to the
homebrew menu, separate config dir (`sdmc:/switch/SwitchfinNX2/`) so it
coexists with upstream Switchfin.
