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
  enabled = builtins.filter (name: cfg.apps.${name}.enable) names;
  # vectorcraft's default mode drives a running app on 127.0.0.1:7979; --headless runs standalone.
  mcpArgs = {
    vectorcraft = [ "--headless" ];
    # pdfcraft lists 163 tools (~154 KB); --compact lists 17 plus tool_search/tool_call.
    pdfcraft = [ "--compact" ];
    # lightcraft lists 388 tools (~205 KB); --compact lists 17 helpers, the rest via run_command.
    lightcraft = [ "--compact" ];
  };
in
{
  options.programs.craftapps = {
    enable = lib.mkEnableOption "the ArtCraft Crafting Apps";

    enableAll = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Default for every `apps.<name>.enable`; exclude single apps by setting theirs to false.";
    };

    mcp.enable = lib.mkEnableOption "an MCP server for every enabled app (`<app>-cli mcp`, stdio)";

    skill.enable = lib.mkEnableOption "the craftapps agent skill for every Home Manager agent with a skills option";

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
      mcp.args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "mcp" ] ++ (mcpArgs.${name} or [ ]);
        description = "Arguments for `${name}-cli` when it runs as an MCP server. Add flags such as `--bridge <addr>` or file-root options here.";
      };
    });

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      readOnly = true;
      internal = true;
      default = map (name: cfg.apps.${name}.package) enabled;
    };

    mcp.servers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      readOnly = true;
      defaultText = lib.literalMD "one `{ command, args }` per enabled app while `mcp.enable` is on, else `{ }`";
      default = lib.optionalAttrs cfg.mcp.enable (
        lib.genAttrs enabled (name: {
          command = "${cfg.apps.${name}.package}/bin/${name}-cli";
          inherit (cfg.apps.${name}.mcp) args;
        })
      );
      description = "MCP servers for the enabled apps. Feeds `programs.mcp.servers` and `/etc/craftapps/mcp.json`.";
    };
  };
}
