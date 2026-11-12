# Design

## Upstream

| | |
|---|---|
| Project | [CachyOS/wine-cachyos](https://github.com/CachyOS/wine-cachyos) |
| License | LGPL-2.1-or-later (Wine) |
| Tracked | GitHub tags matching `-wine` (`cachyos-<version>-<date>-wine`) |

## wine-cachyos and proton-cachyos

CachyOS ships two things from one Wine tree. `proton-cachyos` is a Steam Play
compatibility tool, a whole runtime bundle, and is packaged separately in
[proton-cachyos-nix](https://github.com/Daaboulex/proton-cachyos-nix).
`wine-cachyos` is a plain system Wine you point Bottles, Lutris, Heroic or a
bare `wine` invocation at.

| | `proton-cachyos` | `wine-cachyos` (this repo) |
|---|---|---|
| What it is | Steam Play compatibility tool | A system Wine (`bin/wine`) |
| Ships | Wine + DXVK + VKD3D-Proton + Steam Linux Runtime glue + `proton` entry script + `compatibilitytool.vdf` | Wine only (plus Gecko, Mono, Xalia) |
| Delivered as | prebuilt release tarballs | source only, built from `*-wine` git tags |
| Consumed by | Steam, via `programs.steam.extraCompatPackages` | Bottles, Lutris, Heroic, plain `wine` |
| Upstream tag stream | `*-proton-slr` / `*-proton-native` | `*-wine` |

They are siblings, not rivals. At the same date the `*-wine` tag is the
`*-proton-slr` tag plus roughly 60 commits that turn the Proton tree into a
standalone Wine, and both sit about a thousand commits above the shared
`*-base` tag. Upstream advances the two streams independently, so their
versions differ.

## How it is built

The flake builds from source in Wine's new WoW64 mode
(`--enable-archs=x86_64,i386`), so one 64-bit build runs both 32-bit and 64-bit
Windows programs with no 32-bit ELF stack.

It inherits nixpkgs' Wine closure. The derivation is nixpkgs'
`wineWow64Packages.stableFull` with upstream's source, patch set and build
flags applied on top. Every support flag, dependency and NixOS integration
nixpkgs validates comes along, and only what CachyOS actually changes is
overridden.

The build flags are upstream's. They are Proton's portable optimization set,
verbatim from upstream's PKGBUILD (`-march=nocona -mtune=core-avx2
-mfpmath=sse`, with AVX, AVX2 and AVX-512 explicitly off), so the result runs
on any x86-64 machine in a mixed fleet.

The runtime pins are upstream's too. The rolling channel ships Gecko 2.47.4 and
Mono 10.4.1, the exact versions this Wine tree's `dlls/appwiz.cpl/addons.c`
asks for, plus Xalia 0.4.8. The live values, for every channel, are in
[`sources.nix`](../sources.nix).

Dependencies are covered by construction. Every `--with-*` is passed
explicitly, so a dependency that ever goes missing fails the build instead of
being autodetected away into a silently reduced Wine.

## Deliberate deviations from the Arch package

| Upstream does | Here | Why |
|---|---|---|
| `-s` in the host `CFLAGS` | dropped for the host build, kept for the PE cross build | Nix strips ELF output in `fixupPhase`; `-s` on the host link would fight the RPATH handling Wine needs. PE files are not touched by that phase, so the flag stays where it still does work. |
| `LDFLAGS="-Wl,-O1,--sort-common,--as-needed"` | not set for the host link | nixpkgs owns host link flags (RPATH injection, hardening). `CROSSLDFLAGS` is applied unchanged. |
| Gecko/Mono shipped as extracted tarballs | shipped as the `.msi` files | `dlls/appwiz.cpl/addons.c` looks for `wine-gecko-<ver>-<arch>.msi` under `$WINEDATADIR`; the `.msi` layout is what nixpkgs proves works. Same versions either way. |
| `modules-load.d` and `binfmt.d` | native NixOS options in [`module.nix`](../module.nix) | Declarative equivalents, no vendored config files. |
| `30-win32-aliases.conf` installed into fontconfig's `conf.avail` and linked into `conf.default` | the same file, read from the pinned PKGBUILD input, validated against fontconfig's DTD at build time and installed as `/etc/fonts/conf.d/30-win32-aliases.conf` | One source: the bytes are upstream's and the weekly lock refresh re-reads them. A conf.d drop-in is a complete document of its own; `fonts.fontconfig.localConf` is written raw by NixOS, so it stays free for the user's own aliases. |
| builds against Arch's toolchain | pre-10 channels add `-std=gnu17` | Wine trees older than 10 use `bool` as an identifier, which C23, gcc 15's default, reserves as a keyword. Same one-flag fix nixpkgs applies to its own older Wine variant. |

## The module

The NixOS module installs the package and wires the three system-level pieces
upstream ships as Arch drop-ins: the `ntsync` kernel module, the Win32 font
aliases and the binfmt registration.

`binfmt.enable` is off by default because the registration is system-wide. It
routes every Windows executable on the host through this Wine, not only the
ones you meant.

The font aliases cover the Win32 logical font names `MS Shell Dlg`,
`MS Shell Dlg 2` and `MS Sans Serif`, which fontconfig's own metric aliases do
not cover.

## Xalia

Xalia, upstream's gamepad-driven UI navigator, is installed at `share/xalia`
and is opt-in at runtime. Wine only starts it when `PROTON_USE_XALIA=1` is set
in the environment.

## Architecture

`x86_64-linux` only. Upstream declares `arch=(x86_64)` and the build carries
x86-specific flags (`-march=nocona`, `-mfpmath=sse`). The reason is recorded in
[`.github/update.json`](../.github/update.json) under `platforms`.
