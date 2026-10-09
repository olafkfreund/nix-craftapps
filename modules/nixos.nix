craftapps:
{ config, lib, ... }:

let
  cfg = config.programs.craftapps;
in
{
  imports = [ (import ./common.nix craftapps) ];

  options.programs.craftapps.linkFonts = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Link /usr/share/fonts to the system fonts. The apps' text tools look
      for fonts only there and do not use fontconfig.
    '';
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      { environment.systemPackages = cfg.packages; }
      (lib.mkIf cfg.linkFonts {
        fonts.fontDir.enable = true;
        systemd.tmpfiles.rules = [
          "d /usr/share 0755 root root -"
          "L+ /usr/share/fonts - - - - /run/current-system/sw/share/X11/fonts"
        ];
      })
    ]
  );
}
