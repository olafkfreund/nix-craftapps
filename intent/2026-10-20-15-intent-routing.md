---
status: approved
issue: 15
author: olafkfreund
---

# Intent: route create/edit requests to the right Craft app

## Problem

When you ask an agent to "make a PowerPoint", "write a Word document" or
"clean up this spreadsheet", it should pick DeckCraft, WordCraft or
GridCraft and use that app's MCP server. Today it usually doesn't (#15):

- An agent chooses a skill from its `description` alone, and the
  `craftapps` description mostly lists app names. Requests phrased by file
  type (".pptx", ".docx", ".xlsx") or by familiar app name ("PowerPoint",
  "Excel", "Photoshop") hardly match it.
- Generic skills such as the bundled `pptx`, `docx` and `xlsx` match
  those words directly, so they win, or the agent writes the file by hand
  with a library.
- The skill body says what each app "makes", but not which formats it
  opens and saves, nor which app to pick when two could do the job (PDF
  output, photos, DXF, graphics, video and audio overlap).

## Proposed outcome

- A request to create or edit a file of a type a Craft app handles makes
  the agent load the `craftapps` skill, choose the app by intent, and do
  the work through that app's MCP server or `<app>-cli`.
- The skill's description leads with the intents and file types, for
  example slides/PowerPoint/.pptx → DeckCraft, Word/.docx → WordCraft,
  Excel/.xlsx/CSV → GridCraft, Photoshop/.psd → PhotoCraft. It fits Claude
  Code's limits: 1,024 characters per the Agent Skills spec, truncated at
  1,536 in Claude Code's skill listing.
- The skill body has an intent → app table with the formats each app opens
  and saves, every format verified against that app's own CLI or MCP
  schema, and tie-breakers for the overlaps.
- Where a Craft app fits, the skill tells the agent to prefer it over a
  generic file-format skill or a hand-written library script.

## Affected users and systems

- This flake: `skills/craftapps/SKILL.md`, and the README "Agent skill"
  section. No Nix code changes are expected.
- p620 and razer after a lock bump: the installed skill text changes.
  `features.craftapps.skill` is already on.
- Every agent the skill is installed for: Claude Code, Codex, opencode,
  Crush, Copilot CLI and Antigravity CLI.

## Constraints

- One skill, not thirteen. Every skill's description sits in the agent's
  context in every session, so one routing description costs far less
  than thirteen.
- Only formats verified on 2026-10-20 go in. Unverified ones (FilmCraft
  `.mp4` container, SoundCraft MP3 export, LightCraft raw formats beyond
  ARW, NEF, RAF, CR3 and DNG) are marked or left out.
- No version numbers, so the daily updates don't make it stale.
- The skill must also work when some apps are disabled: it tells the agent
  to check that `<app>-cli` exists before routing to it.
- It cannot change or disable other skills. It can only describe itself
  well and state the preference.

## Open questions

- Should the skill tell agents to prefer a Craft app even when you name a
  generic library or tool, for example "use python-pptx"? Proposed: no,
  an explicit request wins. The preference applies only when you name a
  file type or a task.
