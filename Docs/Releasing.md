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
   git tag -a v0.4.0 <merged-commit> -m 'GMSetzer 0.4.0'
   git push origin refs/tags/v0.4.0
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
    .package(url: "https://github.com/kerker00/GMSetzer.git", exact: "0.4.0"),
],
targets: [
    .target(name: "MyTarget", dependencies: [
        .product(name: "GMSetzer", package: "GMSetzer"),
    ]),
]
```

The package URL can be entered in Xcode's package dependency dialog as well.
Use an exact version for deliberate updates during pre-1.0 development.

## 0.5.0 preparation

PR #23 (`2d8ecef`) merges the source-only M5 preview preparation after
[functional acceptance](M5Acceptance.md). It sets result identity `0.5.0` and adds
[version-specific notes](Releases/0.5.0.md) and
[executed preparation evidence](Validation/Release/0.5.0.md). Workflows,
products, dependencies and protected fixtures are unchanged.

The latest published version remains 0.4.0. Preparation is merged; publication
still requires owner confirmation of an exact tag commit, successful tag CI and
confirmation of the resulting draft. Resolving a preparation commit through
SwiftPM proves source-package consumption, not that an exact 0.5.0 version
tag exists. No tag or release was created by the preparation PR.

The intended source-only preview keeps GitHub's two automatic source archives;
no binary uploads are added.
