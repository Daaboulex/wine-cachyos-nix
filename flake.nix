{
  description = "Wine-CachyOS packaged for NixOS - Wine with the CachyOS and Proton patch set, overlay and NixOS module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    std = {
      url = "github:Daaboulex/nix-packaging-standard?ref=v2.16.1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.git-hooks.follows = "git-hooks";
    };
  };

  outputs =
    inputs@{ flake-parts, self, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      imports = [ inputs.std.flakeModules.base ];

      flake.overlays.default = import ./overlay.nix;
      flake.nixosModules.default = import ./module.nix;

      perSystem =
        {
          pkgs,
          lib,
          system,
          ...
        }:
        let
          assembled = pkgs.callPackage ./default.nix { };
        in
        {
          packages = {
            wine-cachyos = assembled.wine-cachyos;
            default = assembled.wine-cachyos;
          };

          checks.module-eval-nixos = inputs.std.lib.nixosModuleCheck {
            inherit (inputs) nixpkgs;
            inherit system;
            overlays = [ self.overlays.default ];
            module = ./module.nix;
            config.programs.wine-cachyos = {
              enable = true;
              binfmt.enable = true;
            };
          };

          checks.wine-shape =
            let
              named = lib.mapAttrsToList (n: wine: { inherit n wine; }) assembled.channels;
            in
            pkgs.runCommand "wine-cachyos-shape" { } ''
              export HOME="$TMPDIR"
              export WINEPREFIX="$TMPDIR/prefix"
              export WINEDLLOVERRIDES="mscoree,mshtml="
              ${lib.concatMapStringsSep "\n" (c: ''
                echo "checking channel ${c.n} (${c.wine.version})"
                test -x "${c.wine}/bin/wine"
                test -d "${c.wine}/lib/wine/x86_64-windows"
                test -d "${c.wine}/lib/wine/i386-windows"
                test -f "${c.wine}/share/wine/gecko/wine-gecko-${c.wine.geckoVersion}-x86.msi"
                test -f "${c.wine}/share/wine/gecko/wine-gecko-${c.wine.geckoVersion}-x86_64.msi"
                test -f "${c.wine}/share/wine/mono/wine-mono-${c.wine.monoVersion}-x86.msi"
                test -f "${c.wine}/share/xalia/xalia.exe"
                reported=$("${c.wine}/bin/wine" --version)
                echo "  reports: $reported"
                case "$reported" in
                wine-${c.wine.major}.*) ;;
                *)
                  echo "channel ${c.n} should be a wine-${c.wine.major} lineage, got '$reported'" >&2
                  exit 1
                  ;;
                esac
              '') named}
              touch "$out"
            '';
        };
    };
}
