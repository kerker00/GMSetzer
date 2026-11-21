# Releasing GMSetzer

GMSetzer releases contain source only. GitHub supplies the source ZIP and tar.gz
downloads automatically. No build artifacts are uploaded. Swift Package Manager
resolves version tags in the Git repository; it does not use release assets or
require a package registry.

## Checks

`.github/workflows/ci.yml` runs for pull requests to `main`, pushes to `main`,
manual dispatch and as a reusable release check. It runs the library tests
(including both protected specification corpora), an optimized library build
and the offline Python script tests on macOS and Linux with Swift 6.2.
Actions are pinned to commits. Library builds need no consumer checkout,
development package dependencies or credentials beyond repository access.
Benchmarks and the separate `Tools/` reference suite are not part of CI.

## Release sequence

1. Prepare `Docs/Releases/<version>.md` with features, limitations and package
   installation instructions. Obtain the owner's review and merge the release
   preparation PR into `main`; the owner merges.
2. After owner confirmation, fetch `main`, verify a clean checkout and choose
   the exact merged commit. Create and push an annotated SemVer tag, for example:

   ```sh
   git fetch origin
   git tag -a v0.5.0 <merged-commit> -m 'GMSetzer 0.5.0'
   git push origin refs/tags/v0.5.0
   ```

3. The `Release` workflow verifies that the tag has the form `vMAJOR.MINOR.PATCH`,
   belongs to `main` and has nonempty version-specific notes. It reruns CI at
   the tagged commit, then creates a **draft** release using those notes.
   Versions below 1.0 are marked as prereleases. A rerun leaves an existing
   release untouched. No tag is moved or overwritten.
4. Review the draft and successful workflow results, then publish with owner
   confirmation. GitHub supplies the two source archive links. A failed check
   prevents creation of the draft; fix the problem before choosing a new tag.

A tag can already be resolved through Swift Package Manager while its GitHub
release is still a draft. The repository is public; source archives and SwiftPM
dependencies are available over HTTPS without GitHub authentication. Changing
repository visibility remains a separate owner decision.

Consumers can pin the version with:

```swift
dependencies: [
    .package(url: "https://github.com/kerker00/GMSetzer.git", exact: "0.5.0"),
],
targets: [
    .target(name: "MyTarget", dependencies: [
        .product(name: "GMSetzer", package: "GMSetzer"),
    ]),
]
```

The package URL can be entered in Xcode's package dependency dialog as well.
Use an exact version for deliberate updates during pre-1.0 development.

## 0.5.0 publication

PR #23 (`2d8ecef`) merged the source-only M5 preview preparation after
[functional acceptance](M5Acceptance.md). With the owner's confirmation,
annotated `v0.5.0` was created at that exact commit and the existing
[release workflow](https://github.com/kerker00/GMSetzer/actions/runs/44827793180)
passed tag validation, macOS/Linux CI and draft creation. The draft was checked
against [version-specific notes](Releases/0.5.0.md), then published as a preview
with zero uploaded assets. GitHub supplies the two automatic source archives.

The latest published preview is
[v0.5.0](https://github.com/kerker00/GMSetzer/releases/tag/v0.5.0).
An isolated public-HTTPS SwiftPM consumer resolves exact version 0.5.0 to
`2d8ecef4050976b0e817f0aaeba30fea4b3ac3d1` and exercises the library successfully.
See [executed release evidence](Validation/Release/0.5.0.md). Products,
dependencies, workflow definitions and protected fixtures are unchanged.


## 0.6.0 / 0.7 development boundary

The owner selected accepted main `0cf6690` for separate source-only 0.6.0
preparation on 21 November 2026. [PR #25](https://github.com/kerker00/GMSetzer/pull/25)
from `release/0.6.0` retains the accepted M6
parser/rendering implementation and changes only its result identity to
`0.6.0` in runtime sources. It excludes all M7 commits. Owner review/merge,
exact merged-commit selection and the confirmed tag/publication sequence
remain required; v0.5.0 remains the published preview until then.

`feature/m7-hardening` continues separately as `0.7.0-dev.1`. Its mutation
coverage, baseline data and parser optimization are not part of the 0.6.0
release. Existing M7 measurements keep their recorded identity/hashes; the
version-only transition does not retarget them or imply 0.7 acceptance.
