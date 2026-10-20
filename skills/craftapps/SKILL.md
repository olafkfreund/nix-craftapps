---
name: craftapps
description: "Create or edit files with the installed Craft apps instead of writing them by hand: slides, PowerPoint or .pptx → DeckCraft; Word document, letter, report, .docx/.odt/.rtf → WordCraft; spreadsheet, Excel, .xlsx/.xls/.ods/.csv → GridCraft; fill, sign, merge, OCR or redact a PDF, PDF to Word → PdfCraft; retouch an image, remove a background, Photoshop or .psd → PhotoCraft; raw photos, batch photo edits, Lightroom → LightCraft; logo, icon, illustration, SVG, Illustrator, .ai/.eps → VectorCraft; app or web UI, wireframe, prototype, Figma or .fig → FigCraft; brochure, magazine, InDesign, .idml, EPUB → DesignCraft; CAD, floor plan, AutoCAD, .dwg/.dxf → CADCraft; cut or edit a video, captions, Premiere → FilmCraft; motion graphics, animated titles, After Effects, Lottie → EffectCraft; record, mix or master audio, Pro Tools → SoundCraft. Also for driving an open Craft app or any Craft CLI or MCP server."
---

# Craft apps

Thirteen desktop apps, each with a GUI (`<app>`) and a CLI (`<app>-cli`).
Every app does its work through engine commands, so an agent never needs
the GUI to get a result.

## Choose the app

If you are asked to create, convert or edit a file type in the table below,
use that Craft app's MCP server or CLI rather than a generic file-format
skill or a library script. If the user names a tool or library, use that instead.

Before routing, run `command -v <app>-cli`. If it is missing, say the app
isn't installed and fall back.

| You want | App | Opens | Saves / exports |
| --- | --- | --- | --- |
| slides, a deck, PowerPoint | deckcraft | .pptx, .deckcraft | .pptx, .pdf, .png/.jpg, .gif |
| a Word document, letter, report | wordcraft | .docx, .doc (read only), .odt, .rtf, .md, .html, .txt | .docx, .pdf, .odt, .rtf, .html, .md, .txt |
| a spreadsheet, Excel, CSV | gridcraft | .xlsx, .xlsm, .xls, .ods, .csv, .tsv, .json | .xlsx, .csv/.tsv, .json, .html, .pdf |
| work on an existing PDF | pdfcraft | .pdf | .pdf, PDF/A, .docx, .pptx, .html, .rtf, .txt, page images |
| edit one image, PSD, layers | photocraft | .psd/.psb, .png, .jpg, .tif, .webp, .exr | .psd, .png, .jpg, .tif, .webp, .gif |
| raw photos, many photos, a library | lightcraft | ARW, NEF, RAF, CR3, .dng, .jpg, .tif, Lightroom catalogs | .jpg, .png, .tif, .psd, .webp, .avif, .jxl, .dng |
| a logo, icon, illustration | vectorcraft | .svg, .pdf, .ai, .eps, .dxf, .psd, images | .svg, .pdf, .ai, .eps, .dxf, .png/.jpg |
| app or web UI, a prototype | figcraft | .fig (best effort), .svg, images | .png, .jpg, .svg, .webp, .pdf |
| print layout, a brochure, an ebook | designcraft | .idml, .indd (converted), images, PDF pages | .pdf (PDF/X-4, PDF/A), .epub, .idml, .html, .png/.jpg |
| a CAD drawing, floor plan | cadcraft | .dxf, .dwg | .dxf, .dwg, .svg, .png, .pdf |
| a video edit, captions | filmcraft | .mp4, .mov, audio, images, AAF | H.264/HEVC/ProRes renders, image sequences, EDL, FCPXML, OTIO, AAF |
| motion graphics, Lottie | effectcraft | Lottie, footage | Lottie, H.264/HEVC/ProRes/WebM/GIF renders |
| record, mix, master audio | soundcraft | .wav, .aiff, .flac, .mp3, .ogg, .m4a, MIDI | .wav, .aiff, .flac, stems, MIDI |

### When two apps fit

- **New PDF:** made by the app that makes the content (prose → wordcraft,
  slides → deckcraft, sheets → gridcraft, print layout or PDF/X →
  designcraft). pdfcraft is for an existing PDF: forms, signing, OCR,
  merge, split, redact, PDF/A, and PDF → .docx/.pptx.
- **.pptx:** deckcraft. designcraft's PPTX export only turns an existing
  layout into slides.
- **Photos:** raw files, many photos, grading or library work → lightcraft.
  Pixel edits to one image (layers, background removal, PSD) → photocraft.
- **Graphics:** logos, icons, SVG/AI/EPS → vectorcraft. UI screens and
  prototypes → figcraft. Multi-page print or ebooks → designcraft.
- **DXF:** engineering drawings and anything DWG → cadcraft. DXF as artwork
  → vectorcraft, which cannot do DWG.
- **Video and audio:** timeline editing → filmcraft. Motion graphics or
  Lottie → effectcraft. Multitrack or MIDI audio → soundcraft. Audio inside
  a video edit → filmcraft.
- **A format fails:** run `<app>-cli help` and use what it lists.

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

## Compact tool lists

pdfcraft and lightcraft have very large tool lists. The packaged MCP setup
starts both with `--compact`.

- pdfcraft lists a core set plus `tool_search` and `tool_call`. Find the
  rest with `tool_search`, then run it with `tool_call`.
- lightcraft lists a small set of helper tools. For any other command, find
  its id with `command_list` (or `list_commands`) and run it with
  `run_command` (`command`, `params`). It has no `tool_search`.

For the full list, run the server without `--compact`.

## Troubleshooting

- A GUI that exits at once on a fresh Linux machine is usually a missing
  graphics driver. The apps render through wgpu, which finds drivers only in
  `/run/opengl-driver`. `WGPU_BACKEND=gl` forces the GLES path. On macOS
  they use Metal and need no setup.
- On Linux, text tools find fonts only in `/usr/share/fonts`. On macOS they
  use the system font folders.
- `<app>-cli --version` exits 0 and is the cheapest liveness check.
  `--help` is not consistent across the CLIs; use `<app>-cli help`.
