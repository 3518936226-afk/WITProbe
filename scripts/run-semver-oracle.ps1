param(
  [Parameter(Mandatory=$true)][string]$WasmTools,
  [Parameter(Mandatory=$true)][string]$EvidenceDir
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$root = Split-Path $PSScriptRoot -Parent
$EvidenceDir = [IO.Path]::GetFullPath($EvidenceDir)
if ([IO.Path]::GetPathRoot($EvidenceDir) -ine 'D:\') { throw 'Evidence must remain on D: for this workspace.' }
New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null
$rows = [Collections.Generic.List[object]]::new()
Push-Location $root
try {
  $cases = @(
    @('export-added','fixtures/oracle-directions','baseline','more-exports',1),
    @('export-removed','fixtures/oracle-directions','more-exports','baseline',0),
    @('import-added','fixtures/oracle-directions','baseline','more-imports',0),
    @('import-removed','fixtures/oracle-directions','more-imports','baseline',1),
    @('signature-forward','fixtures/semver','demo:calculator/calculator-world@1.0.0','demo:calculator/calculator-world@2.0.0',1),
    @('signature-reverse','fixtures/semver','demo:calculator/calculator-world@2.0.0','demo:calculator/calculator-world@1.0.0',1)
  )
  foreach ($case in $cases) {
    & $WasmTools component semver-check $case[1] --prev $case[2] --new $case[3] 1> "$EvidenceDir/semver-$($case[0]).stdout.txt" 2> "$EvidenceDir/semver-$($case[0]).stderr.txt"
    $actual = $LASTEXITCODE
    $rows.Add([pscustomobject]@{case=$case[0];prev=$case[2];new=$case[3];actual_exit=$actual;expected_exit=$case[4]})
    if ($actual -ne $case[4]) { throw "Unexpected semver-check result for $($case[0]): $actual" }
  }
} finally {
  ConvertTo-Json -InputObject @($rows.ToArray()) -Depth 5 | Set-Content "$EvidenceDir/semver-oracle-results.json" -Encoding utf8
  Pop-Location
}
[pscustomobject]@{total=$rows.Count;passed=$rows.Count;results=$rows.ToArray()}
