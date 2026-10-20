# Installs the craftapps skill for each agent whose Home Manager module has `skills`.
isEnabled:
{
  config,
  options,
  lib,
  ...
}:

let
  agents = [
    "claude-code"
    "codex"
    "opencode"
    "crush"
    "github-copilot-cli"
    "antigravity-cli"
  ];
  present = builtins.filter (a: options.programs ? ${a} && options.programs.${a} ? skills) agents;
in
{
  config = lib.mkIf (isEnabled config) {
    programs = lib.genAttrs present (_: {
      skills.craftapps = ../skills/craftapps/SKILL.md;
    });
  };
}
