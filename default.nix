{ pkgs }:

let
  inherit (pkgs) lib;
  registry = lib.importJSON ./apps.json;
  system = pkgs.stdenv.hostPlatform.system;
  apps = lib.mapAttrs (name: info: pkgs.callPackage ./package.nix { inherit name info; }) (
    lib.filterAttrs (_: info: info.sources ? ${system}) registry
  );
in
apps
// {
  craftapps-all = pkgs.symlinkJoin {
    name = "craftapps-all";
    paths = builtins.attrValues apps;
  };
}
