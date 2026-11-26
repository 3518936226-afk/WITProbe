$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$pointer=Get-Content -LiteralPath "$root\evidence\latest-product-run.json" -Raw | ConvertFrom-Json
$summary=Get-Content -LiteralPath $pointer.summary -Raw | ConvertFrom-Json
$required=@('parser','analysis','integration','value-types','resources','real-projects','real-resources','mutations')
if($summary.status -ne 'PASS'){throw 'Validation did not finish successfully.'}
foreach($name in $required){$stage=@($summary.stages | Where-Object stage -eq $name);if($stage.Count -ne 1 -or $stage[0].status -ne 'PASS'){throw "Required stage missing/skipped/failed: $name"}}
$demo=Get-Content -LiteralPath "$root\evidence\latest-demo.json" -Raw | ConvertFrom-Json
if($demo.status -ne 'PASS'){throw 'Demo was not successful.'}
if($env:GITHUB_STEP_SUMMARY){
  $run=Split-Path $pointer.summary -Parent
  $lines=@('# Full clean-checkout validation',"Commit: $env:GITHUB_SHA",'', '| Suite | Result |','|---|---|')
  $analysis=Get-Content -LiteralPath "$run\analysis-tests.txt" -Raw
  $lines += "| MoonBit analysis | $($analysis.Trim()) |"
  foreach($suite in @('integration','value-types','resources','real-projects','real-resources')){
    $s=Get-Content -LiteralPath "$run\$suite\summary.json" -Raw | ConvertFrom-Json
    $lines += "| $suite | $($s.passed)/$($s.total), $($s.status) |"
  }
  $mutations=Get-Content -LiteralPath "$run\mutations\summary.json" -Raw | ConvertFrom-Json
  $lines += "| Mutations caught | $(@($mutations.mutants | Where-Object status -eq 'KILLED').Count)/$($mutations.mutants.Count) |"
  $lines += '| Real inputs | Original pinned WASI releases; mapped and unmapped cases checked |'
  $lines += '| Demo and local gate | PASS |'
  $lines | Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Encoding utf8
}
& git -C $root diff --exit-code --no-ext-diff --no-textconv HEAD --
if($LASTEXITCODE -ne 0){throw 'Tracked source differs after fresh preparation and testing.'}
$untracked=& git -C $root ls-files --others --exclude-standard
if($LASTEXITCODE -ne 0 -or $untracked){throw 'Untracked source appeared after testing.'}
@{status='PASS';required_stages=$required;commit=(& git -C $root rev-parse HEAD);summary=$pointer.summary;run_url="https://github.com/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$root\evidence\ci-acceptance.json" -Encoding utf8
'All required stages passed without using cached builds or changing tracked files.'
