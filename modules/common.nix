# Options shared by the NixOS and Home Manager modules.
craftapps:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.craftapps;
  available = craftapps pkgs;
  names = builtins.attrNames (lib.importJSON ../apps.json);
in
{
  options.programs.craftapps = {
    enable = lib.mkEnableOption "the ArtCraft Crafting Apps";

    enableAll = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Default for every `apps.<name>.enable`; exclude single apps by setting theirs to false.";
    };

    apps = lib.genAttrs names (name: {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.enableAll;
        defaultText = lib.literalExpression "config.programs.craftapps.enableAll";
        description = "Whether to install ${name}. Set to false to exclude it when `enableAll` is on.";
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = available.${name};
        defaultText = lib.literalExpression "nix-craftapps.packages.\${system}.${name}";
        description = "The ${name} package to install.";
      };
    });

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      readOnly = true;
      internal = true;
      default = map (name: cfg.apps.${name}.package) (
        builtins.filter (name: cfg.apps.${name}.enable) names
      );
    };
  };
}
