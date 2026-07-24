{
  pkgs,
  lib ? pkgs.lib,
}:
let
  sources = import ./sources.nix;

  majorOf = tag: lib.head (builtins.match "cachyos-([0-9]+)\\..*" tag);

  mk = tag: hash: pkgs.callPackage ./package.nix { inherit tag hash; };

  entry = tag: hash: {
    name = "v${majorOf tag}";
    value = mk tag hash;
  };

  # Appended last so the rolling version always owns its own major.
  channels =
    lib.listToAttrs (lib.mapAttrsToList entry sources.pins ++ [ (entry sources.version sources.hash) ])
    // {
      latest = mk sources.version sources.hash;
    };
in
{
  inherit channels;

  wine-cachyos = channels.latest.overrideAttrs (old: {
    passthru = (old.passthru or { }) // channels;
  });
}
