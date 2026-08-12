# wine-cachyos (Nix)

<!-- BEGIN generated:badges -->
[![CI](https://github.com/Daaboulex/wine-cachyos-nix/actions/workflows/ci.yml/badge.svg)](https://github.com/Daaboulex/wine-cachyos-nix/actions/workflows/ci.yml)
[![NixOS unstable](https://img.shields.io/badge/NixOS-unstable-78C0E8?logo=nixos&logoColor=white)](https://nixos.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
<!-- END generated:badges -->

Nix flake packaging for [wine-cachyos](https://github.com/CachyOS/wine-cachyos) by the [CachyOS](https://cachyos.org) team - Valve's Proton Wine tree with CachyOS patches, built as a general-purpose system Wine (not a Steam compatibility tool).

<!-- BEGIN generated:upstream -->
## Upstream

| | |
|---|---|
| **Project** | [CachyOS/wine-cachyos](https://github.com/CachyOS/wine-cachyos) |
| **License** | LGPL-2.1-or-later (Wine) |
| **Tracked** | GitHub tags matching `-wine` (`cachyos-<version>-<date>-wine`) |

<!-- END generated:upstream -->

## What Is This?

CachyOS ships two things from one Wine tree. `proton-cachyos` is a **Steam Play compatibility tool** - a whole runtime bundle - and is packaged separately in [proton-cachyos-nix](https://github.com/Daaboulex/proton-cachyos-nix). `wine-cachyos` is a **plain system Wine** you point Bottles, Lutris, Heroic, or a bare `wine` invocation at.

| | `proton-cachyos` | `wine-cachyos` (this repo) |
|---|---|---|
| What it is | Steam Play compatibility tool | A system Wine (`bin/wine`) |
| Ships | Wine + DXVK + VKD3D-Proton + Steam Linux Runtime glue + `proton` entry script + `compatibilitytool.vdf` | Wine only (plus Gecko, Mono, Xalia) |
| Delivered as | prebuilt release tarballs | source only - built from `*-wine` git tags |
| Consumed by | Steam, via `programs.steam.extraCompatPackages` | Bottles, Lutris, Heroic, plain `wine` |
| Upstream tag stream | `*-proton-slr` / `*-proton-native` | `*-wine` |

They are siblings, not rivals: at the same date the `*-wine` tag is the `*-proton-slr` tag plus roughly 60 commits that turn the Proton tree into a standalone Wine, and both sit about a thousand commits above the shared `*-base` tag. Upstream advances the two streams independently, so their versions differ.

This flake builds it from source in Wine's **new WoW64** mode (`--enable-archs=x86_64,i386`), so one 64-bit build runs both 32-bit and 64-bit Windows programs with no 32-bit ELF stack.

- **Inherits nixpkgs' Wine closure** - the derivation is nixpkgs' `wineWow64Packages.stableFull` with upstream's source, patch set, and build flags applied on top. Every support flag, dependency, and NixOS integration nixpkgs validates comes along; only what CachyOS actually changes is overridden.
- **Faithful build flags** - Proton's portable optimization set verbatim from upstream's PKGBUILD (`-march=nocona -mtune=core-avx2 -mfpmath=sse`, AVX/AVX2/AVX-512 explicitly off), so the result runs on any x86-64 machine in a mixed fleet.
- **Faithful runtime pins** - Gecko 2.47.4 and Mono 10.4.1, the exact versions this Wine tree's `dlls/appwiz.cpl/addons.c` asks for, plus Xalia 0.4.8.
- **Package integrity** - SRI hashes on every fetched artifact, verified on each build.
- **Upstream trust** - automated tag detection, hash recomputation, and a verified test build, auto-committed to `main`.
- **Stale cleanup** - weekly `flake.lock` refresh (pushed only if it still builds); orphaned update branches older than 30 days are deleted.

### Deliberate deviations from the Arch package

| Upstream does | Here | Why |
|---|---|---|
| `-s` in the host `CFLAGS` | dropped for the host build, kept for the PE cross build | Nix strips ELF output in `fixupPhase`; `-s` on the host link would fight the RPATH handling Wine needs. PE files are not touched by that phase, so the flag stays where it still does work. |
| `LDFLAGS="-Wl,-O1,--sort-common,--as-needed"` | not set for the host link | nixpkgs owns host link flags (RPATH injection, hardening). `CROSSLDFLAGS` is applied unchanged. |
| Gecko/Mono shipped as extracted tarballs | shipped as the `.msi` files | `dlls/appwiz.cpl/addons.c` looks for `wine-gecko-<ver>-<arch>.msi` under `$WINEDATADIR`; the `.msi` layout is what nixpkgs proves works. Same versions either way. |
| `modules-load.d`, `binfmt.d`, and a fontconfig drop-in | native NixOS options in `module.nix` | Declarative equivalents, no vendored config files. |
| builds against Arch's toolchain | pre-10 channels add `-std=gnu17` | Wine trees older than 10 use `bool` as an identifier, which C23 - gcc 15's default - reserves as a keyword. Same one-flag fix nixpkgs applies to its own older Wine variant. |

## Channels

`sources.nix` holds the rolling `version` plus a `pins` map of frozen tags; the
live truth is that file. Every channel hangs off the package as passthru.

| Channel | Attribute | Tag |
|---|---|---|
| `latest` (also `packages.default`) | `pkgs.wine-cachyos` | newest `*-wine` tag |
| `v<major>` | `pkgs.wine-cachyos.v10` | that major's newest packaged tag |

`latest` rolls with every upstream `*-wine` tag; each `v<major>` freezes one
major so a prefix built against it keeps working after upstream moves on. The
rolling version always owns its own major, so when CachyOS cuts the first
`cachyos-11.0-<date>-wine` tag the updater picks it up as `latest` + `v11` and
the 10.x line stays available as `v10` by moving it into `pins`.

Upstream advances this stream slowly: the newest `*-wine` tag as of 2026-07-24 is
`cachyos-10.0-20260425-wine` (Wine 10.0), while mainline Wine is at 11.0 stable /
11.13 development. CachyOS's 11.0 work currently lives only in the `*-base` and
`*-proton-*` streams, which are not this package - so this flake does not
fabricate an `11` channel out of them.

## Staying in step with upstream

Nothing this flake mirrors from upstream is left to be noticed by hand. Two
checks run in `nix flake check`, so they gate every push, and also gate the
daily updater's verification build - a drift cannot be committed, and the
standard's workflow files the issue.

- **`runtime-pins`** reads each channel's own source tree and asserts the Gecko
  and Mono versions it ships are exactly the ones `dlls/appwiz.cpl/addons.c`
  declares. Ship the wrong Mono and Wine silently asks the user to download it
  at prefix creation while every build stays green - this makes that
  impossible. It needs only the fetched source, so it fails in seconds rather
  than after a full compile, and it is checked per channel because different
  Wine majors want different runtimes.
- **`upstream-recipe`** pins CachyOS's own `PKGBUILD` as a flake input, so the
  weekly `flake.lock` refresh re-reads it. It compares the Gecko, Mono and Xalia
  versions and every `configure` flag against what this flake actually passes,
  and names the file to edit when they diverge. The comparison only applies while
  upstream's `_srctag` matches the packaged tag - when upstream moves first it
  says so and passes, because the daily updater is what advances the tag.

Dependencies themselves are covered by construction: every `--with-*` is passed
explicitly, so a dependency that ever goes missing fails the build instead of
being autodetected away into a silently reduced Wine.

## Architecture

`x86_64-linux` only. Upstream declares `arch=(x86_64)` and the build carries x86-specific flags (`-march=nocona`, `-mfpmath=sse`); the reason is recorded in `.github/update.json` `platforms`.

<!-- BEGIN generated:installation -->
## Installation

Add as a flake input:

```nix
{
  inputs.wine-cachyos = {
    url = "github:Daaboulex/wine-cachyos-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Then either take the package directly:

```nix
environment.systemPackages = [
  inputs.wine-cachyos.packages.${pkgs.system}.default
];
```

or apply `inputs.wine-cachyos.overlays.default` and use `pkgs.wine-cachyos`.

<!-- END generated:installation -->

## Usage

The NixOS module installs the package and wires the three system-level pieces upstream ships as Arch drop-ins:

```nix
{
  imports = [ inputs.wine-cachyos.nixosModules.default ];
  nixpkgs.overlays = [ inputs.wine-cachyos.overlays.default ];

  programs.wine-cachyos = {
    enable = true;
    ntsync.enable = true;      # default: load the ntsync kernel module
    fontAliases.enable = true; # default: Win32 logical font names
    binfmt.enable = false;     # default: do NOT claim every MZ binary
  };
}
```

`binfmt.enable` is off by default because the registration is system-wide: it routes *every* Windows executable on the host through this Wine, not only the ones you meant.

To stay on a frozen major instead of the rolling one, point the module at that channel:

```nix
programs.wine-cachyos.package = pkgs.wine-cachyos.v10;
```

Xalia (upstream's gamepad-driven UI navigator) is installed at `share/xalia` and is opt-in at runtime - Wine only starts it when `PROTON_USE_XALIA=1` is set in the environment.

## License

The packaging is MIT. Wine itself is LGPL-2.1-or-later; Gecko, Mono, and Xalia carry their own licences and are fetched from their upstreams at build time - this flake redistributes nothing.

<!-- BEGIN generated:footer -->
<!-- END generated:footer -->
