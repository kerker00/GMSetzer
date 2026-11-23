# Releasing GMSetzer

> Historical record, archived during 1.0 documentation consolidation. Status,
> counts and plans below describe their original checkpoint. Current contracts
> and workflow are in the [package guide](../README.md) and
> [development handbook](../Development.md).

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
    .package(url: "https://github.com/kerker00/GMSetzer.git", exact: "0.6.0"),
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
against [version-specific notes](../Releases/0.5.0.md), then published as a preview
with zero uploaded assets. GitHub supplies the two automatic source archives.

At that checkpoint the published preview was
[v0.5.0](https://github.com/kerker00/GMSetzer/releases/tag/v0.5.0).
An isolated public-HTTPS SwiftPM consumer resolves exact version 0.5.0 to
`2d8ecef4050976b0e817f0aaeba30fea4b3ac3d1` and exercises the library successfully.
See [executed release evidence](../Validation/Release/0.5.0.md). Products,
dependencies, workflow definitions and protected fixtures are unchanged.


## 0.6.0 publication and 0.7 development

The owner merged [PR #25](https://github.com/kerker00/GMSetzer/pull/25) at
`8ff206178bb07664e89fdc6a119da039fadcd581`. With the agreed publication,
annotated `v0.6.0` was created at that exact commit. The
[release workflow](https://github.com/kerker00/GMSetzer/actions/runs/44950301780)
passes tag validation, macOS/Linux minimum-toolchain checks and draft creation.
The draft's notes, immutable tag target, prerelease flag and zero uploaded
assets were checked before publication.

The latest published source-only preview is
[v0.6.0](https://github.com/kerker00/GMSetzer/releases/tag/v0.6.0).
Both automatic source archives return HTTP 200. A fresh public-HTTPS SwiftPM
consumer resolves exact version 0.6.0 to the tagged commit and passes the
M5/GFM/progressive HTML and identity checks. See [notes](../Releases/0.6.0.md) and
[executed release checks](../Validation/Release/0.6.0.md) for receipts and limits.

The release retains the accepted M6 implementation and changes only its result
identity to `0.6.0` in runtime sources. Historical M6 timings keep their original
hashes and are not relabelled as fresh release measurements. M7 mutation,
benchmark and parser optimization changes are excluded; that work continues
separately as `0.7.0-dev.1`. No tag is moved or rewritten by documentation
follow-up or development-branch synchronization.


## Recorded M7 development

`feature/m7-hardening` continues as `0.7.0-dev.1`, with mutation coverage,
benchmark data and parser optimization kept outside the published 0.6.0 tag.
The published main is merged into this local development branch while retaining
its tested parser/rendering source and original measurement commit history.
Version-only or documentation integration does not retarget historical timing
receipts or imply M7 acceptance; the remaining validation is in
[M7Hardening](M7Hardening.md).

## Swift Package Index and 1.0 preparation

The owner confirmed M8's PR #30 merge (`5f81308`) and requested 1.0 release
preparation on 23 November 2026. `release/1.0.0` finalises identity `1.0.0`,
the frozen API baseline and [notes](../Releases/1.0.0.md); see
[candidate checks](../Validation/Release/1.0.0.md), [readiness](M8Readiness.md)
and [API stability](APIStability.md). The published preview remains 0.6.0.
An intermediate 0.7 tag is not required.
`Scripts/check_release_version.py v1.0.0` now passes without creating a tag.
The release workflow enforces the same version/notes agreement in
addition to tag ancestry, CI, DocC and public-API validation.

The [Index inclusion requirements](https://swiftpackageindex.com/add-a-package)
are a public repository, a valid root Swift package, at least one SemVer tag,
valid `swift package dump-package` JSON with the latest toolchain and a package
that compiles. A 1.0 tag is not required for inclusion. The canonical submission
URL is `https://github.com/kerker00/GMSetzer.git`. No package registry or binary
artifact upload is required.

The root `.spi.yml` follows the Index's
[documented hosting configuration](https://github.com/SwiftPackageIndex/SPIManifest/blob/main/Sources/SPIManifest/Documentation.docc/CommonUseCases.md):
it lists all six documentation targets, with `GMSetzer` first as the landing
target. SPI injects its documentation plugin; no plugin dependency is added
to this library. The [online manifest validator](https://swiftpackageindex.com/validate-spi-manifest)
is available for the submission review. Local DocC checks establish valid
catalogs, not an executed Index build or accepted listing.

After M8 review/merge and successful minimum-toolchain checks:

1. Obtain the owner's confirmation of the exact merged commit/version, then
   create/push the immutable SemVer tag through the existing release sequence.
2. Check the release workflow/draft, an independent public-HTTPS exact-version
   consumer and GitHub's automatic source archives. Publish the release with
   the owner's confirmation.
3. Prepare the package submission through the Index's Add a Package flow.
   Check whether the repository is already indexed before sending a new request.
   Review its exact URL and obtain confirmation before sending the submission;
   it creates an externally visible request. Record the resulting URL/status.
4. After the listing/build results exist, verify all six documentation targets
   and add real Index/documentation/badge links to the README. Do not advertise
   an unverified listing or substitute a successful local build for SPI results.
