# WITProbe

**MoonBit WIT contract evolution and regression prototype.**

WITProbe compares service-provider World contracts, explains directional compatibility findings, and preserves source/IR/rule identities in regression baselines.

- MoonBit implements the IR, Diff, compatibility rules and JSON/Markdown reports.
- A Node.js host handles files, CLI arguments, SHA256 and process exit codes.
- Scalar types, scalar aliases and synchronous functions have deterministic rules.
- Public complex types, resources and async features produce actionable UNKNOWN findings.
- Native binaries, complete WIT subtyping and business-component interoperability remain unverified.

## Clone and prepare (Windows / D:)

~~~powershell
git clone https://github.com/3518936226-afk/WITProbe.git D:\VAPP\WITProbe
Set-Location D:\VAPP\WITProbe

# Use an existing MoonBit installation matching toolchain.lock.json.
.\scripts\prepare.ps1 -Toolchain 'D:\VAPP\tools\moon'
~~~

This script checks the toolchain version, fetches the exact Apache-2.0 parser revision, prepares JS dependencies, and downloads/checksums the official wasm-tools reference binary on D:. It does not install MoonBit or MSVC, change credentials, or write shell profiles.

Prerequisites for the full validation: Git, PowerShell 7, Node and Python matching the recorded versions. Machine-specific MoonBit paths are stored only in the ignored toolchain.local.json, or provided via WITPROBE_MOON_HOME. Version pins remain committed. Network access is needed for first-time setup.

## Compare

~~~powershell
node .\witprobe.mjs compare --old .\fixtures\vertical\base --new .\fixtures\vertical\added --world calculator-world --direction provider-upgrade

node .\witprobe.mjs compare --old .\fixtures\vertical\base --new .\fixtures\vertical\added --world calculator-world --direction consumer-upgrade --format markdown
~~~

The same added export is COMPATIBLE for a provider upgrade and BREAKING when an upgraded caller expects the old provider to implement it. Both inputs describe provider contracts. The report records actual_side and expected_side; it does not automatically interpret the consumer's own World.

| Result | Exit |
|---|---:|
| COMPATIBLE | 0 |
| BREAKING | 1 |
| ERROR: invalid input/configuration/tool failure | 2 |
| UNKNOWN: valid input outside proven rules | 3 |

World selection is required. Use --old-world / --new-world if their names differ. --out accepts a new D: path and refuses overwrites.

## Baselines, demo and validation

~~~powershell
.\scripts\demo.ps1
.\run-validation.ps1
~~~

The demo saves a source baseline and JSON/Markdown examples. Actual release gates should call scripts/ci-gate.ps1, which preserves the regression exit code. The demo itself returns success when all expected incompatible/unknown cases behave correctly.

Baseline creation refuses existing paths and does not write inside the input tree. Regression is read-only and checks source bytes, saved IR, parser/options and rule versions. Source hashes, normalized semantic hashes and rule-set versions are separate.

Recorded verification: 25 MoonBit analysis tests, 32 product integration cases (including eight official direction comparisons), and three intentionally broken implementations caught by the tests. Parser integration/upstream tests are reported separately. See [verification](verification/README.md) for records and [CURRENT_STATUS.md](CURRENT_STATUS.md) for limits.

Remote GitHub Actions has not run. Local CI-style gate behavior has been tested. No toolchain, dependency checkout, cache, runtime evidence directory or private local configuration is committed.

## Layout and documentation

- src/contract: independent MoonBit contract model, Diff, pure rules and reports.
- src/analyzer: pinned upstream parser adapter and public-type closure.
- src/cli: compiled MoonBit analysis process.
- witprobe.mjs: host I/O; it does not implement compatibility decisions.
- [PROJECT_PLAN_V1.2.md](PROJECT_PLAN_V1.2.md): current scope and next work.
- [RULES.md](RULES.md): result/reason protocol.
- [DEMO_GUIDE.md](DEMO_GUIDE.md): detailed examples.
- [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md): upstream sources and licenses.

Historical plans and feasibility notes are retained as history; paths to old local logs in them are historical references. Portable selected results are under verification/.

The project's own code has not been assigned an open-source license. Third-party code keeps its original licensing. This initial repository is private.
