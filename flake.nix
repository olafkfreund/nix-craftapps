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
          node = lib.nixosSystem {
            inherit system;
            modules = [
              self.nixosModules.default
              {
                programs.craftapps = {
                  enable = true;
                  enableAll = true;
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
              ok =
                builtins.length cfg.programs.craftapps.packages == builtins.length names
                && builtins.any (lib.hasInfix "/usr/share/fonts") cfg.systemd.tmpfiles.rules
                && cfg.fonts.fontDir.enable;
            in
            assert lib.assertMsg ok "craftapps NixOS module did not install every app and link the fonts";
            pkgs.runCommand "craftapps-module-check" { } "touch $out";
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
