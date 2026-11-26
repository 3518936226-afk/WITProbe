# WITProbe compatibility report

Status: UNKNOWN
Direction: provider-upgrade
Actual provider: new
Expected contract/environment: old
Scope: structural; root package versions are mapped explicitly; this is not a runtime linking proof.
Rules: value-sync-v2

## Summary

Findings: 579; breaking: 0; unknown: 579; errors: 0; changes: 43.
- [UNKNOWN] UNSUPPORTED_RESOURCE: 374
  Action: Review nominal resource identity, ownership and lifecycle; these are not covered by the value-type rules.
  - Example: new/import/interface:wasi:io/error@0.2.1/type/error
  - Example: old/import/interface:wasi:io/error@0.2.0/type/error
  - Example: new/import/interface:wasi:cli/stdin/type/input-stream
- [UNKNOWN] UNMAPPED_DEPENDENCY_VERSION: 17
  Action: Review the dependency identity mapping explicitly; package versions are not erased automatically.
  - Example: import/interface:wasi:io/poll@0.2.1
  - Example: import/interface:wasi:io/error@0.2.1
  - Example: import/interface:wasi:io/streams@0.2.1
- [UNKNOWN] UNSUPPORTED_RESOURCE_OR_ACCESSOR: 188
  Action: Review nominal resource identity, ownership and lifecycle; these are not covered by the value-type rules.
  - Example: new/import/interface:wasi:io/poll@0.2.1/function/[method]pollable.block
  - Example: new/import/interface:wasi:io/poll@0.2.1/function/[method]pollable.ready
  - Example: old/import/interface:wasi:io/poll@0.2.0/function/[method]pollable.block

## Findings

- [UNKNOWN] UNMAPPED_DEPENDENCY_VERSION at import/interface:wasi:io/poll@0.2.1
  Dependency identity differs only by a version suffix; no mapping was proven. Action: Review the dependency identity mapping explicitly; package versions are not erased automatically.
- [UNKNOWN] UNMAPPED_DEPENDENCY_VERSION at import/interface:wasi:io/error@0.2.1
  Dependency identity differs only by a version suffix; no mapping was proven. Action: Review the dependency identity mapping explicitly; package versions are not erased automatically.
- [UNKNOWN] UNMAPPED_DEPENDENCY_VERSION at import/interface:wasi:io/streams@0.2.1
  Dependency identity differs only by a version suffix; no mapping was proven. Action: Review the dependency identity mapping explicitly; package versions are not erased automatically.
- [UNKNOWN] UNMAPPED_DEPENDENCY_VERSION at import/interface:wasi:sockets/tcp@0.2.1
  Dependency identity differs only by a version suffix; no mapping was proven. Action: Review the dependency identity mapping explicitly; package versions are not erased automatically.
- [UNKNOWN] UNMAPPED_DEPENDENCY_VERSION at import/interface:wasi:sockets/udp@0.2.1
  Dependency identity differs only by a version suffix; no mapping was proven. Action: Review the dependency identity mapping explicitly; package versions are not erased automatically.
- [UNKNOWN] UNMAPPED_DEPENDENCY_VERSION at import/interface:wasi:random/random@0.2.1
  Dependency identity differs only by a version suffix; no mapping was proven. Action: Review the dependency identity mapping explicitly; package versions are not erased automatically.
- [UNKNOWN] UNMAPPED_DEPENDENCY_VERSION at import/interface:wasi:random/insecure@0.2.1
  Dependency identity differs only by a version suffix; no mapping was proven. Action: Review the dependency identity mapping explicitly; package versions are not erased automatically.
- [UNKNOWN] UNMAPPED_DEPENDENCY_VERSION at import/interface:wasi:sockets/network@0.2.1
  Dependency identity differs only by a version suffix; no mapping was proven. Action: Review the dependency identity mapping explicitly; package versions are not erased automatically.
- [UNKNOWN] UNMAPPED_DEPENDENCY_VERSION at import/interface:wasi:filesystem/types@0.2.1
  Dependency identity differs only by a version suffix; no mapping was proven. Action: Review the dependency identity mapping explicitly; package versions are not erased automatically.
- [UNKNOWN] UNSUPPORTED_RESOURCE at new/import/interface:wasi:io/error@0.2.1/type/error
  Public type contains an unsupported type, regardless of function usage. Action: Review nominal resource identity, ownership and lifecycle; these are not covered by the value-type rules.
- [UNKNOWN] UNSUPPORTED_RESOURCE at old/import/interface:wasi:io/error@0.2.0/type/error
  Public type contains an unsupported type, regardless of function usage. Action: Review nominal resource identity, ownership and lifecycle; these are not covered by the value-type rules.
- [UNKNOWN] UNMAPPED_DEPENDENCY_VERSION at import/interface:wasi:clocks/wall-clock@0.2.1
  Dependency identity differs only by a version suffix; no mapping was proven. Action: Review the dependency identity mapping explicitly; package versions are not erased automatically.
- [UNKNOWN] UNSUPPORTED_RESOURCE at new/import/interface:wasi:cli/stdin/type/input-stream
  Public type contains an unsupported type, regardless of function usage. Action: Review nominal resource identity, ownership and lifecycle; these are not covered by the value-type rules.
- [UNKNOWN] UNSUPPORTED_RESOURCE at new/import/interface:wasi:io/poll@0.2.1/type/pollable
  Public type contains an unsupported type, regardless of function usage. Action: Review nominal resource identity, ownership and lifecycle; these are not covered by the value-type rules.
- [UNKNOWN] UNSUPPORTED_RESOURCE at new/import/interface:wasi:io/streams@0.2.1/type/error
  Public type contains an unsupported type, regardless of function usage. Action: Review nominal resource identity, ownership and lifecycle; these are not covered by the value-type rules.
- [UNKNOWN] UNSUPPORTED_RESOURCE at old/import/interface:wasi:cli/stdin/type/input-stream
  Public type contains an unsupported type, regardless of function usage. Action: Review nominal resource identity, ownership and lifecycle; these are not covered by the value-type rules.
- [UNKNOWN] UNSUPPORTED_RESOURCE at old/import/interface:wasi:io/poll@0.2.0/type/pollable
  Public type contains an unsupported type, regardless of function usage. Action: Review nominal resource identity, ownership and lifecycle; these are not covered by the value-type rules.
- [UNKNOWN] UNSUPPORTED_RESOURCE at old/import/interface:wasi:io/streams@0.2.0/type/error
  Public type contains an unsupported type, regardless of function usage. Action: Review nominal resource identity, ownership and lifecycle; these are not covered by the value-type rules.
- [UNKNOWN] UNMAPPED_DEPENDENCY_VERSION at import/interface:wasi:filesystem/preopens@0.2.1
  Dependency identity differs only by a version suffix; no mapping was proven. Action: Review the dependency identity mapping explicitly; package versions are not erased automatically.
- [UNKNOWN] UNMAPPED_DEPENDENCY_VERSION at import/interface:wasi:random/insecure-seed@0.2.1
  Dependency identity differs only by a version suffix; no mapping was proven. Action: Review the dependency identity mapping explicitly; package versions are not erased automatically.
Showing 20 of 579 findings; use --detail full for every finding and symbol path.

## Changes

- MODIFIED at import/interface:wasi:cli/stdin
- MODIFIED at import/interface:wasi:cli/stderr
- MODIFIED at import/interface:wasi:cli/stdout
- ADDED at import/interface:wasi:io/poll@0.2.1
- ADDED at import/interface:wasi:io/error@0.2.1
- REMOVED at import/interface:wasi:io/poll@0.2.0
- REMOVED at import/interface:wasi:io/error@0.2.0
- ADDED at import/interface:wasi:io/streams@0.2.1
- ADDED at import/interface:wasi:sockets/tcp@0.2.1
- ADDED at import/interface:wasi:sockets/udp@0.2.1
- REMOVED at import/interface:wasi:io/streams@0.2.0
- ADDED at import/interface:wasi:random/random@0.2.1
- REMOVED at import/interface:wasi:sockets/tcp@0.2.0
- REMOVED at import/interface:wasi:sockets/udp@0.2.0
- ADDED at import/interface:wasi:random/insecure@0.2.1
- REMOVED at import/interface:wasi:random/random@0.2.0
- ADDED at import/interface:wasi:sockets/network@0.2.1
- ADDED at import/interface:wasi:filesystem/types@0.2.1
- ADDED at import/interface:wasi:clocks/wall-clock@0.2.1
- REMOVED at import/interface:wasi:random/insecure@0.2.0
Showing 20 of 43 changes; use --detail full for complete definitions.
