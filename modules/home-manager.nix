# Home Manager cannot write /usr/share/fonts, so the apps' text tools find no
# fonts unless the NixOS module (linkFonts) or the distro provides that path.
craftapps:
{
  config,
  options,
  lib,
  ...
}:

let
  cfg = config.programs.craftapps;
in
{
  imports = [
    (import ./common.nix craftapps)
    (import ./skill.nix (c: c.programs.craftapps.enable && c.programs.craftapps.skill.enable))
  ];

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      { home.packages = cfg.packages; }
      # Older Home Manager has no programs.mcp.
      (lib.optionalAttrs (options.programs ? mcp) {
        programs.mcp = lib.mkIf cfg.mcp.enable {
          enable = lib.mkDefault true;
          servers = cfg.mcp.servers;
        };
      })
    ]
  );
}
