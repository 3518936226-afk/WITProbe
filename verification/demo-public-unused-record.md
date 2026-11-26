# WITProbe compatibility report

Status: UNKNOWN
Direction: provider-upgrade
Actual provider: new
Expected contract/environment: old
Scope: structural; root package versions are mapped explicitly; this is not a runtime linking proof.
Rules: scalar-sync-v1

## Findings

- [UNKNOWN] UNSUPPORTED_COMPOSITE at new/export/interface:demo:closed-loop/calculator/type/future-item
  Public type is outside the scalar/alias rules, regardless of function usage. Action: Review ordered members and nested types, or add a tested composite-type rule; UNKNOWN blocks the gate.

## Changes

- MODIFIED at export/interface:demo:closed-loop/calculator
- PUBLIC_TYPE_ADDED at export/interface:demo:closed-loop/calculator/type/future-item

