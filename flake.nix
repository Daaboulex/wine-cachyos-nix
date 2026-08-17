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
      url = "github:Daaboulex/nix-packaging-standard?ref=v2.27.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.git-hooks.follows = "git-hooks";
    };
    # Upstream's own recipe, so the weekly lock bump re-reads it and the
    # upstream-recipe check fails the moment CachyOS changes something we mirror.
    cachyos-pkgbuilds = {
      url = "github:CachyOS/CachyOS-PKGBUILDS";
      flake = false;
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
            inherit (assembled) wine-cachyos;
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

          checks.upstream-recipe =
            let
              wine = assembled.channels.latest;
            in
            pkgs.runCommand "wine-cachyos-upstream-recipe" { } ''
              pkgbuild="${inputs.cachyos-pkgbuilds}/wine-cachyos/PKGBUILD"
              [ -f "$pkgbuild" ] || { echo "upstream PKGBUILD not found at $pkgbuild" >&2; exit 1; }

              field() { sed -n "s/^$1=\(.*\)$/\1/p" "$pkgbuild" | head -1; }
              up_srctag=$(field _srctag)
              [ -n "$up_srctag" ] || { echo "cannot read _srctag from the upstream PKGBUILD" >&2; exit 1; }

              if [ "cachyos-$up_srctag-wine" != "${wine.tag}" ]; then
                echo "upstream now packages cachyos-$up_srctag-wine; this flake packages ${wine.tag}."
                echo "The recipe comparison only applies at the same tag, so it is skipped."
                echo "The daily updater advances the tag; the pins are re-checked once it does."
                touch "$out"
                exit 0
              fi

              fail=0
              for pair in "_geckover ${wine.geckoVersion} Gecko geckoVersion/geckoHash32/geckoHash64" \
                          "_monover ${wine.monoVersion} Mono monoVersion/monoHash" \
                          "_xaliaver ${wine.xaliaVersion} Xalia xaliaVersion/xaliaHash"; do
                set -- $pair
                up=$(field "$1")
                if [ -n "$up" ] && [ "$up" != "$2" ]; then
                  echo "upstream builds $3 $up, this flake pins $2 -- update $4 in sources.nix" >&2
                  fail=1
                fi
              done

              want=$(sed -n '/configure \\/,/^$/p' "$pkgbuild" |
                grep -oE '^[[:space:]]*--[a-z0-9-]+(=[^ \\]*)?' | tr -d ' ' | sort -u)
              have="${lib.concatStringsSep " " wine.configureFlags}"
              for f in $want; do
                case "$f" in
                --prefix* | --libdir*) continue ;;
                esac
                case " $have " in
                *" $f "*) ;;
                *)
                  echo "upstream passes $f to configure, this flake does not -- add it in package.nix" >&2
                  fail=1
                  ;;
                esac
              done

              [ "$fail" -eq 0 ] || exit 1
              echo "recipe matches upstream at cachyos-$up_srctag-wine" > "$out"
            '';

          checks.runtime-pins =
            let
              named = lib.mapAttrsToList (n: wine: { inherit n wine; }) assembled.channels;
            in
            pkgs.runCommand "wine-cachyos-runtime-pins" { } ''
              fail=0
              ${lib.concatMapStringsSep "\n" (c: ''
                addons="${c.wine.src}/dlls/appwiz.cpl/addons.c"
                want_gecko=$(sed -n 's/^#define GECKO_VERSION "\(.*\)"$/\1/p' "$addons")
                want_mono=$(sed -n 's/^#define MONO_VERSION "\(.*\)"$/\1/p' "$addons")
                echo "channel ${c.n}: source requires Gecko $want_gecko, Mono $want_mono"
                if [ -z "$want_gecko" ] || [ -z "$want_mono" ]; then
                  echo "  cannot read GECKO_VERSION/MONO_VERSION from $addons" >&2
                  fail=1
                fi
                if [ -n "$want_gecko" ] && [ "$want_gecko" != "${c.wine.geckoVersion}" ]; then
                  echo "  channel ${c.n} ships Gecko ${c.wine.geckoVersion}, source requires $want_gecko" >&2
                  echo "  fix: set geckoVersion/geckoHash32/geckoHash64 for this channel in sources.nix" >&2
                  fail=1
                fi
                if [ -n "$want_mono" ] && [ "$want_mono" != "${c.wine.monoVersion}" ]; then
                  echo "  channel ${c.n} ships Mono ${c.wine.monoVersion}, source requires $want_mono" >&2
                  echo "  fix: set monoVersion/monoHash for this channel in sources.nix" >&2
                  fail=1
                fi
              '') named}
              [ "$fail" -eq 0 ] || exit 1
              touch "$out"
            '';

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
