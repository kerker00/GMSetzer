# Initial M6 progressive HTML validation

21 November 2026, `feature/m6-progressive-html`, based on
`13f0094623b182c70c3925e9b1f082207db75c97` plus the initial implementation.
Development identity: `0.6.0-dev.1`. This is not M6 completion or a release.
The [source hashes](../../BenchmarkData/m6-progressive-html/source-hashes.json)
identify the changed runtime files and bounded probe driver.

## Executed checks

| Environment | Command and result |
| --- | --- |
| macOS 27.0.1 arm64, Xcode 27.2, Apple Swift 6.4.2 | `swift test --build-system native --disable-sandbox`: 239 tests in 28 suites pass; runtime 0.732 s. |
| Same Mac, optimised tests | `swift test --build-system native -c release --disable-sandbox`: all 239 tests pass; runtime 0.175 s. |
| Same Mac, offline tooling | `python3 -I -m unittest discover -s Scripts`: all 17 tests pass. |
| Owner-provided Linux ARM64 host, Debian 13.7, glibc 2.41, Swift 6.4.2 | `swift test --build-system native --jobs 2`: all 239 tests in 28 suites pass; runtime 2.675 s. |
| Same Linux host | `swift build --build-system native -c release --jobs 2`: optimised library build passes. |
| Same Linux host, offline tooling | `python3 -I -m unittest discover -s Scripts`: all 17 tests pass. |
| Source identity | SHA-256 of all five changed runtime files matches between the local implementation and the Linux test copy. |
| Protected fixtures | `Package.swift`, the parser/extension grammars, both specification JSON corpora and `baseline.json` are unchanged. All 652 CommonMark and 672 GFM protected examples pass. |

macOS commands use task-specific scratch/cache/configuration/security and module
cache directories outside the repository. The native build system avoids the
default build engine's sandbox-blocked dSYM step on this host; its deprecation
warning does not affect these results. The initial default-engine executable
was usable for a diagnostic probe, but the archived comparison uses native
Release builds for both variants.

Linux receives only the package sources, tests, fixture/script data,
documentation needed by the offline checks and licence files in a separate
task directory. It uses the owner's existing ARM64 machine, not a VM or
container. The owner explicitly authorised installing the missing toolchain.
Official [Swift 6.4.2 Debian 13 aarch64](https://www.swift.org/install/linux/debian/13/)
was installed in the user's `.local/opt/swift-6.4.2`; no system toolchain or
shell profile was replaced. Test commands explicitly prepend its `usr/bin`
to `PATH`. Existing compiler/linker/runtime dependencies were sufficient.

The downloaded archive's detached signature was verified against the
[official Swift 6 release key](https://www.swift.org/keys/active/), fingerprint
`52BB7E3DE28A71BE22EC05FFEF80A866B47A981F`, before extraction. The first key
download was content-encoded and failed import; the individual release key
was retrieved with HTTP decompression and then verified. No unverified
toolchain was executed. The Linux runtime reports that backtrace path/
environment protection is unavailable; builds/tests still exit successfully.
These checks do not establish crash-backtrace behavior or a new minimum OS.

## Functional coverage

Twelve added tests consist of eleven focused API tests plus a corpus-wide
comparison. They verify deferred rendering, no evaluation of later hooks
before the requested group, early consumption stop, in-render and appendix
cancellation, source ranges, oversized indivisible blocks, invalid requests,
concurrent/out-of-order requests, forward links, safe HTML/URLs, empty results,
non-rendering definitions and explicit fallback modes. Footnote numbering,
cyclic/repeated references, lazy appendices and combined front matter/math/
alerts/callouts retain complete-document behavior.

The corpus comparison assembles grouped output for every one of the 1,324
specification inputs in safe and conformance modes and compares it byte for
byte with full rendering. The existing conformance suites separately compare
full output with the protected expected HTML. Baselines were not weakened.

## Measurement scope and outstanding gates

The [bounded Release stage probe](../../Benchmarks.md#m6-progressive-html-first-stage-probe)
records one 1 MB workload, three samples per variant. It demonstrates earlier
HTML-group availability after parsing; it measures no WebView, device latency,
allocation counts or peak memory. The archived hashes match the measured
implementation. Full-output timing remains similar within this limited sample.

M6 still needs the 100 KB/5 MB and complete workload/selected-extension matrix,
allocation/peak-memory evidence and new validation with the minimum Swift 6.2
compiler. Full benchmark/long-test runs retain their separate execution gate.
Consumer UI integration and device checks remain outside this library change.
General hardening/fuzzing stays M7; API/DocC/1.0 completion stays M8.

No push, PR creation, tag or publication is part of this local validation.


## Subsequent measurement-only follow-up

The owner subsequently authorised the [42-case Linux ARM64 matrix](linux-arm64-measurements.md).
It supplies the 100 KB/1 MB/5 MB workload/annotation timings, fresh-process peak
RSS and synchronous-thread gross allocation evidence missing above, at unchanged
library sources (`087e694`). It records one representative all-M5 composition;
minimum Swift 6.2 and quantitative M6 target acceptance remain open. The expanded
v2 driver differs from the original macOS probe; the original source hashes
remain evidence for the v1 driver at `087e694`. No fresh library-test run or
consumer integration is claimed by that follow-up.
