---
status: draft
issue: 3
author: olafkfreund
---

# Intent: configure the apps' built-in MCP servers from the modules

## Problem

Every Craft app has an MCP server built in: `<app>-cli mcp`, which speaks
JSON-RPC over stdio. The CLI is already installed, but no MCP client knows
it is there. A user who wants an assistant to drive PhotoCraft or
WordCraft has to find the subcommand and write a client entry for every
app by hand, with the Nix store path or the right binary name. Each
client stores that entry in a different file and format.

`programs.craftapps` installs the apps but says nothing about MCP. The
servers are not a known, documented option, and an admin cannot set them
up for every user on a machine.

## Proposed outcome

- Turning MCP on for `programs.craftapps` registers one MCP server for
  every enabled app, and only for those. Excluding an app with
  `apps.<name>.enable = false` removes its server too.
- On Home Manager, the servers show up in any client that reads the
  standard Home Manager MCP option (`programs.mcp.servers`): Claude Code,
  Codex, Cursor, Copilot CLI, crush, Antigravity and others. The user only
  turns on that client's `enableMcpIntegration`.
- On NixOS, an admin can make the servers available to every user from
  first login, without each user writing any client config.
- The option and its limits are documented in README.md, llms.txt and
  the option descriptions.
- A flake check proves the generated server entries for an enabled and an
  excluded app.

## Affected users and systems

- `modules/common.nix`, `modules/nixos.nix`, `modules/home-manager.nix`
  and the `module` check in `flake.nix`.
- Users of both modules. Nothing changes for anyone who leaves the new
  option off.
- MCP clients on the user's machine: Claude Code, Codex, Cursor and
  others.

## Constraints

Research done for this intent (2026-10-17) found these limits:

- **The servers are stdio only.** A client must start the process, so there
  is no daemon or systemd service to run. A server is a command plus
  arguments.
- **Default modes differ between apps.** Most run headless by default.
  `vectorcraft-cli mcp` connects to a running app on 127.0.0.1:7979 by
  default and needs `--headless` to work without one. Several have a
  bridge mode to a running GUI (`--connect` / `--bridge`).
- **Some apps can confine file access.** soundcraft, vectorcraft and
  wordcraft take `--automation-read-root` / `--automation-write-root`;
  pdfcraft takes `--root`. Any default the module picks decides what an
  assistant can read and write.
- **Claude Code has no non-exclusive system-wide hook for stdio servers.**
  - `/etc/claude-code/managed-mcp.json` takes exclusive control: users
    lose every other MCP server, plugin servers, claude.ai connectors and
    Claude in Chrome, and `claude mcp add` fails.
  - `managedMcpServers` in managed settings keeps users' own servers, but
    it accepts only `https` remote servers, never a `command`.
  - This machine already has `/etc/claude-code/managed-settings.json`
    and relies on many user MCP servers, so the module must never write
    `managed-mcp.json` by default.
- **Home Manager already has the standard hub.** `programs.mcp.servers`
  is written to `$XDG_CONFIG_HOME/mcp/mcp.json`, and client modules merge
  it in through `enableMcpIntegration`. The module should use that rather
  than writing client config files itself.
- **No server takes secrets**, so world-readable store files are fine.
- **Repository rules (AGENTS.md):**
  - Server entries come from data, never from `if name == …` branches.
  - The modules take packages from this flake, not from `pkgs.craftapps`.
  - `apps.<name>.enable` keeps defaulting to `enableAll`.
  - Python stays stdlib only.

## Open questions

1. **Default.** Should MCP be off until enabled (`mcp.enable = false`), or
   on whenever an app is installed? Recommendation: off. It gives an
   assistant control of the apps.
2. **NixOS, all users.** Which route should NixOS use?
   - (a) Publish the server set as a read-only option, plus a file such as
     `/etc/craftapps/mcp.json`, that users and admins plug into clients.
   - (b) Inject `programs.mcp.servers` into every user through
     `home-manager.sharedModules` when Home Manager runs as a NixOS
     module.
   - (c) An opt-in that writes `/etc/claude-code/managed-mcp.json`, with a
     warning that it takes over all MCP for Claude Code.

   Recommendation: (a) and (b). Leave out (c).
3. **Mode.** Should servers run headless (they work with no GUI open) or
   bridge to a running app? Recommendation: headless by default, with
   per-app `extraArgs` to override.
4. **File confinement.** Should the module set read and write roots by
   default, for example the user's home, or leave each app's own default?
   Recommendation: leave the app defaults and expose `extraArgs`.
