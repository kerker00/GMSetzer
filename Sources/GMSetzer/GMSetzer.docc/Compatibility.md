# Compatibility and versioning

Understand the package's source API and the limits of its compatibility promises.

Development toward 1.0 retains the six library products and Swift 6.2 minimum.
Declared Apple deployment targets are macOS 15, iOS 18 and visionOS 2; Linux
is supported. Platform build results and actual runtime checks have distinct
scopes; consult the repository portability report for measured hosts.

The latest published preview remains 0.6.0. Development documentation does
not imply publication of a stable tag. Before 1.0, APIs can change. The
planned 1.x policy preserves public source signatures, documented grammar,
coordinate/ownership contracts, named extension/token/message identifiers and
safe defaults. Source-breaking changes require a major release, including
changes that break exhaustive switches over public enums.

Bug fixes can correct nonconforming parsing or unsafe rendering. New syntax
is opt-in through explicit selections. Native finding wording and generated
HTML formatting can be corrected; applications should use message keys and
structural HTML contracts rather than treating every output string as an
immutable serialisation format.

Source compatibility does not promise binary ABI, in-memory layouts, stable
hash values, cross-version node indices, persisted tree formats or fixed
timings. Trees and service values are immutable snapshots, not archive schemas.
