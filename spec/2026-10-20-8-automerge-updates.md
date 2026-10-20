---
status: approved
issue: 8
intent: intent/2026-10-20-8-automerge-updates.md
---

# Spec: merge daily update PRs automatically once CI passes

## Design

Add one job, `automerge`, to `.github/workflows/ci.yml`:

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

Why it works:

- `update.yml` already dispatches `ci.yml` on `update/craft-apps` after it
  opens the PR. A `workflow_dispatch` run is exempt from the GITHUB_TOKEN
  no-trigger rule, so it runs with no approval click.
- `needs: check` waits for both matrix legs (x86_64 and aarch64). If either
  fails, `automerge` is skipped and the PR stays open for a person.
- The `if` limits it to the bot's branch on the dispatched run. Feature
  PRs (`pull_request`) and pushes to `main` never match.
- `--match-head-commit "$GITHUB_SHA"` makes GitHub refuse the merge if the
  branch moved after CI started, for example if the next day's update
  force-pushed it. Only the tested commit merges.
- Job-level `permissions` lift only this job above the workflow's
  `contents: read`.

The held `pull_request` run on the bot's PR is left alone. After the
merge it is moot, and nobody needs to approve it. The merge commit is
pushed with GITHUB_TOKEN, so it does not start another `ci` run on `main`;
the PR's CI ran on the same tree, because `update.yml` branches from
`main` the same day.

Docs: one sentence in the README update section and in AGENTS.md "CI on
update PRs", saying that update PRs merge themselves after CI passes on
both architectures.

## Alternatives rejected

- **GitHub native auto-merge (`gh pr merge --auto`)**: needs
  `allow_auto_merge` on the repo and branch protection with required
  checks. Required checks would also gate your own pushes to `main`. That
  is more settings for the same result.
- **A PAT or GitHub App token in `update.yml`**: the `pull_request` run
  would start without approval, but it needs a stored secret, which the
  intent rules out.
- **Merging in `update.yml` right after `nix flake check`**: that check
  runs on x86_64 only, so it skips the aarch64 gate.

## Risks

- **A broken upstream release lands on `main` unreviewed.** It still has
  to build, pass `--version`, answer MCP `initialize`, and pass the module
  checks on both architectures. GUI-only breakage would get through. You
  accepted that trade-off in the intent.
- **No CI run on `main` after the merge.** If `main` moved between the
  branch cut and the merge, the merged tree is untested. Update PRs only
  touch `apps.json` and `flake.lock`, so the risk is low.
- **A merge failure**, such as a conflict or a moved head, fails the job
  visibly and leaves the PR open. Nothing is lost.

## Verification

- `nix run nixpkgs#actionlint -- .github/workflows/*.yml` reports no errors.
- On the next update PR, the dispatched `ci` run shows `automerge`
  succeeding, and the PR is merged by `github-actions[bot]` with its branch
  deleted.
- A `pull_request` run on any feature PR shows `automerge` as skipped.
