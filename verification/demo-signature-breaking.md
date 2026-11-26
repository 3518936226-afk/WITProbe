# WITProbe compatibility report

Status: BREAKING
Direction: provider-upgrade
Actual provider: new
Expected contract/environment: old
Scope: structural; root package versions are mapped explicitly; this is not a runtime linking proof.
Rules: scalar-sync-v1

## Findings

- [BREAKING] TYPE_CHANGED at export/interface:demo:closed-loop/calculator/function/add/result
  Required type u32 is supplied as string. Action: Restore the required contract or migrate the dependent party explicitly.
- [BREAKING] TYPE_CHANGED at export/interface:demo:closed-loop/calculator/function/add/param/0
  Required type u32 is supplied as string. Action: Restore the required contract or migrate the dependent party explicitly.
- [BREAKING] TYPE_CHANGED at export/interface:demo:closed-loop/calculator/function/add/param/1
  Required type u32 is supplied as string. Action: Restore the required contract or migrate the dependent party explicitly.

## Changes

- MODIFIED at export/interface:demo:closed-loop/calculator
- FUNCTION_MODIFIED at export/interface:demo:closed-loop/calculator/function/add

