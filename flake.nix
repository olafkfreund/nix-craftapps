{
  description = "The ArtCraft Crafting Apps (storytold) for Nix: 12 pure-Rust creative apps";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      craftapps = pkgs: import ./default.nix { inherit pkgs; };
      names = builtins.attrNames (lib.importJSON ./apps.json);
      initialize = builtins.toJSON {
        jsonrpc = "2.0";
        id = 1;
        method = "initialize";
        params = {
          protocolVersion = "2025-06-18";
          capabilities = { };
          clientInfo = {
            name = "check";
            version = "0";
          };
        };
      };
    in
    {
      packages = forAllSystems (
        pkgs:
        let
          apps = craftapps pkgs;
        in
        apps // { default = apps.craftapps-all; }
      );

      overlays.default = final: _prev: { craftapps = craftapps final; };

      nixosModules.default = import ./modules/nixos.nix craftapps;
      homeManagerModules.default = import ./modules/home-manager.nix craftapps;

      checks = forAllSystems (
        pkgs:
        let
          system = pkgs.stdenv.hostPlatform.system;
          mcpStub.options.programs.mcp = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
            servers = lib.mkOption {
              type = lib.types.attrsOf lib.types.anything;
              default = { };
            };
          };
          node = lib.nixosSystem {
            inherit system;
            modules = [
              self.nixosModules.default
              { options.home-manager.sharedModules = lib.mkOption { type = lib.types.listOf lib.types.raw; }; }
              {
                programs.craftapps = {
                  enable = true;
                  enableAll = true;
                  mcp.enable = true;
                  apps.soundcraft.enable = false;
                };
                boot.loader.grub.enable = false;
                fileSystems."/" = {
                  device = "none";
                  fsType = "tmpfs";
                };
                system.stateVersion = "26.05";
              }
            ];
          };
        in
        lib.removeAttrs self.packages.${system} [ "default" ]
        // {
          module =
            let
              cfg = node.config;
              s =
                (builtins.fromJSON (
                  builtins.unsafeDiscardStringContext cfg.environment.etc."craftapps/mcp.json".text
                )).mcpServers;
              ok =
                builtins.length cfg.programs.craftapps.packages == builtins.length names - 1
                && !builtins.elem "soundcraft" (map (p: p.pname) cfg.programs.craftapps.packages)
                && builtins.any (lib.hasInfix "/usr/share/fonts") cfg.systemd.tmpfiles.rules
                && cfg.fonts.fontDir.enable
                && builtins.length (builtins.attrNames s) == builtins.length names - 1
                && !(s ? soundcraft)
                &&
                  s.vectorcraft.args == [
                    "mcp"
                    "--headless"
                  ]
                && builtins.all (v: lib.hasSuffix "-cli" v.command) (builtins.attrValues s);
            in
            assert lib.assertMsg ok
              "craftapps NixOS module: enableAll with one exclusion, the font link, or the MCP servers are wrong";
            pkgs.runCommand "craftapps-module-check" { } "touch $out";
          hm-module =
            let
              eval =
                stub:
                lib.evalModules {
                  modules = [
                    self.homeManagerModules.default
                    stub
                    {
                      _module.args.pkgs = pkgs;
                      programs.craftapps = {
                        enable = true;
                        enableAll = true;
                        mcp.enable = true;
                        apps.soundcraft.enable = false;
                      };
                    }
                  ];
                };
              packagesOpt.options.home.packages = lib.mkOption { type = lib.types.listOf lib.types.package; };
              withMcp = eval {
                imports = [
                  packagesOpt
                  mcpStub
                ];
              };
              # The NixOS module's per-user module; a user's own entry must replace the shared one.
              shared = lib.evalModules {
                modules = node.config.home-manager.sharedModules ++ [
                  mcpStub
                  { programs.mcp.servers.gridcraft.args = [ "x" ]; }
                ];
              };
              without = eval packagesOpt;
              mcp = withMcp.config.programs.mcp;
              ok =
                mcp.enable
                && builtins.length (builtins.attrNames mcp.servers) == builtins.length names - 1
                && !(mcp.servers ? soundcraft)
                && shared.config.programs.mcp.enable
                &&
                  builtins.length (builtins.attrNames shared.config.programs.mcp.servers) == builtins.length names - 1
                && shared.config.programs.mcp.servers.gridcraft.args == [ "x" ];
            in
            assert lib.assertMsg ok "craftapps Home Manager module, or the NixOS per-user MCP module, is wrong";
            builtins.seq without.config.home.packages (
              pkgs.runCommand "craftapps-hm-module-check" { } "touch $out"
            );
          mcp = pkgs.runCommand "craftapps-mcp-check" { } ''
            ${lib.concatMapStringsSep "\n" (
              name:
              let
                app = self.packages.${system}.${name};
                args = lib.escapeShellArgs node.config.programs.craftapps.apps.${name}.mcp.args;
              in
              "echo '${initialize}' | HOME=$TMPDIR ${app}/bin/${name}-cli ${args} | grep -qF '\"result\"'"
            ) names}
            touch $out
          '';
          cli = pkgs.runCommand "craftapps-cli-check" { } ''
            ${lib.concatMapStringsSep "\n" (
              name:
              let
                app = self.packages.${system}.${name};
              in
              "HOME=$TMPDIR ${app}/bin/${name}-cli --version | grep -qF ${app.version}"
            ) names}
            touch $out
          '';
        }
      );

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}
