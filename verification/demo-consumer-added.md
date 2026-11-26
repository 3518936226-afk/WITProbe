# WITProbe compatibility report

Status: BREAKING
Direction: consumer-upgrade
Actual provider: old
Expected contract/environment: new
Scope: structural; root package versions are mapped explicitly; this is not a runtime linking proof.
Rules: scalar-sync-v1

## Findings

- [BREAKING] MISSING_FUNCTION at export/interface:demo:closed-loop/calculator/function/subtract
  The supplying party does not provide a required function. Action: Restore the required contract or migrate the dependent party explicitly.

## Changes

- MODIFIED at export/interface:demo:closed-loop/calculator
- FUNCTION_ADDED at export/interface:demo:closed-loop/calculator/function/subtract

