param([switch]$SkipMutations,[string]$RealCorpusPath)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$root = $PSScriptRoot
. "$root\scripts\environment.ps1"
$toolchain = Get-WitprobeToolchain -Root $root
$pin = Get-Content -LiteralPath "$root\toolchain.lock.json" -Raw | ConvertFrom-Json
$runId = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8)
$out = "$root\evidence\product-runs\$runId"
New-Item -ItemType Directory -Path $out -Force | Out-Null
$names = @('MOON_HOME','PATH','TEMP','TMP','TMPDIR','MOON_DEP_CACHE','MOON_BUILD_CACHE','PYTHONDONTWRITEBYTECODE')
$before = @{}
foreach ($name in $names) { $before[$name] = [Environment]::GetEnvironmentVariable($name,'Process') }
$summary = [ordered]@{status='RUNNING';directory=$out;stages=[Collections.Generic.List[object]]::new();remote_ci='NOT_RUN';native='NOT_RUN'}
Push-Location $root
try {
  & "$root\run-phase1.ps1" -EvidenceDir "$out\parser" -NoLatestPointer *> "$out\parser-run.txt"
  if ($LASTEXITCODE -ne 0) { throw 'Parser checks failed.' }
  $summary.stages.Add(@{stage='parser';status='PASS'})
  $env:MOON_HOME = $toolchain
  $env:PATH = "$($toolchain)\bin;$env:PATH"
  $env:TEMP = "$root\work\tmp"
  $env:TMP = $env:TEMP
  $env:TMPDIR = $env:TEMP
  $env:MOON_DEP_CACHE = "$root\work\cache\deps"
  $env:MOON_BUILD_CACHE = "$root\work\cache\build"
  $env:PYTHONDONTWRITEBYTECODE = '1'
  & moon fmt src src/main src/contract src/analyzer src/cli --check *> "$out\format.txt"
  if ($LASTEXITCODE -ne 0) { throw 'Project formatting failed.' }
  & moon test --target js -p local/witprobe/analyzer *> "$out\analysis-tests.txt"
  if ($LASTEXITCODE -ne 0) { throw 'Analysis tests failed.' }
  $summary.stages.Add(@{stage='analysis';status='PASS'})
  & node scripts/test-product.mjs "$out\integration" *> "$out\integration-run.txt"
  if ($LASTEXITCODE -ne 0) { throw 'Product integration tests failed.' }
  $summary.stages.Add(@{stage='integration';status='PASS'})
  & node scripts/test-value-types.mjs "$out\value-types" *> "$out\value-types-run.txt"
  if ($LASTEXITCODE -ne 0) { throw 'Value-type/reference/report tests failed.' }
  $summary.stages.Add(@{stage='value-types';status='PASS'})
  & node scripts/test-resources.mjs "$out\resources" *> "$out\resources-run.txt"
  if ($LASTEXITCODE -ne 0) { throw 'Resource/ownership/mapping checks failed.' }
  $summary.stages.Add(@{stage='resources';status='PASS'})
  if ($RealCorpusPath) {
    & node scripts/test-real-projects.mjs $RealCorpusPath "$out\real-projects" *> "$out\real-projects-run.txt"
    if ($LASTEXITCODE -ne 0) { throw 'Real-project checks failed.' }
    $summary.stages.Add(@{stage='real-projects';status='PASS'})
    & node scripts/test-real-resources.mjs $RealCorpusPath "$out\real-resources" *> "$out\real-resources-run.txt"
    if ($LASTEXITCODE -ne 0) { throw 'Real WASI CLI resource break checks failed.' }
    $summary.stages.Add(@{stage='real-resources';status='PASS'})
  } else { $summary.stages.Add(@{stage='real-projects';status='SKIPPED';reason='Supply -RealCorpusPath after fetching the pinned external corpus.'}) }
  if (!$SkipMutations) {
    & node scripts/test-mutations.mjs "$out\mutations" *> "$out\mutations-run.txt"
    if ($LASTEXITCODE -ne 0) { throw 'Mutation tests failed.' }
    $summary.stages.Add(@{stage='mutations';status='PASS'})
  } else { $summary.stages.Add(@{stage='mutations';status='SKIPPED'}) }
  $summary.status = 'PASS'
} catch {
  $summary.status = 'FAIL'
  $summary.error = $_.Exception.Message
  throw
} finally {
  $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath "$out\summary.json" -Encoding utf8
  @{status=$summary.status;summary="$out\summary.json"} | ConvertTo-Json | Set-Content -LiteralPath "$root\evidence\latest-product-run.json" -Encoding utf8
  Pop-Location
  foreach ($name in $names) {
    if ($null -eq $before[$name]) { Remove-Item -LiteralPath "Env:\$name" -ErrorAction SilentlyContinue }
    else { [Environment]::SetEnvironmentVariable($name,$before[$name],'Process') }
  }
}
"Validation PASS: $out"
exit 0
