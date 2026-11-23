---
name: branch-cleanup
description: Clean up GMSetzer branches and worktrees after confirmed PR merges, and update README and affected documentation on main at every branch completion.
---

# Clean up after a confirmed merge

The owner transferred Setzkit's standing cleanup authorization to GMSetzer on
19 November 2026: delete local and remote branches proven merged into `main`,
and remove their clean worktrees, without asking again. This authorization
covers cleanup. On 20 November 2026 the owner additionally authorised updating,
committing and pushing README and affected descriptive documentation directly
on `main` at every branch completion, without another approval or docs PR.
This includes descriptive skill/workflow instructions. It does not authorise
merging code PRs, unrelated pushes, tags, releases, executable CI changes or
repository visibility changes.

## Verify before deleting

Fetch with `git fetch --prune` and inspect the PR using
`gh pr view <number> --json state,headRefName,mergeCommit`.

- Require `state == MERGED`; a closed, unmerged PR is insufficient.
- Check both local and remote branch tips. Containment is proven when
  `git rev-list --count origin/main..<branch>` is `0`.
- For rewritten history, `git cherry origin/main <branch>` with no `+` lines
  can establish patch equivalence. If a squash combines several commits and
  that check does not prove equivalence, retain the branch; the PR's merged
  status alone does not prove that its current tip contains no later work.
- Check for open PRs using the branch, including dependent PRs, and inspect
  `git worktree list --porcelain`. Also check earlier merged branches.
- Recheck branch tips immediately before deletion. If a tip changed, verify
  it again rather than using the earlier result.

## Remove only verified branches and clean worktrees

- Preserve `main`, branches used by open PRs, and branches with unmerged or
  unproven commits. Report what was retained and why; ask about unmerged work
  only if deleting it is needed for the requested task.
- Preserve all uncommitted and untracked work. Never stash, reset, discard or
  force-remove it to perform cleanup. Leave dirty worktrees in place and
  continue independent cleanup of verified branches.
- If a merged branch is checked out in the primary worktree, switch to `main`
  only when the working tree is clean, then use `git merge --ff-only origin/main`.
  If fast-forwarding fails, preserve local history and report the limitation.
- Remove clean worktrees with `git worktree remove <path>` before deleting
  their branches; then use `git worktree prune`.
- Delete local branches with `git branch -d <branch>`. Use `-D` only after the
  content checks above prove the commits are already represented in `main`.
- Delete verified remote branches with a lease on the verified remote tip:
  `git push --force-with-lease=refs/heads/<branch>:<verified-sha> origin :refs/heads/<branch>`.
  If the lease fails, refresh and recheck; never retry with an unrestricted force.

## Update documentation on main at every branch completion

Documentation reconciliation is part of every branch completion, even when
the branch already contained a documentation update. Work from current `main`
and compare the merged change with [README.md](../../../README.md), the status
and next-work entries in [Docs/Development.md](../../../Docs/Development.md#current-state), and affected
contract/validation documents. Follow [feature-docs](../feature-docs/SKILL.md).

- Always check README's summary, implemented/planned features, installation
  instructions and examples against the merged state. Correct stale claims;
  do not add a cosmetic edit when a document is already current.
- Replace current claims that merged work is local, pending or unimplemented
  with the PR number and merge commit. Preserve historical validation records
  and keep unperformed tests, unreleased versions and open acceptance explicit.
- If a branch was closed without merging, do not describe its work as shipped;
  correct affected status entries to reflect that outcome.

Commit necessary descriptive corrections directly on up-to-date `main`, stage
only the intended documentation files, inspect the staged diff and push `main`
normally. No further approval or documentation PR is needed under the standing
authorisation. Do not include source, manifests, executable scripts/workflows,
resources or test data in this exception. Preserve unrelated local changes;
use a clean checkout when needed. If `main` advances, fetch and reconcile the
documentation before retrying; never force-push.

Report in German what was removed locally, remotely and as worktrees, what was
retained and why, and any documentation commit or remaining limitation.
