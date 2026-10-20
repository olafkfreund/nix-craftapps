---
name: craftapps
description: Use the storytold Craft apps (CADCraft, DeckCraft, DesignCraft, EffectCraft, FigCraft, FilmCraft, GridCraft, LightCraft, PdfCraft, PhotoCraft, SoundCraft, VectorCraft, WordCraft) to create or edit DXF drawings, presentations, page layouts, motion graphics, UI designs, video, spreadsheets, photos, PDFs, audio, vector art and documents. Use when asked to drive the open app, work on a live document in a Craft app, or connect to a running Craft app, and when any craftapps MCP server or `<app>-cli` is available.
---

# Craft apps

Thirteen desktop apps, each with a GUI (`<app>`) and a CLI (`<app>-cli`).
Every app does its work through engine commands, so an agent never needs
the GUI to get a result.

| App | Makes |
| --- | --- |
| cadcraft | 2D/3D CAD drawings (DXF, DWG, SVG, PDF) |
| deckcraft | presentations (.deckcraft, .pptx) |
| designcraft | page layouts |
| effectcraft | motion graphics compositions |
| figcraft | interface designs |
| filmcraft | video edits |
| gridcraft | spreadsheets |
| lightcraft | photo library and raw development |
| pdfcraft | PDF inspection and editing |
| photocraft | raster images (.pcraft) |
| soundcraft | audio sessions |
| vectorcraft | vector illustration |
| wordcraft | word processor documents (.docx) |

## Headless first

Use the MCP server for the app (`<app>-cli mcp`, stdio) or the CLI. Both run
an in-process engine with no window, so they work over SSH and in CI.

- Discover before you act: list the commands (`list_commands`,
  `command_list`, or `<app>-cli commands`) and read the parameter docs.
- Verify after you act: use the inspect tool and the render or screenshot
  tool and look at the result.
- Edits live in memory until you save or export. Save explicitly.
- Never run the GUI binary (`<app>`) with `--help` or any flag you have not
  confirmed. An unknown flag opens a window instead of printing help. Use
  `<app>-cli` for anything headless.

## Bridge mode: drive the open app

When the user has an app open and wants you to work on that live document,
start the GUI with `--control PORT` (the user does this) and point the MCP
server at it. The flag for the server differs by app:

| App | Server flag |
| --- | --- |
| cadcraft | `--connect HOST:PORT` (also `--lazy`, `--launch`) |
| deckcraft | `--connect PORT` |
| designcraft | `--connect PORT` |
| effectcraft | `--bridge PORT` |
| figcraft | `--attach PORT` |
| filmcraft | `--bridge 127.0.0.1:PORT` |
| gridcraft | `--connect PORT` |
| lightcraft | `--connect [ADDR]` (default 127.0.0.1:7980) |
| photocraft | `--bridge 127.0.0.1:PORT` (and `--control-token`) |
| soundcraft | `--connect PORT` |
| vectorcraft | `--connect ADDR`, default 127.0.0.1:7979 |
| wordcraft | `--connect HOST:PORT` |
| pdfcraft | no bridge in `mcp`; see below |

If a flag is rejected, run `<app>-cli help` and use what it prints.

- **pdfcraft** has no bridge for `mcp`. Its `ui` subcommand drives a
  running app started with `--control FILE`, and the argument is a file,
  not a port.
- **soundcraft** has tools marked `APP_ONLY`. They exist only in bridge
  mode (`soundcraft --control 0`, then `soundcraft-cli mcp --connect PORT`).
  Headless, they fail.
- **vectorcraft** tries the running app first and falls back to a headless
  session. Pass `--headless` to force the standalone engine.
- **effectcraft**, **filmcraft** and **photocraft** add
  `ui_*` tools (click, key, screenshot) in bridge mode.

## File access roots

Most servers (check `<app>-cli help`) can confine file access with `--automation-read-root DIR` and
`--automation-write-root DIR` (repeatable on some apps). A root you leave
out grants no access of that kind. The roots apply to the in-process
engine only; a bridged app enforces its own, set when it was started.
pdfcraft also takes `--root DIR`. Paths you pass to tools are then relative
to, or must sit inside, these roots. If a read or save is refused, check
the roots before anything else.

## pdfcraft tool list

pdfcraft has a very large tool list. The packaged MCP setup starts it with
`--compact`, which lists a core set plus `tool_search` and `tool_call`.
Find the rest with `tool_search`, then run it with `tool_call`. If the full
list is wanted, run `pdfcraft-cli mcp` without `--compact`.

## Troubleshooting

- A GUI that exits at once on a fresh machine is usually a missing graphics
  driver. The apps render through wgpu, which finds drivers only in
  `/run/opengl-driver`. `WGPU_BACKEND=gl` forces the GLES path.
- Text tools find fonts only in `/usr/share/fonts`.
- `<app>-cli --version` exits 0 and is the cheapest liveness check.
  `--help` is not consistent across the CLIs; use `<app>-cli help`.
