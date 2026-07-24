{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.wine-cachyos;
in
{
  options.programs.wine-cachyos = {
    enable = lib.mkEnableOption "wine-cachyos, Wine with the CachyOS and Proton patch set";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.wine-cachyos;
      defaultText = lib.literalExpression "pkgs.wine-cachyos";
      description = "The wine-cachyos package to install. Requires this flake's overlay.";
    };

    ntsync.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Load the `ntsync` kernel module at boot, mirroring upstream's
        `modules-load.d` drop-in. ntsync is the in-kernel NT synchronization
        primitive this Wine build prefers; without it Wine falls back to
        esync/fsync. Needs a kernel that provides the module.
      '';
    };

    binfmt.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Register Windows executables with `binfmt_misc` so they can be run
        directly, mirroring upstream's `wine-binfmt.conf`. Off by default: the
        registration is system-wide and routes every `MZ` binary through this
        Wine, not only the ones you intended.
      '';
    };

    fontAliases.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install upstream's fontconfig aliases for the Win32 logical font names
        (`MS Shell Dlg`, `MS Shell Dlg 2`, `MS Sans Serif`), which fontconfig's
        own metric aliases do not cover.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    boot.kernelModules = lib.optional cfg.ntsync.enable "ntsync";

    boot.binfmt.registrations = lib.mkIf cfg.binfmt.enable {
      DOSWin = {
        recognitionType = "magic";
        magicOrExtension = "MZ";
        interpreter = lib.getExe cfg.package;
      };
    };

    fonts.fontconfig.localConf = lib.mkIf cfg.fontAliases.enable ''
      <alias binding="same">
        <family>MS Shell Dlg</family>
        <accept><family>Microsoft Sans Serif</family></accept>
        <default><family>sans-serif</family></default>
      </alias>
      <alias binding="same">
        <family>MS Shell Dlg 2</family>
        <accept><family>Tahoma</family></accept>
        <default><family>sans-serif</family></default>
      </alias>
      <alias binding="same">
        <family>MS Sans Serif</family>
        <prefer><family>Microsoft Sans Serif</family></prefer>
        <default><family>sans-serif</family></default>
      </alias>
    '';
  };
}
