---
status: approved
issue: 15
spec: spec/2026-10-20-15-intent-routing.md
---

# Plan: route create/edit requests to the right Craft app

Approved decisions, carried over from the spec:

- One skill, `craftapps`. The routing lives in its `description` (agents
  choose skills from descriptions only) and in a new first body section,
  "Choose the app".
- **Description:** the exact text is in step 1. It is 918 characters,
  limited to 1,024, with no `<` or `>` (the Agent Skills spec forbids XML
  tags). No `when_to_use`, because only Claude Code reads it.
- **Rule:** if you ask to create, convert or edit a file type in the
  table, use that Craft app's MCP server or CLI rather than a generic
  file-format skill or a library script. If you name a tool or library,
  do what you asked. Check `command -v <app>-cli` first; if the app is
  missing, say so and fall back.
- **Formats:** only those verified on 2026-10-20 from each app's
  `-cli help`, command catalog or MCP schemas. Left out because
  unverified: the `.mp4` container for FilmCraft, MP3 export for
  SoundCraft, raw formats beyond ARW, NEF, RAF, CR3 and DNG.
- **New `skill` flake check:** it fails on a wrong `name`, a description
  over 1,024 characters, or `<`/`>` in the description.
- No module changes. Docs: README, llms.txt, AGENTS.md step 6.

## Steps

1. `skills/craftapps/SKILL.md:3`: replace the `description:` line with
   this text, on one line:

   ```text
   description: Create or edit files with the installed Craft apps instead of writing them by hand: slides, PowerPoint or .pptx → DeckCraft; Word document, letter, report, .docx/.odt/.rtf → WordCraft; spreadsheet, Excel, .xlsx/.xls/.ods/.csv → GridCraft; fill, sign, merge, OCR or redact a PDF, PDF to Word → PdfCraft; retouch an image, remove a background, Photoshop or .psd → PhotoCraft; raw photos, batch photo edits, Lightroom → LightCraft; logo, icon, illustration, SVG, Illustrator, .ai/.eps → VectorCraft; app or web UI, wireframe, prototype, Figma or .fig → FigCraft; brochure, magazine, InDesign, .idml, EPUB → DesignCraft; CAD, floor plan, AutoCAD, .dwg/.dxf → CADCraft; cut or edit a video, captions, Premiere → FilmCraft; motion graphics, animated titles, After Effects, Lottie → EffectCraft; record, mix or master audio, Pro Tools → SoundCraft. Also for driving an open Craft app or any Craft CLI or MCP server.
   ```

   → verify by
   `sed -n 3p skills/craftapps/SKILL.md | sed 's/^description: //' | wc -m`
   (≤ 1024) and `sed -n 3p skills/craftapps/SKILL.md | grep -c '[<>]'`
   printing 0.
   Traps: YAML. The value contains `: ` ("by hand: slides"), and plain
   YAML scalars may not contain `: `. Write it as a double-quoted string
   (`description: "…"`) and escape nothing else; it has no `"`. Then
   check that the frontmatter parses:
   `python3 -c 'import sys;print(open("skills/craftapps/SKILL.md").read().split("---")[1])'`
   shows it, and the step 3 check reads it.

2. `skills/craftapps/SKILL.md:6-26`: replace the intro and the
   "| App | Makes |" table with:
   - `# Craft apps`, then the existing two-sentence intro (lines 8-10).
   - `## Choose the app`, containing:
     - the rule and the explicit-tool exception, as in the decisions
       above;
     - the check: "Before routing, run `command -v <app>-cli`. If it is
       missing, say the app isn't installed and fall back";
     - this table:

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

     - `### When two apps fit`, with these tie-breakers:
       - **New PDF:** made by the app that makes the content (prose →
         wordcraft, slides → deckcraft, sheets → gridcraft, print layout
         or PDF/X → designcraft). pdfcraft is for an existing PDF:
         forms, signing, OCR, merge, split, redact, PDF/A, and PDF →
         .docx/.pptx.
       - **.pptx:** deckcraft. designcraft's PPTX export only turns an
         existing layout into slides.
       - **Photos:** raw files, many photos, grading or library work →
         lightcraft. Pixel edits to one image (layers, background
         removal, PSD) → photocraft.
       - **Graphics:** logos, icons, SVG/AI/EPS → vectorcraft. UI screens
         and prototypes → figcraft. Multi-page print or ebooks →
         designcraft.
       - **DXF:** engineering drawings and anything DWG → cadcraft. DXF
         as artwork → vectorcraft, which cannot do DWG.
       - **Video and audio:** timeline editing → filmcraft. Motion
         graphics or Lottie → effectcraft. Multitrack or MIDI audio →
         soundcraft. Audio inside a video edit → filmcraft.
       - **A format fails:** run `<app>-cli help` and use what it lists.
   - The remaining sections ("Headless first" onwards) stay unchanged.

   → verify by `wc -l skills/craftapps/SKILL.md` (≤ 170) and
   `grep -n '^## ' skills/craftapps/SKILL.md`, which must show "Choose the
   app" first.
   Traps: no version numbers. Keep the formats exactly as listed here;
   don't add any that aren't in this table.

3. `flake.nix`, next to the `cli` check (around line 236): add

   ```nix
   skill = pkgs.runCommand "craftapps-skill-check" { } ''
     f=${./skills/craftapps/SKILL.md}
     fm=$(sed -n '2,/^---$/p' "$f")
     grep -qx 'name: craftapps' <<<"$fm" || { echo "skill name must be craftapps"; exit 1; }
     desc=$(sed -n 's/^description: "\{0,1\}\(.*\)"\{0,1\}$/\1/p' <<<"$fm")
     [[ -n $desc ]] || { echo "skill description missing"; exit 1; }
     (( ''${#desc} <= 1024 )) || { echo "skill description is ''${#desc} chars, max 1024"; exit 1; }
     [[ $desc != *[\<\>]* ]] || { echo "skill description must not contain < or >"; exit 1; }
     touch $out
   '';
   ```

   Adjust the quoting until it works, and keep the four rules. `''${`
   escapes `${` inside a Nix indented string. Bash's `${#desc}` counts
   characters only under a UTF-8 locale. In the sandbox the locale is C,
   so `→` counts as 3 bytes: either set `LC_ALL=C.UTF-8` (with
   `LOCALE_ARCHIVE` from `pkgs.glibcLocales`), or count with
   `wc -m` under such a locale. Check the measured number against step
   1's (918).
   → verify by `nix build .#checks.x86_64-linux.skill -L`. Mutation tests,
   from a scratchpad backup, restoring after each: (a) append 200 x's to
   the description, so the check must fail on length; (b) add `<x>`, so it
   must fail on brackets.
   Traps: `grep -q` in a pipe can SIGPIPE under pipefail, so use
   here-strings as above. Don't name a variable `out`.

4. Docs:
   - `README.md` "Agent skill" (line 372 onwards): add one sentence. The
     skill tells agents which app to use for each request (for example
     .pptx → DeckCraft, .docx → WordCraft, .xlsx → GridCraft), so they
     use the installed apps instead of writing files by hand.
   - `llms.txt:17`: append "It routes requests by file type and task to
     the right app."
   - `AGENTS.md:88` (step 6): "Add the app to `skills/craftapps/SKILL.md`:
     its bridge flag, its row in the routing table, and its intents in the
     `description`. The `skill` check keeps that under 1,024 characters."
   - `AGENTS.md` Commands block: the `nix flake check` comment line gains
     `skill`.
   → verify by `grep -n -i 'rout' README.md llms.txt AGENTS.md`.
   Traps: plain, short README style.

4a. New `skills/craftapps/routing.md` (spec 3b), without frontmatter.
    Base it on the text proven in the experiment
    (`/tmp/claude-1000/-mnt-code-Source-home-GitHub-nix-craftapps/4e6fbfc5-b1ed-40c6-add3-f8054ec93388/scratchpad/smoke/cm.md`):

    ```markdown
    # Craft apps

    When asked to create, convert or edit a file, use the installed Craft app's MCP server (load its tools with ToolSearch) instead of python libraries, pandoc, LibreOffice or ImageMagick, unless the user names a tool:

    - slides/.pptx → deckcraft; Word/.docx/.odt/.rtf → wordcraft; spreadsheet/.xlsx/.csv → gridcraft
    - edit/fill/sign/merge an existing PDF → pdfcraft; image edits, background removal, .psd → photocraft
    - raw photos/photo library → lightcraft; logo/icon/SVG/.ai/.eps → vectorcraft; UI/prototype/.fig → figcraft
    - print layout/brochure/.idml/EPUB → designcraft; CAD/.dwg/.dxf → cadcraft
    - video edit → filmcraft; motion graphics/Lottie → effectcraft; audio mix → soundcraft

    For formats, tie-breakers and driving an open app, load the craftapps skill.
    ```

    → verify by `wc -c skills/craftapps/routing.md` (≤ 1000).
    Traps: keep it this short. It is loaded into every session.

4b. Install the rule and test it:
    - `modules/skill.nix`: inside the existing `config = lib.mkIf …`, also
      set `programs.claude-code.rules.craftapps = ../skills/craftapps/routing.md;`,
      but only when `options.programs ? claude-code &&
      options.programs.claude-code ? rules`. Merge it with the existing
      `programs = genAttrs …` through `lib.mkMerge` or `//` on the
      `claude-code` entry. Don't overwrite its `skills`.
    - `flake.nix` `hm-module` check: give `skillStub` a
      `programs.claude-code.rules` option (`attrsOf (either lines path)`,
      default `{ }`). Assert
      `withSkill.config.programs.claude-code.rules ? craftapps`,
      `shared.config.programs.claude-code.rules ? craftapps` and
      `skillOff.config.programs.claude-code.rules == { }`.
    - Docs:
      - README "Agent skill": one sentence saying that for Claude Code it
        also installs `~/.claude/rules/craftapps.md`, a short routing
        rule loaded in every session, about 200 tokens;
      - AGENTS.md layout: add a row for `skills/craftapps/routing.md`;
      - AGENTS.md step 6: also add the app to `routing.md`;
      - llms.txt: append that line too.
    → verify by
    `nix build .#checks.x86_64-linux.hm-module .#checks.x86_64-linux.skill -L`.
    Mutation test: drop the rules line, and `hm-module` must fail;
    restore it. Real Home Manager eval as in #10's step 7 (pinned HM
    `/nix/store/zlzw0yfldi2ggxsnwhc74mbm25s19is8-source`): `home.file`
    has a key containing `.claude/rules/craftapps.md`, and
    `.claude/skills/craftapps` is still present.
    Traps: no `options` access outside `config`. Codex, opencode, crush,
    copilot-cli and antigravity-cli get no rule, because their options
    own whole files.

5. Routing smoke test with real Claude Code (revised for spec 3b; the
   original run failed, as recorded under Deviations). No repo edits;
   record the results for the PR.
   - Revised setup: in each fresh scratch dir, install the repo's
     `routing.md` as `.claude/rules/craftapps.md`, and the new
     SKILL.md as `.claude/skills/craftapps-next/SKILL.md`.
   - Run all four prompts sequentially, each in its own dir. Allow
     `Bash(magick:*)` and `Bash(convert:*)` as well, so the generic
     tools are real competitors.
   - Pass: the first non-ToolSearch tool call is the matching app's
     `mcp__<app>__` tool, with no python, pandoc or ImageMagick probing.
     Files are created for 1–3. For prompt 4, reaching
     `mcp__photocraft__` passes, because opening files needs #16.
   - Original setup, kept for the record:
   - In a fresh scratch dir `S`, create
     `S/.claude/skills/craftapps-next/SKILL.md` as a copy of the new file
     with `name: craftapps-next`.
   - For each prompt run, from `S`:
     ```bash
     claude -p --output-format stream-json --verbose --max-turns 12 \
       --allowedTools 'Skill,Bash(command -v:*),mcp__deckcraft__*,mcp__wordcraft__*,mcp__gridcraft__*,mcp__photocraft__*' \
       < prompt.txt > run-N.jsonl
     ```
     Pass the prompt on stdin: the prompt argument is swallowed after
     `--allowedTools`.
   - The prompts:
     1. "Make a 3-slide presentation about otters and save it as otters.pptx in this directory."
     2. "Write a one-page thank-you letter and save it as letter.docx here."
     3. "Make a monthly budget spreadsheet with a total row and save it as budget.xlsx here."
     4. "Remove the background from photo.png and save it as photo-cut.png." (Create `photo.png` first with a one-colour background; `photocraft-cli` or any small PNG will do.)
   - **Pass:** each run shows a `Skill` tool_use for `craftapps-next` or
     `craftapps`, then tool_use calls of the matching
     `mcp__<app>__` server (deckcraft, wordcraft, gridcraft, photocraft),
     and the file exists.
   - **Baseline for comparison:** run prompt 1 once more in a second
     scratch dir without `craftapps-next`. The installed old `craftapps`
     still exists, so this shows what the old description did.
   - Record per run: skill loaded (yes/which), app tools used, and file
     created. Use `jq` over the jsonl.
   → verify by the four pass results. If a run doesn't route, sharpen the
   description or the rule and re-run. Note each change as a deviation in
   this plan.
   Traps: don't edit `~/.claude` or the installed skill. Never launch a
   GUI binary.

6. Final checks and commit as
   `feat: route create/edit requests to the right Craft app (#15)`.
   → verify with the commands under Tests.

## Tests

```sh
python3 scripts/update.py --self-test        # self-test ok
nix fmt && git diff --stat                   # no unexpected .nix changes
nix flake check -L                           # includes the new skill check
```

Plus the step 3 mutation tests and the step 5 smoke-test results. CI must
pass on both architectures before merge. After merge, bump the lock in
nixos-config and deploy p620 and razer from a clean worktree, announced
on the agent bus. Then check that `~/.claude/skills/craftapps/SKILL.md`
has the new description.

## Rollback

Revert the commit. The skill returns to its earlier description and body
on the next rebuild.

## Deviations

- Step 1: the description measures 908 characters, not the 918 stated above.
- Step 3: the check sets `LOCALE_ARCHIVE` (from `pkgs.glibcLocales`) and
  `LC_ALL=C.UTF-8`, so `→` counts as one character.
- Step 3: the `sed` matches only the double-quoted form. An unquoted
  description fails on purpose, because a plain scalar breaks on `: `.
- Step 3: the check echoes the measured length.
- Step 5, first run (skill only): no `claude -p` run loaded the skill,
  with the planned description or a sharpened one. The agent probed
  python-pptx, python-docx, openpyxl or pandoc first, and used
  ImageMagick for the background removal. A project `CLAUDE.md` with the
  routing rule fixed both. The spec gained section 3b (approved
  2026-10-20), and steps 4a and 4b were added here. Evidence is in
  `…/4e6fbfc5-…/scratchpad/smoke/` (`run-*.jsonl`, `retry-*.jsonl`,
  `cmd-*.jsonl`).
- Step 5: PhotoCraft's server cannot open files without file-access
  roots. That is tracked separately as #16.
- Review fixes:
  - The rule is skipped when the user sets
    `programs.claude-code.rulesDir`, because Home Manager forbids
    `rules` together with `rulesDir`. A `withRulesDir` hm-module case
    asserts it, and a mutation test showed the case fails without the
    guard.
  - The `skill` check also rejects a `"` in the description.
  - The `skill` check uses the built-in C.UTF-8, with no
    `glibcLocales`; it still measures 908.
