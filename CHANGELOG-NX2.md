# Switchfin NX2 — changelog

Unofficial Switch 2 port of [Switchfin](https://github.com/dragonflylee/switchfin)
(based on upstream 0.9.5). Ported by Lucaspec72. Version numbering is
independent from upstream and starts at 1.0.0.

## v1.0.1 (2026-11-17)

First release with the in-app updater re-enabled — updates now pull from
this repository. Install the NRO as
`sdmc:/switch/SwitchfinNX2/SwitchfinNX2.nro` so the updater can replace it
(see below).

### Added

- Switch 2 (libounce / OunceVK) support: full Switchfin client — servers,
  libraries, playback (mpv), downloads, Live TV, danmaku — running at the
  display's native resolution (1080p handheld, up to 4K docked), with the
  homebrew tile reading **"Switchfin NX2"**.
- In-app self-update (Settings → Others): checks
  `Lucaspec72/switchfin` releases and downloads the new `SwitchfinNX2.nro`
  into the app's config dir, then exits so you can relaunch.

### Changed

- **AV1 preferred**: default transcode codec is AV1 instead of H.264, and
  the DirectPlay device profile advertises `av1,h264,hevc,vp9` — the
  Switch 2 decodes AV1 in hardware (dav1d software fallback is built in).
  A codec explicitly chosen in Settings → Playback is honoured as before.
- Quitting the app returns to the homebrew menu instead of the console
  HOME menu.
- Identity: separate executable/config from upstream Switchfin
  (`sdmc:/switch/SwitchfinNX2/`), GitHub links point at
  `Lucaspec72/switchfin`, NRO author "Lucaspec72".

### Install / update notes

- Copy `SwitchfinNX2.nro` to `sdmc:/switch/SwitchfinNX2/SwitchfinNX2.nro`.
  With that layout, in-app updates land on the file hbmenu launches —
  after an update just relaunch the tile. If you keep the NRO elsewhere,
  the downloaded update appears in `sdmc:/switch/SwitchfinNX2/` instead
  and you need to move it over manually.
- Release assets must be named `SwitchfinNX2.nro` and tags follow
  `v1.0.x` (the updater compares versions numerically).
