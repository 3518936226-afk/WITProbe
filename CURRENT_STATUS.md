# WITProbe 0.2.0 verification status

Recorded 2026-11-26 from the updated owning project, with a freshly downloaded and hash-verified external corpus.

| Suite | Result |
|---|---|
| MoonBit analysis | 33/33 |
| Product integration | 32/32, including 8 official direction comparisons |
| Value types and report completeness | 60/60, including 38 additional official comparisons |
| Real-project checks | 27/27 expected outcomes; this includes deliberately retained UNKNOWN |
| Mutation detection | 3/3 caught; reversed direction 8 failures, ignored type changes 8, swallowed UNKNOWN 6 |
| Parser integration / upstream | 13/13 and 113/113, recorded separately |

## Real-project results

Official WASI Random v0.2.0 → v0.2.1, World imports: COMPATIBLE in both directions, no findings. The earlier scalar-only implementation returned UNKNOWN. Controlled List and Tuple payload changes in separate real-source copies are BREAKING in both directions, matching the fixed official tool. These injected changes are not upstream releases or upstream bugs.

Official WASI CLI v0.2.0 → v0.2.1, World command: still UNKNOWN in both directions. A provider-upgrade report has 579 findings: 374 resource, 188 resource/accessor, 17 unmapped dependency version findings. Common value containers no longer produce UNSUPPORTED_COMPOSITE in this case. The reference tool accepts the release pair, while WITProbe intentionally has narrower resource/identity rules.

For that CLI case, default JSON is **19,944 bytes**; current full JSON is **1,305,784 bytes**. The previous default was 1,510,227 bytes. Counts remain exact, previews are explicitly truncated, and --detail full retains complete findings, definitions and IR.

Real baselines remain byte-for-byte unchanged after regression. The actual local gate allows the Random case with exit 0 and blocks the CLI UNKNOWN with exit 3. A real scalar-sync-v1 baseline is rejected with BASELINE_RULE_VERSION_CHANGED / 2 rather than silently migrated.

## Evidence and remaining limits

[Versioned results](verification/v0.2.0/results.json), [test log](verification/v0.2.0/validation-log.txt), [real-project results](verification/v0.2.0/real-projects-summary.json), [real type-break evidence](verification/v0.2.0/real-type-breaks.json), [CLI summary](verification/v0.2.0/cli-summary.md).

Supported: synchronous scalar/alias and common value-type structural equality. Resources, accessors, async, external identities, additional container proposals and unmapped dependency versions remain conservative UNKNOWN. Native, remote GitHub Actions, arbitrary-platform installation and real business-component ABI/runtime interoperability are NOT_RUN / unverified.

Older plans and verification files describe earlier versions. Current reproduction commands are in README.md. Test runs use the existing pinned MoonBit toolchain; this was not a new-machine installation test.
