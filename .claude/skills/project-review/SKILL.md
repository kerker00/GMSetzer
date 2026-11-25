---
name: project-review
description: Review GMSetzer's overall state against its requirements and roadmap, with evidence per platform and toolchain, branch/release state, Swift Package Index status, code and documentation health, and a prioritised recommendation. Use when the owner asks for a general review or status ("Review", "wo stehen wir"), before a release, and at the end of a milestone.
---

# Review GMSetzer against its goals

A review answers one question: how far is GMSetzer from its goals, and what
is proven? Keep three levels apart for every claim:

1. **In code** – on `main` (or only on a branch; say which).
2. **Executed** – tests, corpora or benchmarks that actually ran, with
   platform, toolchain and commit.
3. **Published** – tagged, released and resolvable by consumers.

The review is read-only: do not fix findings during it unless the owner asks.
Ask before long test runs and before full benchmarks; builds are fine. Write
project documentation in English, report to the owner in German.

## 1. Goals

Read the goals before looking at code, from `main`:

- `Docs/Development.md`: requirements, decisions, current state, roadmap,
  release checklist
- `README.md` and `Docs/README.md`: what is promised to consumers (CommonMark
  and GFM coverage, Linux support, deployment minimums, 1.x compatibility)
- `CLAUDE.md` rules that are product goals: no runtime dependencies, no
  Foundation in the core, everything builds on Linux, protected spec IDs

## 2. Branch and release state

```bash
git fetch --prune
git log --oneline -5 origin/main
git tag --sort=-v:refname | head -5
gh release list --limit 5
gh pr list --state open --json number,headRefName,baseRefName,title
```

- Commits on `main` since the latest tag and whether they touch runtime
  sources, the manifest or the public API (`Docs/API/`).
- Stacked PRs, stale branches and worktrees.
- Swift Package Index: is the package listed, and do its build and
  documentation results match the claims? Never submit or change a listing
  from a review.

## 3. Evidence

- Spec baseline: all IDs in `Tests/SetzerSpecTests/Resources/baseline.json`
  still protected (652 CommonMark / 672 GFM at 1.0).
- Latest CI runs on `main` (`gh run list --branch main --limit 5`) and what
  they cover: minimum Swift 6.2 on macOS and Linux, DocC, API compatibility.
- Records under `Docs/Validation/`: which commit each one validates. A record
  for an older commit is not proof for the current one.
- Benchmarks and performance budgets: date and commit of the last receipts.

## 4. Platform coverage

- macOS locally (current Swift) and in CI (minimum Swift).
- Linux x86_64: `ssh PowerG5` (CachyOS, fish shell: wrap commands in
  `bash -lc '…'`).
- Linux aarch64: `ssh pipi` (Raspberry Pi 5, Debian 13, 16 KiB pages). Swift
  comes from swiftly in the user account; non-login SSH commands need
  `. ~/.local/share/swiftly/env.sh` first. The runtime notice that
  backtracing is disabled is expected there.
- Build from a fresh anonymous HTTPS clone of the tag or commit in a
  temporary directory, then remove it. Builds need no approval, tests on
  these hosts follow the normal rules.

## 5. Code health

```bash
for p in 'import Foundation' 'fatalError(' 'try!' 'as!' 'TODO' '@unchecked Sendable' 'nonisolated(unsafe)'; do
  echo "$p: $(git grep -F -c "$p" origin/main -- 'Sources/*.swift' | awk -F: '{s+=$NF} END {print s+0}')"
done
swift package dump-package | python3 -I -c "import json,sys; d=json.load(sys.stdin); print(d['dependencies'])"
```

- No runtime dependencies; Foundation only where the rules allow it.
- Source against test lines, largest files, public API size against the
  frozen baseline.
- Licence hygiene: notices preserved, no code taken from reference checkouts
  under `Parser/`.

## 6. Documentation health

- README and `Docs/README.md` match the latest release (version, platforms,
  Linux statement, links to validation records).
- `Docs/Development.md` current state and roadmap match `main`; no references
  to branches that no longer exist.

## 7. Report to the owner

In German, manager style, plain language. Structure:

1. **Kurzfazit** – two or three sentences.
2. **Was gut ist** – short, with numbers.
3. **Wo es hakt** – numbered findings, each with the concrete evidence
   (commit, run, record, count) and why it matters for consumers or Setzkit.
4. **Abgleich mit den Zielen** – table: goal / in code / executed / published.
5. **Empfehlung** – at most six steps in priority order.

Say what was not checked. Offer the review as a shareable page in one line.

## Known pitfalls

- In zsh, `$var:r…` is a variable modifier: write `"${sha}:refs/heads/main"`
  in refspecs.
- Swift Testing filters need parentheses; a filter without a match reports
  success with zero tests.
