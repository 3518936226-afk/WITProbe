$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$root = Split-Path $PSScriptRoot -Parent
$runId = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8)
$out = "$root\evidence\demos\$runId"
New-Item -ItemType Directory -Path $out -Force | Out-Null
$rows = [Collections.Generic.List[object]]::new()
$baseline = "$out\baseline"
try {
  & node "$root\witprobe.mjs" baseline create --wit "$root\fixtures\vertical\base" --world calculator-world --out $baseline 1> "$out\baseline-created.json" 2> "$out\baseline.stderr.txt"
  if ($LASTEXITCODE -ne 0) { throw 'Baseline creation failed.' }
  foreach ($case in @(
    @('provider-added','added','provider-upgrade',0,'COMPATIBLE'),
    @('consumer-added','added','consumer-upgrade',1,'BREAKING'),
    @('signature-breaking','breaking','provider-upgrade',1,'BREAKING'),
    @('public-unused-record','unknown','provider-upgrade',3,'UNKNOWN'),
    @('comment-only','comment-only','provider-upgrade',0,'COMPATIBLE')
  )) {
    & node "$root\witprobe.mjs" regression run --baseline $baseline --new "$root\fixtures\vertical\$($case[1])" --direction $case[2] --out "$out\$($case[0]).json"
    $actual = $LASTEXITCODE
    $report = Get-Content -LiteralPath "$out\$($case[0]).json" -Raw | ConvertFrom-Json
    $rows.Add([pscustomobject]@{case=$case[0];status=$report.status;exit_code=$actual;expected_exit=$case[3];expected_status=$case[4]})
    if ($actual -ne $case[3] -or $report.status -ne $case[4]) { throw "Unexpected demo result: $($case[0])" }
    Set-Content -LiteralPath "$out\$($case[0]).md" -Value $report.markdown -Encoding utf8
  }
  & "$root\scripts\ci-gate.ps1" -Baseline $baseline -New "$root\fixtures\vertical\breaking" -Out "$out\ci-gate.json"
  if ($LASTEXITCODE -ne 1) { throw 'The local CI gate did not reject the breaking change with exit 1.' }
  $summary = @{status='PASS';cases=$rows.ToArray();local_ci_gate='BLOCKED_AS_EXPECTED';remote_ci='NOT_RUN';baseline=$baseline}
} catch {
  $summary = @{status='FAIL';cases=$rows.ToArray();error=$_.Exception.Message;remote_ci='NOT_RUN'}
  throw
} finally {
  $summary | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath "$out\summary.json" -Encoding utf8
}
@{status='PASS';directory=$out;summary="$out\summary.json"} | ConvertTo-Json | Set-Content -LiteralPath "$root\evidence\latest-demo.json" -Encoding utf8
"Demo PASS. Reports: $out"
exit 0
