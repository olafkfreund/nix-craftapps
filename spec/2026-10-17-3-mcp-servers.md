---
status: approved
issue: 3
intent: intent/2026-10-17-3-mcp-servers.md
---

# Spec: configure the apps' built-in MCP servers from the modules

These intent decisions were approved and are carried over:

- MCP is off by default.
- NixOS uses routes (a) and (b), a published server set plus the Home
  Manager shared module. It never writes `managed-mcp.json` (route c).
- Servers run headless by default, and each app gets `args` to override
  that.
- The module sets no file-confinement roots. Each app keeps its own
  default.

## Design

### Facts checked for this spec (2026-10-17, current releases)

- **All 12 servers start without a GUI.** `HOME=<tmp> <app>-cli mcp` answers
  an MCP `initialize` request with a JSON-RPC `result`.
- **VectorCraft is the one exception to headless-by-default.** Its default
  mode also answers `initialize`. But its help says the default mode sends
  tool calls to a running app on 127.0.0.1:7979, so it needs `--headless`.
  The other 11 are headless by default.
- **Home Manager's Claude Code integration needs two switches.** In
  `programs/claude-code/default.nix` it reads `programs.mcp.servers` only
  when both `programs.claude-code.enableMcpIntegration` and
  `programs.mcp.enable` are true. `programs.mcp` writes
  `~/.config/mcp/mcp.json` only when `enable` is on. Codex, Cursor,
  Copilot CLI, crush and Antigravity integrate the same way.

### `modules/common.nix` (both modules)

New options:

| Option | Type | Default | Notes |
| --- | --- | --- | --- |
| `mcp.enable` | bool | `false` | Register an MCP server for every enabled app. |
| `apps.<name>.mcp.args` | list of str | `[ "mcp" ] ++ (mcpArgs.${name} or [ ])` | Arguments to `<name>-cli`. Override for bridge mode or file roots. |
| `mcp.servers` | attrs, read-only | computed | `{ <name> = { command = "<pkg>/bin/<name>-cli"; args = …; }; }`, one entry for each app with `apps.<name>.enable`, and `{ }` while `mcp.enable` is off. |

`mcpArgs` is a small data attrset in `common.nix`:
`{ vectorcraft = [ "--headless" ]; }`, with a one-line comment on why.
`command` is the absolute store path from `apps.<name>.package`, so a
client needs no `PATH` and a custom package override is respected.

Each entry has only `command` and `args`. That is valid for Home
Manager's `programs.mcp.servers` submodule, and for the `mcpServers` map
in `.mcp.json`, `managed-mcp.json`, Cursor and Codex.

### `modules/home-manager.nix`

When `enable && mcp.enable`, the module sets:

- `programs.mcp.servers = cfg.mcp.servers`;
- `programs.mcp.enable = lib.mkDefault true`. Without it, no client
  integration and no `mcp.json` would see the servers.

Older Home Manager releases have no `programs.mcp`. The definition is
therefore wrapped in `lib.optionalAttrs (options.programs ? mcp)`, so
evaluation does not fail there. `mcp.enable` is then just a no-op,
which the option description says.

The user still turns on each client, for example
`programs.claude-code.enableMcpIntegration = true`. The module does not set
that switch, because it belongs to that client's own configuration.

### `modules/nixos.nix`

When `enable && mcp.enable`, the module does two things:

1. **(a)** It writes `environment.etc."craftapps/mcp.json"` as
   `{ "mcpServers": cfg.mcp.servers }`. Any user or admin can merge this
   into a client: Claude Code with `claude mcp add-json`, a project
   `.mcp.json`, or Cursor's `mcp.json`. The README shows the commands.
2. **(b)** When Home Manager runs as a NixOS module
   (`options ? home-manager`), it adds one entry to
   `home-manager.sharedModules`. That entry sets
   `programs.mcp.servers = <servers>` and
   `programs.mcp.enable = lib.mkDefault true` for every Home Manager user,
   using the same `options.programs ? mcp` guard. So every Home Manager
   user gets the servers from their first login without installing the
   apps through their own Home Manager configuration.

The servers come from the system's `cfg.mcp.servers`. The shared module
does not need the user's own `programs.craftapps`.

The module writes nothing under `/etc/claude-code/`.

### `flake.nix` checks

- **`module`** (extended): the NixOS test node gets `mcp.enable = true`.
  The check asserts all of these:
  - `/etc/craftapps/mcp.json` lists 11 servers and no `soundcraft`;
  - `vectorcraft.args == [ "mcp" "--headless" ]`;
  - every `command` ends in `-cli`.
- **`hm-module`** (new): evaluates `homeManagerModules.default` with
  `lib.evalModules`, using a stub module that declares `home.packages`
  and `programs.mcp.{enable,servers}`. It asserts all of these:
  - the servers reach `programs.mcp.servers`;
  - `programs.mcp.enable` is true;
  - excluding an app removes its server.

  A second evaluation without the stub `programs.mcp` must still succeed;
  that run tests the guard. This adds no flake input.
- **`mcp`** (new): for every app, it pipes an `initialize` request into
  `HOME=$TMPDIR <app>-cli <default args>` and greps the output for
  `"result"`. This runs in the build sandbox like the existing `cli`
  check, and proves each server starts headless.

### Docs

- **README.md:**
  - four rows in the option reference;
  - a short "MCP servers" section covering the Home Manager integration
    switches, `/etc/craftapps/mcp.json` with a
    `claude mcp add-json` loop, why `managed-mcp.json` is not used, and
    how to use bridge mode through `apps.<name>.mcp.args`.
- **llms.txt:** the options and the file path.
- **AGENTS.md:**
  - one trap: "never write `/etc/claude-code/managed-mcp.json`; it takes
    exclusive control";
  - a note that a new app's `mcp` defaults must be checked (step 3 of
    "Adding a new Craft app").

## Alternatives rejected

- **`managed-mcp.json` opt-in (route c).** It is exclusive: it drops every
  user MCP server, plugin servers, connectors and Claude in Chrome. The
  user rejected it at the intent stage.
- **`managedMcpServers` in managed settings.** It accepts only `https`
  remote servers and refuses `command`.
- **Per-app MCP args in `apps.json`.** `update.py` rebuilds each entry from
  scratch and only when the version changes. The key would need updater
  changes and would appear only after the next release. AGENTS.md also
  forbids hand-editing that file. A Nix data attrset next to the options
  is simpler, and it is data, not a branch in `package.nix`.
- **Writing each client's config file directly** (`~/.claude.json`,
  `~/.codex/config.toml`). These files are user-mutable state, and Home
  Manager already owns the integration through `programs.mcp`.
- **A systemd service.** The servers are stdio processes that the client
  starts. There is nothing to run as a daemon.
- **One `craftapps` server that dispatches to all apps.** This would mean
  writing and maintaining our own MCP proxy, for no benefit over 12
  entries.

## Risks

- **Clients start servers lazily, but some list them all at startup.**
  Twelve entries make for a long list in `/mcp`. Users can exclude apps.
- **Store paths change on every update.** Home Manager users get new paths
  on each switch. Users who copied `/etc/craftapps/mcp.json` into a client
  by hand keep stale paths after a rebuild. Pointing `command` at
  `/run/current-system/sw/bin/<name>-cli` would avoid that on NixOS, but
  it only works when the app is in `environment.systemPackages`. The spec
  keeps store paths and documents this.
- **Headless servers write state under `$HOME`,** for example
  `~/.config/<app>/logs` (seen during the check). That is expected app
  behaviour.
- **Upstream may change an app's default mode,** as vectorcraft's did. The
  `mcp` check catches a server that fails to start. It does not catch one
  that starts but waits for a GUI.
- **Hosts:** this only applies where a user sets `mcp.enable`. Nothing
  changes for anyone else.

## Verification

```sh
nix flake check -L                      # module, hm-module, mcp, cli, builds
nix fmt
python3 scripts/update.py --self-test   # unchanged, must still pass
```

Runtime check on this machine:

1. With `mcp.enable = true` through Home Manager and
   `programs.claude-code.enableMcpIntegration = true`, `claude mcp list`
   shows the enabled apps as connected.
2. Asking Claude Code to call one tool, for example a gridcraft
   `tools/list`, works.
