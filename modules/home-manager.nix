# Home Manager cannot write /usr/share/fonts, so the apps' text tools find no
# fonts unless the NixOS module (linkFonts) or the distro provides that path.
craftapps:
{ config, lib, ... }:

let
  cfg = config.programs.craftapps;
in
{
  imports = [ (import ./common.nix craftapps) ];

  config = lib.mkIf cfg.enable { home.packages = cfg.packages; };
}
