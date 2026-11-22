# Bounded parser stress probe

Development-only executable; it adds no library or root-package dependency.
It deterministically mutates six authored seed families with the fixed seed
`0x6d375f7374726573`. The default is 1,024 inputs, each capped at 4,096 bytes.
An optional integer argument selects 1–16,384 inputs.

For each input it parses CommonMark, GFM, and each with all five M5 extensions,
with syntax collection off/on: eight parses per input. Assertions check original
bytes, annotation invariance, extension-result validity, public document
revalidation, standard-library UTF-16 replacement decoding, full HTML and
reverse-requested progressive groups. Failure terminates the process.

On a host with Swift AddressSanitizer support, build and run separately:

```sh
swift build --package-path Tools/ParserStressProbe --sanitize address \
  --scratch-path /tmp/gmsetzer-stress-build
/tmp/gmsetzer-stress-build/debug/ParserStressProbe 1024
```

Use a fresh task-specific scratch path. Keep assertions enabled (Debug); a
successful run prints one JSON summary. Obtain the owner's existing approval
for long tests, and enforce a whole-process timeout in unattended runs. The
22 November 2026 Mac run used a 180-second process-group timeout and finished
in 58.4 seconds, with 8,192 parses and no AddressSanitizer finding.

This is bounded deterministic mutation, **not coverage-guided libFuzzer**.
It does not prove larger-input scaling, absence of all memory errors or every
extension combination. See [M7 validation](../../Docs/Validation/M7/utf8-2026-11-22.md)
for actual toolchain capabilities and retained evidence.

## Separate coverage-guided Linux harness

`Fuzzing/ParserFuzz.swift` exports `LLVMFuzzerTestOneInput` and checks the same
four profile pairs, document/source invariants and progressive HTML equality.
It is outside the CLI target. On an existing native Linux host with Swift,
Clang, `nm` and installed Clang fuzzer/UBSan archives:

```sh
python3 -I Tools/ParserStressProbe/Fuzzing/run-linux.py \
  --output /tmp/gmsetzer-parser-fuzz --seconds 180
```

The output directory must be new. The runner installs nothing, records source,
runtime and executable hashes, builds Debug library objects with Swift fuzzer
instrumentation, and links the existing system archives separately. This avoids
depending on Swift's packaged sanitizer-linker archives. It checks library
coverage symbols and libFuzzer's counters/executed-unit report; a successful
link alone is not a campaign result. Compatibility depends on the installed
compiler/runtime pair and must be established by actual execution.

The campaign uses seven authored seeds, seed `7348327`, a 4,096-byte maximum,
five-second per-input timeout, 2 GiB RSS limit and a whole-process time bound.
Failures and crash inputs remain in the output directory. Assertions stay
enabled. This runner enables coverage-guided fuzzing **without ASan**; the
separate Mac ASan evidence is not attributed to this Linux executable. Obtain
owner approval for long runs and do not compete with timings on that host.
