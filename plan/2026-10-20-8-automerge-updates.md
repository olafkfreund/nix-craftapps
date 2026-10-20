---
status: approved
issue: 8
spec: spec/2026-10-20-8-automerge-updates.md
---

# Plan: merge daily update PRs automatically once CI passes

Approved decisions, carried over from the spec:

- One new job, `automerge`, in `.github/workflows/ci.yml`. It runs only on
  the `workflow_dispatch` run on `refs/heads/update/craft-apps`, which
  `update.yml` already dispatches. It needs both `check` matrix legs.
- It merges with `gh pr merge update/craft-apps --squash --delete-branch
  --match-head-commit "$GITHUB_SHA"`, so only the tested commit merges.
- Job-level `permissions: contents: write, pull-requests: write`; the
  workflow keeps `contents: read`.
- No PAT, no GitHub App, no branch protection, no repo auto-merge setting.
  The held `pull_request` run on the bot PR is left alone.
- GUIs are not launched before merge. You accepted this in the intent.
- The docs say update PRs merge themselves.

## Steps

1. `.github/workflows/ci.yml`: append after the `check` job (end of file):

   ```yaml
     automerge:
       needs: check
       if: github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/update/craft-apps'
       runs-on: ubuntu-latest
       permissions:
         contents: write
         pull-requests: write
       steps:
         - env:
             GH_TOKEN: ${{ github.token }}
           run: >
             gh pr merge update/craft-apps --repo "$GITHUB_REPOSITORY"
             --squash --delete-branch --match-head-commit "$GITHUB_SHA"
   ```

   → verify by `nix run nixpkgs#actionlint -- .github/workflows/*.yml`
   reporting nothing.
   Traps: no checkout step is needed (`--repo` is given). Keep the
   workflow-level `permissions: contents: read` unchanged.

2. Docs:
   - `AGENTS.md:102-104` ("CI on update PRs"): append "Once both
     architectures pass, the `automerge` job in `ci.yml` squash-merges the
     PR; a failure leaves it open."
   - `README.md:452-453`: after "A daily GitHub Actions job runs it.", add
     "It opens a PR that merges itself once CI passes on x86_64 and
     aarch64."
   → verify by `grep -n automerge AGENTS.md` and
   `grep -n 'merges itself' README.md` each printing one line.
   Traps: no narrating comments; keep the AGENTS.md wording plain.

3. Checks and commit as `ci: merge update PRs once CI passes (#8)`.
   → verify with the commands under Tests.

## Tests

```sh
nix run nixpkgs#actionlint -- .github/workflows/*.yml   # no output
nix flake check -L                                      # unchanged, passes
python3 scripts/update.py --self-test                   # self-test ok
```

On the PR, the `pull_request` CI run shows `automerge` as **skipped**.
After merge, on the next update PR, the dispatched `ci` run shows
`automerge` succeeding, and the PR is merged by `github-actions[bot]`
with its branch deleted. If no upstream release happens soon, this is
checked on the first one; there is no safe synthetic test that doesn't
merge something to `main`.

## Rollback

Revert the commit. Update PRs go back to waiting for a manual merge.
