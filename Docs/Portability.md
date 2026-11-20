# Minimum toolchain and Linux verification

Initial verification on 20 November 2026 uses library sources from `7c0f4ea`
(merged M1-B); the development probe/runner are recorded in `34ba92b`.
The subsequent [block-phase extraction](BlockPhases.md) at `4c4fd46` adds a
complete Linux/x86-64 suite and repeats minimum-toolchain builds/tests. The
runtime dependency graph and deployment targets remain unchanged.

## Results and limits

| Check | Result |
| --- | --- |
| Swift 6.2 library build, macOS | All five modules build |
| Swift 6.2 macOS Swift Testing suite | All 57 tests in nine suites pass; all protected spec IDs retained |
| Swift 6.2 static Linux ARM64 build | All five modules and the standalone probe build; linked probe is a static AArch64 ELF |
| Actual Linux execution | Probe passes in a network-free QEMU/Alpine guest, Linux 6.12.115-0-virt |
| Spec checks inside Linux | All 652 CommonMark and 672 pinned GFM inputs compared; 339/652 and 339/672 exact HTML passes, every protected baseline ID retained |
| Targeted Linux checks | Original bytes/BOM offsets, tight/loose and nested wrapper rendering, projected fallback/tab/CRLF, invalid UTF-8/NUL, invalid tree/fallback-owner rejection pass |
| Extracted phases, Linux x86-64/GNU | All 57 Swift Testing tests pass with Swift 6.4.2 and glibc 2.44 on an existing SSH host |
| Extracted phases, minimum compiler | All 57 macOS tests and the Linux ARM64 cross-build pass with Swift 6.2 |

Evidence: [receipt and artifact/source checksums](Validation/Portability/receipt.json),
[macOS test summary](Validation/Portability/mac-swift62-summary.txt),
[Linux boot and probe output](Validation/Portability/linux-aarch64.txt).
The original Linux ARM64 probe is **not the complete 57-test Swift Testing
suite**. The Static Linux SDK lacks `Testing`. The subsequent full Linux
x86-64/glibc run uses Swift 6.4.2; a full Linux suite on the minimum Swift 6.2
compiler remains open. There is no emulation performance claim. iOS,
visionOS and the minimum Apple OS runtimes are not verified by these host tests.

## Toolchain and SDK selection

The official Swift 6.2 macOS package was signature/notarization checked and
extracted under `/private/tmp`; no installer was run and Xcode was not switched.
The matching Static Linux SDK checksum was checked against Swift.org:
`d2225840e592389ca517bbf71652f7003dbf45ac35d1e57d98b9250368769378`.
Swift.org requires the [matching open-source toolchain for Static Linux](https://www.swift.org/documentation/articles/static-linux-getting-started.html),
including when building on macOS; the Xcode compiler is not interchangeable.

The initial macOS test attempts used Xcode's newer SDK/frameworks and failed
with `unknown argument: '-target-arch-variant'`. Even explicitly selecting the
Swift 6.2 Testing module did not fix its dependencies on the newer SDK. Selecting
the already installed Command Line Tools **macOS 14.4 SDK** and the toolchain's
own Testing module/runtime resolves this: all 57 tests pass. This SDK choice
does not change the package's macOS 15 deployment target or prove macOS 14
runtime support. No SDK or toolchain was installed globally.

## Reproduction

From the repository root, set paths to the Swift 6.2 compiler, its own Testing
directory and the extracted static SDK bundle directory:

```sh
GMSETZER_SWIFT62=/path/to/swift-6.2.xctoolchain/usr/bin/swift
GMSETZER_TESTING62=/path/to/swift-6.2.xctoolchain/usr/lib/swift/macosx/testing
GMSETZER_SDKS=/path/to/isolated/swift-sdks

"$GMSETZER_SWIFT62" test --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX14.4.sdk --disable-xctest -Xswiftc -I -Xswiftc "$GMSETZER_TESTING62" -Xlinker "-L$GMSETZER_TESTING62" -Xlinker -rpath -Xlinker "$GMSETZER_TESTING62"
"$GMSETZER_SWIFT62" build --swift-sdk aarch64-swift-linux-musl --swift-sdks-path "$GMSETZER_SDKS"
"$GMSETZER_SWIFT62" build --package-path Tools/PortabilityProbe --swift-sdk aarch64-swift-linux-musl --swift-sdks-path "$GMSETZER_SDKS"
```

In the restricted workspace, all commands also used `--disable-sandbox`,
separate `--scratch-path` directories and redirected compiler/package
cache/config/security paths under `/private/tmp`. No library package dependency
was added. The probe imports Foundation in its separate development package.

Copy the static probe and the three JSON files in
`Tests/SetzerSpecTests/Resources` to a compatible Linux machine, then run
`PortabilityProbe /path/to/resources`. It fails on any lost protected ID or
targeted check. It compares exact HTML with conformance rendering options;
partial conformance is reported as counts, never as 652/672 complete passes.

Alternatively, with trusted Alpine ARM64 netboot artifacts and QEMU installed:

```sh
python3 -I Scripts/run_linux_portability_probe.py --kernel /path/to/vmlinuz-virt --initramfs /path/to/initramfs-virt --binary /path/to/PortabilityProbe --fixtures Tests/SetzerSpecTests/Resources --log /private/tmp/gmsetzer-linux.log
```

The runner builds a temporary initramfs with the probe/fixtures, boots the
QEMU [`virt` platform](https://www.qemu.org/docs/master/system/arm/virt.html)
using TCG, two CPUs and 1536 MiB RAM, and requires both the success marker and
guest exit status. It has a 120-second process timeout, no NIC, no disk/host
shares and removes its temporary guest after shutdown. Kernel/initramfs URLs,
hashes and QEMU version are in the receipt. These binaries are test tools and
are not included in the library or this repository.

## Span implications for M1-C

Swift 6.2 typechecks at `arm64-apple-macosx15.0` establish:

| API | Result |
| --- | --- |
| Borrowing a `Span<UInt8>` and reading `count` | Pass |
| `withUnsafeBufferPointer { $0.span.count }` | Pass |
| Direct `Array.span` | Rejected: requires macOS 26 |
| An unguarded `UTF8Span` parameter | Rejected: requires macOS 26; passes when targeting macOS 26 |

The small sources and expected rejection diagnostics are retained alongside
the receipt. Back-deployment of the `Span` type does not imply that every
convenience API shares it. Retain the owned byte-buffer path; a borrowed-span
implementation needs an explicit lifetime/availability contract and measurements
before replacing it. This verification does not itself introduce spans or
change the public API. Next: split the block loop before registry work, then
prove the M1-C extension/storage contracts and inline budget.

## M1-C/M1-D acceptance update

The [M1 acceptance record](M1Acceptance.md) repeats the full **70-test** suite
with Swift 6.4.2 macOS debug/release, Swift 6.2 macOS and Swift 6.4.2 on the
existing Linux x86-64/glibc host. All five modules also cross-build for static
Linux ARM64 with Swift 6.2. No new VM/container or tool installation was used.
The earlier ARM64 execution evidence remains historical; this update does not
claim another ARM64 runtime run, a full Linux Swift 6.2 suite or minimum Apple
OS runtime checks. No Span/UTF8Span platform availability requirement changed.


## M2 verification (20 November 2026)

The M2 source snapshot in [M2Inlines.md](M2Inlines.md) passes **96 Swift tests**
on macOS/ARM64 with Swift 6.4.2 in debug/release, on macOS with the same Swift
6.2/SDK/Testing setup described above, and on the owner's existing Linux/x86-64
host with Swift 6.4.2/glibc 2.44. Only requested sources/tests were transferred
after explicit approval; no replacement execution environment was created.
The core still uses the standard library only. This update does not claim a
fresh M2 static-ARM64 execution, Linux/Swift 6.2 suite, minimum Apple-OS run or
consumer UI/device integration. Raw output and source hashes are in
[Validation/M2](Validation/M2/).
