craftapps:
{
  config,
  options,
  lib,
  ...
}:

let
  cfg = config.programs.craftapps;
  servers = cfg.mcp.servers;
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
      (lib.mkIf cfg.mcp.enable {
        environment.etc."craftapps/mcp.json".text = builtins.toJSON { mcpServers = servers; };
      })
      (lib.optionalAttrs (options ? home-manager) {
        home-manager.sharedModules = lib.mkIf cfg.mcp.enable [
          (
            { options, lib, ... }:
            {
              # Under `config`: a top-level optionalAttrs on `options` recurses infinitely.
              config = lib.optionalAttrs (options.programs ? mcp) {
                programs.mcp = {
                  enable = lib.mkDefault true;
                  # Per field: a user's own args replace ours instead of concatenating, and
                  # a partial override (`enabled = false`) keeps our command.
                  servers = lib.mapAttrs (_: lib.mapAttrs (_: lib.mkDefault)) servers;
                };
              };
            }
          )
        ];
      })
    ]
  );
}
