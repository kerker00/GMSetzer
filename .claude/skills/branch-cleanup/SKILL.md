---
name: branch-cleanup
description: Clean up GMSetzer branches and worktrees after confirmed PR merges, and record the merged state in the project documentation.
---

# Clean up after a confirmed merge

The owner transferred Setzkit's standing cleanup authorization to GMSetzer on
19 November 2026: delete local and remote branches proven merged into `main`,
and remove their clean worktrees, without asking again. This authorization
covers cleanup only; it does not authorize merging PRs, unrelated pushes,
releases, tags, CI or making the repository public.

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

## Record the merged state

Follow [feature-docs](../feature-docs/SKILL.md). Update the affected status and
next-work entries in [Docs/Plan.md](../../../Docs/Plan.md), and current contract
documents or README references that still describe the merged work as pending.
Use the PR number and merge commit instead of a deleted branch as evidence.
Keep historical records and outstanding acceptance criteria intact.

When a documentation update is needed, commit it on a short docs branch from
`origin/main`. Follow existing session authorization for pushing or opening a
PR; cleanup authorization alone does not grant either. The owner merges.

Report in German what was removed locally, remotely and as worktrees, what was
retained and why, and any documentation commit or remaining limitation.
