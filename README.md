# wine-cachyos (Nix)

[wine-cachyos](https://github.com/CachyOS/wine-cachyos) from the
[CachyOS](https://cachyos.org) team, packaged for NixOS. It is Valve's Proton
Wine tree with CachyOS patches, built as a plain system Wine for Bottles,
Lutris, Heroic or a bare `wine` command. It is not a Steam compatibility tool.
That one is `proton-cachyos`, packaged in
[proton-cachyos-nix](https://github.com/Daaboulex/proton-cachyos-nix).

It builds for `x86_64-linux` only. The checks prove that every channel builds,
carries the 64-bit and the 32-bit Windows libraries and reports its version. No
check starts a Windows program.

## What you get

- `wine-cachyos`, the package: Wine with Gecko, Mono and Xalia. One 64-bit
  build runs both 32-bit and 64-bit Windows programs, with no 32-bit ELF stack.
- A NixOS module, `programs.wine-cachyos`, that installs the package and sets
  up what upstream ships as Arch drop-ins: the `ntsync` kernel module, the
  Win32 font aliases and, if you ask for it, the binfmt registration.
- A frozen channel per Wine major next to the rolling one.

## Install

Add the flake:

```nix
{
  inputs.wine-cachyos = {
    url = "github:Daaboulex/wine-cachyos-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Then import the module and switch it on. The overlay is needed, because the
module installs `pkgs.wine-cachyos`.

```nix
{
  imports = [ inputs.wine-cachyos.nixosModules.default ];
  nixpkgs.overlays = [ inputs.wine-cachyos.overlays.default ];

  programs.wine-cachyos.enable = true;
}
```

Without the module, take the package directly:

```nix
environment.systemPackages = [
  inputs.wine-cachyos.packages.${pkgs.stdenv.hostPlatform.system}.default
];
```

Or apply `inputs.wine-cachyos.overlays.default` and use `pkgs.wine-cachyos`.

Either way `wine` is then on the path. Run a program with it, or point Bottles,
Lutris or Heroic at it.

## Options you are likely to set

All of these sit under `programs.wine-cachyos`.

| Option | Default | What it is for |
|---|---|---|
| `binfmt.enable` | off | Run Windows executables directly, through `binfmt_misc` |
| `ntsync.enable` | on | Load the `ntsync` kernel module at boot |
| `fontAliases.enable` | on | Install upstream's fontconfig aliases for the Win32 logical font names |

Every option, with its type and default: [docs/OPTIONS.md](docs/OPTIONS.md).

## Channels

`pkgs.wine-cachyos` rolls with every upstream `*-wine` tag. Each Wine major
also has a frozen channel, so a prefix built against it keeps working after
upstream moves on. To stay on one, point the module at it:

```nix
programs.wine-cachyos.package = pkgs.wine-cachyos.v10;
```

The channels that exist are the ones in [sources.nix](sources.nix).

## Known limits

- `x86_64-linux` only. Upstream builds for x86_64 alone and the build carries
  x86-specific compiler flags.
- Upstream publishes this Wine as source only, so it is built from the
  `*-wine` git tags.
- It is Wine only. DXVK, VKD3D-Proton and the Steam Linux Runtime glue belong
  to `proton-cachyos`.
- `ntsync.enable` needs a kernel that provides the `ntsync` module. Without
  ntsync Wine falls back to esync/fsync.
- `binfmt.enable` is system-wide. It routes every Windows executable on the
  host through this Wine, not only the ones you meant, which is why it is off
  by default.
- Xalia, upstream's gamepad-driven UI navigator, is installed but off. Wine
  starts it only when `PROTON_USE_XALIA=1` is set in the environment.

## More

- [docs/DESIGN.md](docs/DESIGN.md): how it relates to `proton-cachyos`, what
  comes from nixpkgs, where it deviates from the Arch package and why
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md): building, the checks, how the
  channels and the updater work
- [SECURITY.md](SECURITY.md): how to report a vulnerability

## License

The packaging is MIT. Wine itself is LGPL-2.1-or-later; Gecko, Mono, and Xalia
carry their own licences and are fetched from their upstreams at build time.
This flake redistributes nothing.
