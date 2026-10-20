# What the NixOS and nix-darwin modules share.
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

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      { environment.systemPackages = cfg.packages; }
      (lib.mkIf cfg.mcp.enable {
        environment.etc."craftapps/mcp.json".text = builtins.toJSON { mcpServers = servers; };
      })
      (lib.optionalAttrs (options ? home-manager) {
        home-manager.sharedModules = lib.mkMerge [
          (lib.mkIf cfg.mcp.enable [
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
          ])
          (lib.mkIf cfg.skill.enable [ (import ./skill.nix (_: true)) ])
        ];
      })
    ]
  );
}
