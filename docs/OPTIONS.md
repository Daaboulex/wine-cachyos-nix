# Options

Every option the modules of this flake declare. This file is generated from the module sources: change a description there, then run `nix run .#std-write-option-reference`.

## NixOS module

Declared in [module.nix](../module.nix).

### `programs.wine-cachyos.enable`

Whether to enable wine-cachyos, Wine with the CachyOS and Proton patch set.

Type: `boolean`. Default: `false`.

### `programs.wine-cachyos.package`

The wine-cachyos package to install. Requires this flake's overlay.

Type: `package`. Default: `pkgs.wine-cachyos`.

### `programs.wine-cachyos.binfmt.enable`

Register Windows executables with `binfmt_misc` so they can be run
directly, mirroring upstream's `wine-binfmt.conf`. Off by default: the
registration is system-wide and routes every `MZ` binary through this
Wine, not only the ones you intended.

Type: `boolean`. Default: `false`.

### `programs.wine-cachyos.fontAliases.enable`

Install upstream's fontconfig aliases for the Win32 logical font names
(`MS Shell Dlg`, `MS Shell Dlg 2`, `MS Sans Serif`), which fontconfig's
own metric aliases do not cover.

Type: `boolean`. Default: `true`.

### `programs.wine-cachyos.ntsync.enable`

Load the `ntsync` kernel module at boot, mirroring upstream's
`modules-load.d` drop-in. ntsync is the in-kernel NT synchronization
primitive this Wine build prefers; without it Wine falls back to
esync/fsync. Needs a kernel that provides the module.

Type: `boolean`. Default: `true`.
