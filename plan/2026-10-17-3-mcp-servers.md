---
status: draft
issue: 3
spec: spec/2026-10-17-3-mcp-servers.md
---

# Plan: configure the apps' built-in MCP servers from the modules

## Approved decisions (self-contained)

- **What a server is.** Every app has a stdio MCP server, `<app>-cli mcp`.
  The client starts it, so there is no daemon or systemd unit.
- **Off by default.** `programs.craftapps.mcp.enable` defaults to `false`.
  With it off, nothing changes.
- **One server per enabled app.** The server set is one entry for each app
  whose `apps.<name>.enable` is true:
  `{ command = "${apps.<name>.package}/bin/<name>-cli"; args = apps.<name>.mcp.args; }`.
  There are no other keys.
- **Default args.** `apps.<name>.mcp.args` defaults to
  `[ "mcp" ] ++ (mcpArgs.${name} or [ ])`, where
  `mcpArgs = { vectorcraft = [ "--headless" ]; }`. VectorCraft's default
  mode sends tool calls to a running app on 127.0.0.1:7979. The other 11
  are headless by default. This was verified on 2026-10-17: all 12 answer
  `initialize` with `HOME=<tmp>` and these args.
- **No file-confinement roots.** Users who want them add them through
  `apps.<name>.mcp.args`.
- **Home Manager.** The module sets `programs.mcp.servers` and
  `programs.mcp.enable = lib.mkDefault true`. Home Manager's Claude Code,
  Codex and other clients read the shared servers only when
  `programs.mcp.enable` is on. Both definitions sit behind
  `lib.optionalAttrs (options.programs ? mcp)`, because older Home Manager
  has no `programs.mcp`. The module does not set any client's
  `enableMcpIntegration`.
- **NixOS.**
  - It writes `environment.etc."craftapps/mcp.json"` containing
    `{ mcpServers = <servers>; }`.
  - When `options ? home-manager`, it adds one
    `home-manager.sharedModules` entry. That entry sets the same two
    `programs.mcp` values, with the same guard, for every Home Manager
    user.
- **Never touch `/etc/claude-code/`.** `managed-mcp.json` takes
  exclusive control of MCP. `managedMcpServers` accepts only `https`
  servers.
- **Store paths are kept,** not `/run/current-system/sw/bin`. The README
  says that a hand-copied `/etc/craftapps/mcp.json` goes stale after a
  rebuild.

## Steps

1. **`modules/common.nix`: options.**
   1. In the `let` block (lines 11-14), add
      `mcpArgs = { vectorcraft = [ "--headless" ]; };` with a one-line why
      comment. The comment says that vectorcraft's default mode drives a
      running app on :7979.
   2. In `options.programs.craftapps` (after line 23), add
      `mcp.enable = lib.mkEnableOption "an MCP server for every enabled app (`<app>-cli mcp`, stdio)"`.
   3. Inside the `apps = lib.genAttrs …` submodule (lines 25-38), add
      `mcp.args`: type `listOf str`, default
      `[ "mcp" ] ++ (mcpArgs.${name} or [ ])`, a `defaultText`, and a
      description that names bridge mode and the file-root flags as
      examples.
   4. After `packages` (line 47), add `mcp.servers`. Make it
      `readOnly = true`, of type `attrsOf (attrsOf anything)`, with
      `default = lib.optionalAttrs cfg.mcp.enable (lib.genAttrs (filter enabled names) (name: { command = "${cfg.apps.${name}.package}/bin/${name}-cli"; inherit (cfg.apps.${name}.mcp) args; }))`.
      Give it a description that names `programs.mcp.servers` and
      `/etc/craftapps/mcp.json`.
   5. Factor `builtins.filter (name: cfg.apps.${name}.enable) names` into
      one `let` binding, `enabled`. Use it for both `packages` and
      `mcp.servers`.

   Verify:

   ```sh
   nix eval --impure --expr '(builtins.getFlake (toString ./.)).nixosModules.default' >/dev/null
   nix flake check
   ```

   Traps:
   - `apps.<name>.enable` must still default to `enableAll`; don't OR
     them.
   - Packages come from `cfg.apps.<n>.package`, never `pkgs.craftapps`.
   - No narrating comments.

2. **`modules/home-manager.nix`: Home Manager wiring.**
   1. Add `options` to the function arguments.
   2. Change `config` to
      `lib.mkIf cfg.enable (lib.mkMerge [ { home.packages = cfg.packages; } (lib.optionalAttrs (options.programs ? mcp) { programs.mcp = lib.mkIf cfg.mcp.enable { enable = lib.mkDefault true; servers = cfg.mcp.servers; }; }) ])`.

   Verify: step 4's `hm-module` check.

   Traps:
   - `lib.optionalAttrs` must test `options`, never `config`, or
     evaluation recurses infinitely.

3. **`modules/nixos.nix`: NixOS wiring.**
   1. Add `options` to the arguments.
   2. Add to the `mkMerge` list (lines 20-29):
      - `(lib.mkIf cfg.mcp.enable { environment.etc."craftapps/mcp.json".text = builtins.toJSON { mcpServers = cfg.mcp.servers; }; })`
      - `(lib.optionalAttrs (options ? home-manager) { home-manager.sharedModules = lib.mkIf cfg.mcp.enable [ ({ options, lib, ... }: lib.optionalAttrs (options.programs ? mcp) { programs.mcp = { enable = lib.mkDefault true; servers = servers; }; }) ]; })`

      In the second entry, bind `servers = cfg.mcp.servers;` in the
      outer `let`, so the inner `lib`/`options` names do not shadow
      `cfg`.

   Verify: step 4's `module` check.

   Traps:
   - Write nothing under `/etc/claude-code/`.
   - Never set `hardware.*` (docs/GPU.md promises this).

4. **`flake.nix`: checks.** The current checks are at lines 32-81.
   1. In the NixOS test node (lines 41-45), add `mcp.enable = true;`.
   2. Extend `module`'s `ok` (lines 61-65). Let
      `s = builtins.fromJSON node.config.environment.etc."craftapps/mcp.json".text`.
      Then assert:
      - `builtins.length (builtins.attrNames s.mcpServers) == builtins.length names - 1`;
      - `!(s.mcpServers ? soundcraft)`;
      - `s.mcpServers.vectorcraft.args == [ "mcp" "--headless" ]`;
      - every `command` satisfies `lib.hasSuffix "-cli"`.

      Update the assert message to match.
   3. Add an `hm-module` check. Use
      `lib.evalModules { modules = [ self.homeManagerModules.default stub { _module.args.pkgs = pkgs; programs.craftapps = { enable = true; enableAll = true; mcp.enable = true; apps.soundcraft.enable = false; }; } ]; }`.
      The stub declares `options.home.packages` (`listOf package`),
      `options.programs.mcp.enable` (bool, default false) and
      `options.programs.mcp.servers` (`attrsOf anything`, default
      `{ }`). Assert all of these:
      - `programs.mcp.enable`;
      - 11 servers;
      - no `soundcraft`.

      Then run a second `evalModules` whose stub declares only
      `home.packages`. Force `config.home.packages` with
      `builtins.seq`, which tests the guard. Finish with
      `pkgs.runCommand "craftapps-hm-module-check" { } "touch $out"`.
   4. Add an `mcp` check, a `runCommand` like `cli`. For each name:

      ```sh
      echo '<initialize json>' | HOME=$TMPDIR ${app}/bin/${name}-cli ${escapeShellArgs node.config.programs.craftapps.apps.${name}.mcp.args} | grep -qF '"result"'
      ```

      The initialize JSON is
      `{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"check","version":"0"}}}`.
      Read args from the node config, not a second copy of `mcpArgs`.

   Verify:

   ```sh
   nix flake check -L     # all checks pass, including the new hm-module and mcp
   ```

   Traps:
   - `--help` is inconsistent; don't use it.
   - The `node` has soundcraft disabled. For the `mcp` check, read args
     through `node.config.programs.craftapps.apps.${name}.mcp.args`. The
     options exist for disabled apps too.

5. **Docs.**
   1. **README.md:**
      - Add four rows to the option table (lines 286-292): `mcp.enable`,
        `apps.<name>.mcp.args`, `mcp.servers` (read-only), and a note
        that `/etc/craftapps/mcp.json` is NixOS only.
      - Add a `## MCP servers` section after the option reference, and
        add it to the table of contents near line 41. It covers:
        - the Home Manager snippet: `programs.craftapps.mcp.enable = true;`
          plus `programs.claude-code.enableMcpIntegration = true;` (same
          idea for codex, cursor and others);
        - NixOS without Home Manager: loop over `/etc/craftapps/mcp.json`
          with `jq` into `claude mcp add-json --scope user`;
        - why `managed-mcp.json` is not used, in one paragraph;
        - a bridge-mode example,
          `apps.photocraft.mcp.args = [ "mcp" "--bridge" "127.0.0.1:<port>" ];`;
        - the stale-store-path caveat for hand-copied entries.
   2. **llms.txt:** add an `mcp` bullet under "Module options" (lines
      10-15). Name the options and `/etc/craftapps/mcp.json`.
   3. **AGENTS.md:**
      - Under "Traps already found" (line 85), add **MCP**: the servers
        are stdio, so there is no service; never write
        `/etc/claude-code/managed-mcp.json`, because it takes exclusive
        control; non-headless defaults go in `mcpArgs` in
        `modules/common.nix`.
      - In "Adding a new Craft app" step 3, add: check that
        `<newapp>-cli mcp` answers `initialize` headless; the `mcp`
        check does this.

   Verify: `nix fmt` leaves the Nix files clean. Read through the docs.

   Traps:
   - Plain language; no narrating.

## Tests

```sh
nix fmt && git diff --exit-code -- '*.nix'   # formatted
nix flake check -L                           # builds 12, cli, module, hm-module, mcp
python3 scripts/update.py --self-test        # "self-test ok"
```

Runtime check on this machine, after the PR is merged, through
nixos-config:

1. Set `programs.craftapps.mcp.enable = true`.
2. Check that `/etc/craftapps/mcp.json` lists the enabled apps.
3. With Home Manager's `programs.claude-code.enableMcpIntegration`,
   `claude mcp list` shows them connected.

## Rollback

Revert the PR's squash commit. The option defaults to off, so no
configuration that leaves it unset is affected. Users who set
`programs.craftapps.mcp.enable` must remove that line after a revert,
or evaluation fails on an unknown option.
