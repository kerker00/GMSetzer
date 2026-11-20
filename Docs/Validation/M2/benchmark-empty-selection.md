warning: '--skip-update' option is deprecated and will be removed in a future release
Building for debugging...
[Computing dependencies]
[Using on-disk description]
[12 / 55]
[23 / 87] CDarwinOperatingSystemStats
[36 / 92] RealModule
[48 / 91] SwiftRuntimeHooks
[57 / 90] MallocInterposerSwift
[66 / 78] Benchmark
[79 / 91] Benchmark
[82 / 87] Benchmark
[91 / 96] BenchmarkTool-product
[92 / 96] Benchmark
[93 / 95] BenchmarkTool-product
[95 / 95] BenchmarkTool-product
Build complete! (3,10 secs)

[33mWarning: this project depends on the benchmark package using its legacy
identifier 'package-benchmark'. The repository has been renamed; please update
your Package.swift to use the new URL and identifier:

  .package(url: "https://github.com/ordo-one/benchmark", ...)
  .product(name: "Benchmark", package: "benchmark"),
  .plugin(name: "BenchmarkPlugin", package: "benchmark"),

Support for the legacy 'package-benchmark' identifier will be removed in a
future release.[0m


## Baseline 'Current_run'

```
Host 'BlackBook.local' with 8 'arm64' processors with 16 GB memory, running:
Darwin Kernel Version 27.0.0: Tue Aug 11 21:02:16 PDT 2026; root:xnu-13432.1.9~1/RELEASE_ARM64_T8112
```
