$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$names = @('MOON_HOME','PATH','TEMP','TMP','TMPDIR','MOON_DEP_CACHE','MOON_BUILD_CACHE','PYTHONDONTWRITEBYTECODE')
$before = @{}
foreach ($n in $names) { $before[$n] = [Environment]::GetEnvironmentVariable($n,'Process') }
$oldLogs = @('evidence\integration-tests-js.txt','evidence\upstream-tests-js.txt','evidence\integration-tests-native.txt')
$oldHashes = @{}
foreach ($p in $oldLogs) { $oldHashes[$p] = (Get-FileHash -LiteralPath (Join-Path $root $p)).Hash }
& "$root\run-phase1.ps1"
if ($LASTEXITCODE -ne 0) { throw 'Positive run failed' }
foreach ($n in $names) {
  if ([Environment]::GetEnvironmentVariable($n,'Process') -cne $before[$n]) { throw "Environment changed: $n" }
}
$successPointer = Get-Content -LiteralPath "$root\evidence\latest-success.json" -Raw
$latestPointer = Get-Content -LiteralPath "$root\evidence\latest-run.json" -Raw
$positive = $successPointer | ConvertFrom-Json
$failureDir = "$root\work\runner-checks\missing-tool-$([Guid]::NewGuid().ToString('N'))"
$failed = $false
try { & "$root\run-phase1.ps1" -WasmTools "$root\work\missing-tool-for-negative-check.exe" -EvidenceDir $failureDir -NoLatestPointer } catch { $failed = $true }
if (!$failed) { throw 'Missing-tool run did not fail' }
$failure = Get-Content -LiteralPath "$failureDir\summary.json" -Raw | ConvertFrom-Json
if ($failure.status -ne 'FAIL') { throw 'Failure was not recorded' }
if ((Get-Content -LiteralPath "$root\evidence\latest-success.json" -Raw) -cne $successPointer) { throw 'Failure overwrote last success' }
$versionDir = "$root\work\runner-checks\wrong-tool-$([Guid]::NewGuid().ToString('N'))"
$wrongTool = (Get-Command node -ErrorAction Stop).Source
$versionRejected = $false
try { & "$root\run-phase1.ps1" -WasmTools $wrongTool -EvidenceDir $versionDir -NoLatestPointer } catch { $versionRejected = $true }
$versionFailure = Get-Content -LiteralPath "$versionDir\summary.json" -Raw | ConvertFrom-Json
if (!$versionRejected -or $versionFailure.status -ne 'FAIL' -or $versionFailure.error -notlike '*wasm-tools version differs*') { throw 'Wrong tool version was not rejected during preflight' }
if ((Get-Content -LiteralPath "$root\evidence\latest-run.json" -Raw) -cne $latestPointer) { throw 'Expected failures overwrote main run pointer' }
$runDir = Split-Path $positive.summary -Parent
$beforeSummaryHash = (Get-FileHash -LiteralPath $positive.summary).Hash
$rejected = $false
try { & "$root\run-phase1.ps1" -EvidenceDir $runDir } catch { $rejected = $true }
if (!$rejected -or (Get-FileHash -LiteralPath $positive.summary).Hash -ne $beforeSummaryHash) { throw 'Existing evidence was not protected' }
foreach ($p in $oldLogs) {
  if ((Get-FileHash -LiteralPath (Join-Path $root $p)).Hash -ne $oldHashes[$p]) { throw "Historical log changed: $p" }
}
foreach ($n in $names) {
  if ([Environment]::GetEnvironmentVariable($n,'Process') -cne $before[$n]) { throw "Environment changed after failure: $n" }
}
$checks = [ordered]@{
  status='PASS';successful_run=$positive.summary;expected_failure_run="$failureDir\summary.json"
  wrong_version_run="$versionDir\summary.json";wrong_tool_version_rejected=$true;main_run_pointer_preserved=$true
  environment_restored=$true;missing_tool_rejected=$true;failed_run_summary_saved=$true
  last_success_preserved=$true;existing_evidence_rejected=$true;historical_logs_preserved=$true
}
$checks | ConvertTo-Json | Set-Content -LiteralPath "$root\evidence\optimization-verification.json" -Encoding utf8
'Runner behavior: PASS (success, expected failure, evidence preservation, environment restoration).'
