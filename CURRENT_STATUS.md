# WITProbe 0.3.0 verification status

**GitHub Actions clean-checkout validation is now verified.** [Successful run #2](https://github.com/3518936226-afk/WITProbe/actions/runs/45859517167), tested commit 8333b40edad47cd01dde80f0f5c591c0d535ab0b; [CI receipt](verification/ci/github-actions-success.json), [reproduction](REPRODUCING.md). The following resource results remain recorded separately.

Recorded 2026-11-27. Rules: resource-sync-v3; Report Schema 2; IR/baseline metadata Schema 1.

| Suite | Result |
|---|---|
| MoonBit analysis | 40/40 |
| Product integration | 32/32 (8 official direction comparisons included) |
| Value types / reports | 60/60 (38 official comparisons included) |
| Resources / mapping validation | 66/66 (36 official comparisons included) |
| Real projects | 31/31 expected outcomes, including deliberately retained UNKNOWN |
| Real WASI CLI resource breaks | 9/9 (8 official comparisons included) |
| Mutations | 4/4 caught; direction 9 failures, ignored types 10, swallowed UNKNOWN 5, erased resource identity 4 |
| Parser integration / upstream | 13/13 and 113/113, counted separately |

## WASI CLI

- Original v0.2.0 and v0.2.1, World command, each compared to itself: COMPATIBLE / 0.
- Release pair without a dependency map: UNKNOWN / 3; versions are not erased automatically.
- With the explicit five-package map: COMPATIBLE / 0 in both directions, no findings, matching the fixed reference tool under the declared identity alignment.
- Partial map: UNKNOWN / 3.
- Mapped baseline regression and actual local gate: exit 0; baseline files unchanged.
- Four controlled changes in independent v0.2.1 copies alter own/borrow, nominal resource identity, a method result, and a method name. All eight directional checks are BREAKING / 1, matching official reference checks.
- A real value-sync-v2 baseline is rejected with BASELINE_RULE_VERSION_CHANGED / 2, preserving the old data.

The checked map declares clocks, filesystem, io, random and sockets from 0.2.0 to 0.2.1. Original IR and semantic hashes retain original versions. Full reports also retain the comparison projection; JSON/Markdown show the assumptions and JSON records a policy digest. Policy row order does not change the digest.

WASI Random and previous List/Tuple break experiments remain covered. Test injections are not upstream releases or upstream bugs; original source bytes are preserved.

## Evidence and limits

[Report](verification/v0.3.0/REPORT.md), [results](verification/v0.3.0/results.json), [mapped CLI](verification/v0.3.0/cli-mapped-provider-upgrade.json), [unmapped CLI](verification/v0.3.0/cli-unmapped.json), [real resource breaks](verification/v0.3.0/real-resource-breaks.json), [log](verification/v0.3.0/validation-log.txt), [mapping rules](RESOURCE_MAPPING.md).

Supported: synchronous value/resource contract structure, nominal origins and aliases, own/borrow, constructors/methods/statics, and explicit one-to-one same-package version mapping. Ambiguous/coexisting-version mappings are rejected. Async/accessor proposals, external/unresolved identities and additional container proposals remain conservative UNKNOWN.

This does not execute destructors or prove runtime lifetime safety, actual resource instance identity or business behavior. Native and real business-component interoperability remain unverified. Windows GitHub Actions passed using a fresh checkout and freshly bootstrapped pinned tools without restored build caches. Older local reports that reused an existing toolchain remain historical.

## Public delivery (2026-11-27)

The repository is public. WITProbe's own code and documentation use the MIT license; upstream license texts and notices are preserved. [Application](contest/APPLICATION.md), [PDF](contest/WITProbe-Application.pdf), [contribution and AI disclosure](contest/CONTRIBUTIONS_AND_AI.md), and [submission checklist](contest/SUBMISSION_CHECKLIST.md) are provided. Competition registration, participant identity, group membership, and the participant's own rehearsal are not certified by this repository.
