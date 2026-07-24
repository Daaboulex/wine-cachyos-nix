{
  pkgs,
  lib ? pkgs.lib,
}:
let
  sources = import ./sources.nix;

  majorOf = tag: lib.head (builtins.match "cachyos-([0-9]+)\\..*" tag);

  runtimeKeys = [
    "geckoVersion"
    "geckoHash32"
    "geckoHash64"
    "monoVersion"
    "monoHash"
    "xaliaVersion"
    "xaliaHash"
  ];

  rolling = {
    inherit (sources) hash;
  }
  // lib.getAttrs runtimeKeys sources;

  pinSpec = pin: { hash = pin.srcHash; } // lib.getAttrs runtimeKeys pin;

  mk = tag: spec: pkgs.callPackage ./package.nix ({ inherit tag; } // spec);

  entry = tag: spec: {
    name = "v${majorOf tag}";
    value = mk tag spec;
  };

  # Appended last so the rolling version always owns its own major.
  channels =
    lib.listToAttrs (
      lib.mapAttrsToList (tag: pin: entry tag (pinSpec pin)) sources.pins
      ++ [ (entry sources.version rolling) ]
    )
    // {
      latest = mk sources.version rolling;
    };
in
{
  inherit channels;

  wine-cachyos = channels.latest.overrideAttrs (old: {
    passthru = (old.passthru or { }) // channels;
  });
}
