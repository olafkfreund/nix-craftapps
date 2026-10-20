---
status: approved
issue: 15
intent: intent/2026-10-20-15-intent-routing.md
---

# Spec: route create/edit requests to the right Craft app

The intent was approved with its open question answered as proposed: an
explicit request for a tool or library ("use python-pptx") wins, and the
Craft preference applies only when you name a file type or a task.

## Design

All changes are in `skills/craftapps/SKILL.md`, plus one check and the
docs. No module changes.

### 1. Description (frontmatter line 3)

Replace the current description with an intent-first one. Every arrow is
a request → app pair, and it leads with file types and familiar app
names, because Claude picks a skill only by matching the request against
descriptions (code.claude.com/docs/en/skills: "Put the key use case
first"). The draft is 918 characters:

> Create or edit files with the installed Craft apps instead of writing
> them by hand: slides, PowerPoint or .pptx → DeckCraft; Word document,
> letter, report, .docx/.odt/.rtf → WordCraft; spreadsheet, Excel,
> .xlsx/.xls/.ods/.csv → GridCraft; fill, sign, merge, OCR or redact a
> PDF, PDF to Word → PdfCraft; retouch an image, remove a background,
> Photoshop or .psd → PhotoCraft; raw photos, batch photo edits,
> Lightroom → LightCraft; logo, icon, illustration, SVG, Illustrator,
> .ai/.eps → VectorCraft; app or web UI, wireframe, prototype, Figma or
> .fig → FigCraft; brochure, magazine, InDesign, .idml, EPUB →
> DesignCraft; CAD, floor plan, AutoCAD, .dwg/.dxf → CADCraft; cut or
> edit a video, captions, Premiere → FilmCraft; motion graphics,
> animated titles, After Effects, Lottie → EffectCraft; record, mix or
> master audio, Pro Tools → SoundCraft. Also for driving an open Craft
> app or any Craft CLI or MCP server.

It has no angle brackets: the Agent Skills spec forbids XML tags in
`description`, and the current text's `<app>-cli` breaks that. Only the
description is used, not Claude Code's `when_to_use`, because the other
five agents read just `name` and `description`.

### 2. New first section in the body: "Choose the app"

It goes before "Headless first", so an agent reads it first:

- **Rule:** when you ask to create, convert or edit a file of a type in
  the table, use that Craft app through its MCP server (or its CLI)
  rather than a generic file-format skill or a library script. If you
  name a tool or library yourself, do what you asked.
- **Check first:** `command -v <app>-cli`. If the app isn't installed,
  say so and fall back.
- **Routing table:** request/intent | app | opens | saves/exports. These
  are the verified formats from the 2026-10-20 research, condensed to the
  formats people actually ask for. Unverified items are left out: an
  `.mp4` container for FilmCraft, MP3 export for SoundCraft, raw formats
  beyond ARW, NEF, RAF, CR3 and DNG.
- **Tie-breakers** (verified overlaps):
  - New PDF: made by the app that makes the content (prose → WordCraft,
    slides → DeckCraft, sheets → GridCraft, print layout or PDF/X →
    DesignCraft). PdfCraft is for an existing PDF: forms, sign, OCR,
    merge, split, redact, PDF/A, and PDF → .docx/.pptx.
  - `.pptx`: DeckCraft. DesignCraft's PPTX export is only for turning an
    existing layout into slides.
  - Photos: raw files, many photos, grading or library work → LightCraft;
    pixel edits to one image (layers, background removal, PSD) →
    PhotoCraft.
  - Graphics: logos, icons, SVG/AI/EPS → VectorCraft; UI screens and
    prototypes → FigCraft; multi-page print or ebook → DesignCraft.
  - DXF: engineering drawings and anything DWG → CADCraft; DXF as artwork
    → VectorCraft (no DWG).
  - Video: timeline editing → FilmCraft; motion graphics or Lottie →
    EffectCraft. Audio: multitrack or MIDI → SoundCraft; audio inside a
    video edit → FilmCraft.

The old "Makes" table is replaced by the routing table. The other sections
stay as they are. Line budget: up to about 170 lines, well under the
500-line guidance for SKILL.md.

### 3. A check that guards the frontmatter

A new `skill` check in `flake.nix` (`pkgs.runCommand`) reads the
frontmatter of `skills/craftapps/SKILL.md` and fails if:
- `name` isn't `craftapps`;
- `description` is longer than 1,024 characters;
- `description` contains `<` or `>`.

That stops a later edit from making the skill unloadable for some
agents.

### 4. Docs

- README "Agent skill": one sentence saying the skill routes requests by
  file type to the right app.
- llms.txt: the same in one line.
- AGENTS.md step 6 ("Adding a new Craft app"): it also adds the app's
  intents to the description and the routing table, and keeps the
  description under 1,024 characters (the `skill` check enforces it).

## Alternatives rejected

- **Thirteen per-app skills:** thirteen descriptions in every session's
  context, and no single place for the tie-breakers.
- **`when_to_use`:** Claude Code-only. The other agents would miss the
  routing.
- **Generating the routing from `apps.json`:** formats and tie-breakers
  are judgement and research, not registry data.
- **Disabling or overriding the generic pptx/docx/xlsx skills:** this
  flake doesn't own them. A sharper description plus the explicit rule
  is enough, and those skills already defer to a dedicated skill.

## Risks

- **Over-triggering:** a broad description may load the skill for "write
  a CSV parser". The rule's "create or edit a file … use the app" wording
  and the explicit-tool exception limit the harm. A wrong load costs one
  skill read.
- **Format drift upstream:** apps may add or drop formats. The table
  lists common formats only, and tells the agent to check
  `<app>-cli help` when a format fails.
- **Listing truncation:** Claude Code drops descriptions of rarely used
  skills when the listing overflows (1% of context). A 918-character
  description is within the per-skill cap; nothing more can be done from
  here.

## Verification

- The `skill` check passes. A mutation test (a description over 1,024
  characters, or one containing `<`) fails it.
- `nix flake check`, the updater's `--self-test` and `nix fmt` are clean.
  CI passes on both architectures.
- **Routing smoke test with real Claude Code.** Before merge, from a
  scratch directory, install the new file as a project skill named
  `craftapps-next` (so it doesn't clash with the installed `craftapps`),
  then run `claude -p --output-format stream-json` with four prompts:
  - "make a 3-slide pptx about otters";
  - "write a one-page letter as .docx";
  - "make an xlsx with a monthly budget";
  - "remove the background from photo.png".

  Each must show the skill being loaded and the matching app's MCP tool or
  `-cli` being used (DeckCraft, WordCraft, GridCraft, PhotoCraft).
  Results are recorded in the PR.
- After merge and deploy: `~/.claude/skills/craftapps/SKILL.md` on p620
  has the new description.
