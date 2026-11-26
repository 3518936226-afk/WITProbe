# WITProbe compatibility report

Status: COMPATIBLE
Direction: provider-upgrade
Actual provider: new
Expected contract/environment: old
Scope: structural; root package versions are mapped explicitly; this is not a runtime linking proof.
Rules: resource-sync-v3

## Summary

Findings: 0; breaking: 0; unknown: 0; errors: 0; changes: 0.

## Explicit dependency version assumptions

Each new package is aligned to the declared old package before structural checking. Original IR is retained; this does not prove runtime resource identity or lifecycle behavior.
- wasi:io@0.2.0 -> wasi:io@0.2.1
- wasi:clocks@0.2.0 -> wasi:clocks@0.2.1
- wasi:random@0.2.0 -> wasi:random@0.2.1
- wasi:sockets@0.2.0 -> wasi:sockets@0.2.1
- wasi:filesystem@0.2.0 -> wasi:filesystem@0.2.1

## Findings

All obligations in the supported synchronous value-type scope are satisfied.

## Changes

No selected-world contract changes.
