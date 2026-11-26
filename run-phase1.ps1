param(
  [string]$Toolchain,
  [string]$WasmTools = "$PSScriptRoot\work\tools\wasm-tools-1.263.0-x86_64-windows\wasm-tools.exe",
  [string]$EvidenceDir,
  [switch]$NoLatestPointer
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$root = $PSScriptRoot
. "$root\scripts\environment.ps1"
$pin = Get-Content -LiteralPath "$root\toolchain.lock.json" -Raw | ConvertFrom-Json
if (!$Toolchain) { $Toolchain = Get-WitprobeToolchain -Root $root }
if (!$EvidenceDir) {
  $runId = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8)
  $EvidenceDir = "$root\evidence\runs\$runId"
}
$EvidenceDir = [IO.Path]::GetFullPath($EvidenceDir)
if ([IO.Path]::GetPathRoot($EvidenceDir) -ine 'D:\') { throw 'Evidence must remain on D: for this workspace.' }
if (Test-Path -LiteralPath $EvidenceDir) { throw 'Choose a new evidence directory; existing runs are preserved.' }
New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null
$summary = [ordered]@{
  schema_version=1;status='RUNNING';started_at=[DateTime]::UtcNow.ToString('o')
  finished_at=$null;evidence_dir=$EvidenceDir;error=$null
  stages=[Collections.Generic.List[object]]::new();tests=[ordered]@{}
  native_status='NOT_RUN: historical build failure is recorded separately; this run verifies JS only.'
}
$envNames = @('MOON_HOME','PATH','TEMP','TMP','TMPDIR','MOON_DEP_CACHE','MOON_BUILD_CACHE','PYTHONDONTWRITEBYTECODE')
$oldEnv = @{}
foreach ($name in $envNames) { $oldEnv[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }

function Invoke-CheckedTool {
  param([string]$Name,[string]$Command,[string[]]$Arguments)
  $log = Join-Path $EvidenceDir "$Name.txt"
  & $Command @Arguments *> $log
  $code = $LASTEXITCODE
  $summary.stages.Add([pscustomobject]@{name=$Name;exit_code=$code;log=$log})
  if ($code -ne 0) { throw "$Name failed (exit $code); see $log" }
}

function Read-TestCounts {
  param([string]$Name)
  $content = Get-Content -LiteralPath "$EvidenceDir/$Name.txt" -Raw
  $testSummaries = [regex]::Matches($content, 'Total tests:\s*(\d+), passed:\s*(\d+), failed:\s*(\d+)')
  if ($testSummaries.Count -ne 1) { throw "Expected exactly one test summary in $Name" }
  $m = $testSummaries[0]
  $counts = [ordered]@{total=[int]$m.Groups[1].Value;passed=[int]$m.Groups[2].Value;failed=[int]$m.Groups[3].Value}
  if ($counts.total -le 0 -or $counts.failed -ne 0 -or $counts.passed -ne $counts.total) { throw "Incomplete test execution in $Name" }
  $summary.tests[$Name] = $counts
}

Push-Location $root
try {
  $moon = "$Toolchain\bin\moon.exe"
  if (!(Test-Path -LiteralPath $moon)) { throw 'Supply an existing MoonBit toolchain with -Toolchain. Nothing will be installed.' }
  if (!(Test-Path -LiteralPath $WasmTools)) { throw 'Supply the pinned wasm-tools with -WasmTools.' }
  foreach ($command in @('git','python','node')) { Get-Command $command -ErrorAction Stop | Out-Null }
  $env:MOON_HOME = $Toolchain
  $env:PATH = "$Toolchain\bin;$env:PATH"
  $env:TEMP = "$root\work\tmp"
  $env:TMP = $env:TEMP
  $env:TMPDIR = $env:TEMP
  $env:MOON_DEP_CACHE = "$root\work\cache\deps"
  $env:MOON_BUILD_CACHE = "$root\work\cache\build"
  $env:PYTHONDONTWRITEBYTECODE = '1'
  New-Item -ItemType Directory -Force -Path $env:TEMP | Out-Null

  $commit = & git -C work/vendor/wit rev-parse HEAD
  if ($LASTEXITCODE -ne 0 -or $commit -ne $pin.wit.commit) { throw 'Parser revision differs from toolchain.lock.json.' }
  $dirty = & git -C work/vendor/wit diff --exit-code --no-ext-diff --no-textconv HEAD --
  $diffExit = $LASTEXITCODE
  $untracked = & git -C work/vendor/wit ls-files --others --exclude-standard
  if ($diffExit -ne 0 -or $LASTEXITCODE -ne 0 -or $untracked -or $dirty) { throw 'Pinned parser cannot be verified as an unmodified checkout.' }
  Invoke-CheckedTool 'toolchain-version' $moon @('version','--all')
  $versions = Get-Content -LiteralPath "$EvidenceDir/toolchain-version.txt"
  if (!$versions[0].StartsWith("moon $($pin.moon) ") -or !$versions[1].StartsWith("moonc $($pin.moonc) ")) { throw 'MoonBit version differs from toolchain.lock.json.' }
  Invoke-CheckedTool 'wasm-tools-version' $WasmTools @('--version')
  $wtVersion = Get-Content -LiteralPath "$EvidenceDir/wasm-tools-version.txt" -Raw
  if (!$wtVersion.StartsWith("wasm-tools $($pin.wasm_tools.version) ")) { throw 'wasm-tools version differs from toolchain.lock.json.' }
  $exeHash = (Get-FileHash -LiteralPath $WasmTools -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($exeHash -ne $pin.wasm_tools.executable_sha256) { throw 'wasm-tools executable hash differs from toolchain.lock.json.' }
  Invoke-CheckedTool 'node-version' 'node' @('--version')
  Invoke-CheckedTool 'python-version' 'python' @('--version')
  if ((Get-Content -LiteralPath "$EvidenceDir/node-version.txt" -Raw).Trim() -ne $pin.node) { throw 'Node version differs from toolchain.lock.json.' }
  if ((Get-Content -LiteralPath "$EvidenceDir/python-version.txt" -Raw).Trim() -ne $pin.python) { throw 'Python version differs from toolchain.lock.json.' }

  Invoke-CheckedTool 'format-check' $moon @('fmt','src','src/main','--check')
  Invoke-CheckedTool 'check-js' $moon @('check','--target','js')
  $xManifest = Get-Content -LiteralPath '.mooncakes/moonbitlang/x/moon.mod' -Raw
  if ($xManifest -notmatch ('(?m)^version\s*=\s*"' + [regex]::Escape($pin.moonbitlang_x) + '"\s*$')) { throw 'Resolved moonbitlang/x version differs from the pin.' }
  Invoke-CheckedTool 'integration-tests-js' $moon @('test','--target','js','-p','local/witprobe')
  Read-TestCounts 'integration-tests-js'
  Invoke-CheckedTool 'upstream-tests-js' $moon @('test','--target','js','-p','mizchi/wit')
  Read-TestCounts 'upstream-tests-js'
  & $moon run src/main --target js 1> "$EvidenceDir/resolved-fixtures.json" 2> "$EvidenceDir/experiment-stderr.txt"
  $runExit = $LASTEXITCODE
  $summary.stages.Add([pscustomobject]@{name='parser-experiment';exit_code=$runExit})
  if ($runExit -ne 0) { throw 'Parser experiment failed.' }

  $rows = [Collections.Generic.List[object]]::new()
  foreach ($case in @('v1','v2','dependency','invalid-duplicate')) {
    & $WasmTools component wit "fixtures/$case" --json 1> "$EvidenceDir/official-$case.json" 2> "$EvidenceDir/official-$case.stderr.txt"
    $actual = $LASTEXITCODE
    $expected = if ($case -eq 'invalid-duplicate') { 1 } else { 0 }
    $rows.Add([pscustomobject]@{case=$case;exit_code=$actual;expected_exit=$expected})
    ConvertTo-Json -InputObject @($rows.ToArray()) | Set-Content "$EvidenceDir/official-validation.json" -Encoding utf8
    if ($actual -ne $expected) { throw "Unexpected official parser exit for $case : $actual" }
  }
  $summary.tests['official-parser'] = @{total=$rows.Count;passed=$rows.Count;failed=0}
  Invoke-CheckedTool 'fixture-semantic-comparison' 'python' @('-B','scripts/compare_fixture_semantics.py','--evidence-dir',$EvidenceDir)
  $comparisons = @(Get-Content -LiteralPath "$EvidenceDir/fixture-semantic-comparison.json" -Raw | ConvertFrom-Json)
  if ($comparisons.Count -eq 0 -or @($comparisons | Where-Object status -ne 'PASS').Count -ne 0) { throw 'Semantic comparison result is incomplete.' }
  $summary.tests['semantic-comparison'] = @{total=$comparisons.Count;passed=$comparisons.Count;failed=0}
  $oracle = & "$root\scripts\run-semver-oracle.ps1" -WasmTools $WasmTools -EvidenceDir $EvidenceDir
  $summary.tests['semver-direction-probes'] = @{total=$oracle.total;passed=$oracle.passed;failed=0}
  $summary.status = 'PASS'
} catch {
  $summary.status = 'FAIL'
  $summary.error = $_.Exception.Message
  throw
} finally {
  $summary.finished_at = [DateTime]::UtcNow.ToString('o')
  $summary | ConvertTo-Json -Depth 9 | Set-Content "$EvidenceDir/summary.json" -Encoding utf8
  $pointer = @{status=$summary.status;summary="$EvidenceDir\summary.json";finished_at=$summary.finished_at}
  if (!$NoLatestPointer) {
    $pointer | ConvertTo-Json | Set-Content "$root/evidence/latest-run.json" -Encoding utf8
    if ($summary.status -eq 'PASS') { $pointer | ConvertTo-Json | Set-Content "$root/evidence/latest-success.json" -Encoding utf8 }
  }
  Pop-Location
  foreach ($name in $envNames) {
    if ($null -eq $oldEnv[$name]) {
      Remove-Item -LiteralPath "Env:\$name" -ErrorAction SilentlyContinue
    } else {
      [Environment]::SetEnvironmentVariable($name, $oldEnv[$name], 'Process')
    }
  }
}
$integration = $summary.tests['integration-tests-js']
$upstream = $summary.tests['upstream-tests-js']
"PASS: integration $($integration.passed)/$($integration.total); upstream $($upstream.passed)/$($upstream.total)."
"Summary: $EvidenceDir\summary.json"
'Native: not run; historical failure is recorded separately.'
exit 0
