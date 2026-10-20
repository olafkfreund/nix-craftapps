{
  description = "The ArtCraft Crafting Apps (storytold) for Nix: 13 pure-Rust creative apps";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
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
      darwinModules.default = import ./modules/darwin.nix craftapps;
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
              type = lib.types.attrsOf (
                lib.types.submodule {
                  freeformType = lib.types.attrsOf lib.types.anything;
                  options.command = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                  };
                  options.args = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                  };
                }
              );
              default = { };
            };
          };
          skillStub.options.programs.claude-code = {
            skills = lib.mkOption {
              type = with lib.types; either (attrsOf (either lines path)) path;
              default = { };
            };
            rules = lib.mkOption {
              type = with lib.types; attrsOf (either lines path);
              default = { };
            };
          };
          hmStub.options.home-manager.sharedModules = lib.mkOption {
            type = lib.types.listOf lib.types.raw;
            default = [ ];
          };
          settings.programs.craftapps = {
            enable = true;
            enableAll = true;
            mcp.enable = true;
            skill.enable = true;
            apps.soundcraft.enable = false;
          };
          nixos = lib.nixosSystem {
            inherit system;
            modules = [
              self.nixosModules.default
              hmStub
              settings
              {
                boot.loader.grub.enable = false;
                fileSystems."/" = {
                  device = "none";
                  fsType = "tmpfs";
                };
                system.stateVersion = "26.05";
              }
            ];
          };
          # nix-darwin's own options, stubbed as the Home Manager ones are below.
          darwin = lib.evalModules {
            modules = [
              self.darwinModules.default
              hmStub
              settings
              {
                options.environment.systemPackages = lib.mkOption {
                  type = lib.types.listOf lib.types.package;
                  default = [ ];
                };
                options.environment.etc = lib.mkOption {
                  type = lib.types.attrsOf (
                    lib.types.submodule { options.text = lib.mkOption { type = lib.types.lines; }; }
                  );
                  default = { };
                };
                config._module.args.pkgs = pkgs;
              }
            ];
          };
          node = if pkgs.stdenv.hostPlatform.isDarwin then darwin else nixos;
          systemOk =
            cfg:
            let
              s =
                (builtins.fromJSON (
                  builtins.unsafeDiscardStringContext cfg.environment.etc."craftapps/mcp.json".text
                )).mcpServers;
            in
            builtins.length cfg.programs.craftapps.packages == builtins.length names - 1
            && !builtins.elem "soundcraft" (map (p: p.pname) cfg.programs.craftapps.packages)
            && builtins.all (p: builtins.elem p cfg.environment.systemPackages) cfg.programs.craftapps.packages
            && builtins.length (builtins.attrNames s) == builtins.length names - 1
            && !(s ? soundcraft)
            &&
              s.vectorcraft.args == [
                "mcp"
                "--headless"
              ]
            &&
              s.pdfcraft.args == [
                "mcp"
                "--compact"
              ]
            &&
              s.lightcraft.args == [
                "mcp"
                "--compact"
              ]
            && builtins.all (v: lib.hasSuffix "-cli" v.command) (builtins.attrValues s);
        in
        lib.removeAttrs self.packages.${system} [ "default" ]
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          module =
            let
              cfg = nixos.config;
              ok =
                systemOk cfg
                && builtins.any (lib.hasInfix "/usr/share/fonts") cfg.systemd.tmpfiles.rules
                && cfg.fonts.fontDir.enable;
            in
            assert lib.assertMsg ok
              "craftapps NixOS module: enableAll with one exclusion, the font link, or the MCP servers are wrong";
            pkgs.runCommand "craftapps-module-check" { } "touch $out";
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
          darwin-module =
            assert lib.assertMsg (systemOk darwin.config)
              "craftapps nix-darwin module: enableAll with one exclusion, or the MCP servers are wrong";
            pkgs.runCommand "craftapps-darwin-module-check" { } "touch $out";
        }
        // {
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
                        skill.enable = true;
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
              withSkill = eval {
                imports = [
                  packagesOpt
                  mcpStub
                  skillStub
                ];
              };
              skillOff = eval {
                imports = [
                  packagesOpt
                  skillStub
                  { programs.craftapps.skill.enable = lib.mkForce false; }
                ];
              };
              withRulesDir = eval {
                imports = [
                  packagesOpt
                  skillStub
                  {
                    options.programs.claude-code.rulesDir = lib.mkOption { type = lib.types.nullOr lib.types.path; };
                    config.programs.claude-code.rulesDir = ./skills;
                  }
                ];
              };
              # The NixOS module's per-user module; a user's own entry must replace the shared one.
              shared = lib.evalModules {
                modules = node.config.home-manager.sharedModules ++ [
                  mcpStub
                  skillStub
                  {
                    programs.mcp.servers.gridcraft.args = [ "x" ];
                    programs.mcp.servers.photocraft.enabled = false;
                  }
                ];
              };
              without = eval packagesOpt;
              sharedWithout = lib.evalModules { modules = node.config.home-manager.sharedModules; };
              off = node.extendModules {
                modules = [
                  {
                    programs.craftapps.mcp.enable = lib.mkForce false;
                    programs.craftapps.skill.enable = lib.mkForce false;
                  }
                ];
              };
              mcp = withMcp.config.programs.mcp;
              ok =
                mcp.enable
                && builtins.length (builtins.attrNames mcp.servers) == builtins.length names - 1
                && !(mcp.servers ? soundcraft)
                && shared.config.programs.mcp.enable
                &&
                  builtins.length (builtins.attrNames shared.config.programs.mcp.servers) == builtins.length names - 1
                && shared.config.programs.mcp.servers.gridcraft.args == [ "x" ]
                && shared.config.programs.mcp.servers.photocraft.command != null
                && withSkill.config.programs.claude-code.skills ? craftapps
                && shared.config.programs.claude-code.skills ? craftapps
                && skillOff.config.programs.claude-code.skills == { }
                && withSkill.config.programs.claude-code.rules ? craftapps
                && shared.config.programs.claude-code.rules ? craftapps
                && skillOff.config.programs.claude-code.rules == { }
                && withRulesDir.config.programs.claude-code.rules == { }
                && withRulesDir.config.programs.claude-code.skills ? craftapps
                && off.config.home-manager.sharedModules == [ ]
                && !(off.config.environment.etc ? "craftapps/mcp.json");
            in
            assert lib.assertMsg ok "craftapps Home Manager module, or the NixOS per-user MCP module, is wrong";
            builtins.seq (without.config.home.packages ++ [ sharedWithout.config ]) (
              pkgs.runCommand "craftapps-hm-module-check" { } "touch $out"
            );
          mcp = pkgs.runCommand "craftapps-mcp-check" { } ''
            ${lib.concatMapStringsSep "\n" (
              name:
              let
                app = self.packages.${system}.${name};
                args = lib.escapeShellArgs node.config.programs.craftapps.apps.${name}.mcp.args;
              in
              ''
                resp=$(echo '${initialize}' | HOME=$TMPDIR timeout 30 ${app}/bin/${name}-cli ${args} || true)
                [[ $resp == *'"result"'* && $resp == *'"id":1'* ]] || { echo "${name}: no initialize result: $resp"; exit 1; }
              ''

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
          skill = pkgs.runCommand "craftapps-skill-check" { } ''
            export LC_ALL=C.UTF-8
            f=${./skills/craftapps/SKILL.md}
            fm=$(sed -n '2,/^---$/p' "$f")
            grep -qx 'name: craftapps' <<<"$fm" || { echo "skill name must be craftapps"; exit 1; }
            desc=$(sed -n 's/^description: "\(.*\)"$/\1/p' <<<"$fm")
            [[ -n $desc ]] || { echo "skill description missing or not double-quoted"; exit 1; }
            echo "skill description: ''${#desc} chars"
            (( ''${#desc} <= 1024 )) || { echo "skill description is ''${#desc} chars, max 1024"; exit 1; }
            [[ $desc != *[\<\>]* ]] || { echo "skill description must not contain < or >"; exit 1; }
            [[ $desc != *\"* ]] || { echo "skill description must not contain a double quote"; exit 1; }
            touch $out
          '';
        }
      );

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
