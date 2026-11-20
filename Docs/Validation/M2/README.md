# M2 validation evidence

Sources are based on `main` at `34cbe31` (PR #10), with M2 working changes.
`receipt.json` records content hashes rather than treating an uncommitted tree
as a main-branch acceptance result. See [M2Inlines](../../M2Inlines.md) for scope,
commands, passed technical acceptance, pending owner review/merge and platform limits.

The short timing probe is diagnostic: one warmup and three ContinuousClock
samples over the unchanged mixed-v1 corpus. Its source is `timing-probe.swift`;
compile it as a temporary release executable depending on GMSetzer and copying
`Tools/Sources/BenchmarkCorpus/Corpus.swift` into that executable target. Parser
construction is outside the clock. It lacks simultaneous C controls and does
not replace the full package-benchmark result or either gate.

macOS test paths/caches are task-local. Swift 6.2 uses the installed macOS 14.4
SDK and the matching Testing runtime (see `Docs/Portability.md`); deployment
remains macOS 15. Linux tests use the owner's existing host, x86-64/glibc,
Swift 6.4.2. Connection details/credentials are not part of the evidence.

The final snapshot passes the general budget and all three M2 off-mode variants
(core, selected block rule, selected inline rule). `benchmark-final.md` contains
30 cases selected by `.*(CommonMark|GFM|selected inline|selected registry|inline syntax|reference).*`;
`confirmation-cases.txt` records the expected selection. The earlier anchored
filter selected zero cases; that failed invocation is explicitly not validation.
Three preceding complete 48-case runs are retained, including two failed M2
gates. Source hashes distinguish each implementation stage. No timing rows are
mixed across runs for acceptance. Reference comparisons include both exact HTML
and structural block comparisons, as described in `Docs/M2Inlines.md`.

Library commands used isolated writable scratch/cache/config/security paths;
Swift 6.4.2 release tests additionally used `-debug-info-format none`. The final
Linux source archive SHA-256 is recorded in the receipt; its own temporary test
directory was removed after capturing successful output. No connection secrets
or source-export configuration are stored here.

Raw test output retains the CRLF fixture bytes printed by Swift Testing, and
benchmark exports retain their generated final blank line. Narrow Git
attributes preserve those bytes and exempt only those intentional whitespace
forms; implementation and documentation retain the normal whitespace checks.
