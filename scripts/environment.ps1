function Get-WitprobeToolchain {
  param([Parameter(Mandatory=$true)][string]$Root)
  if ($env:WITPROBE_MOON_HOME) { return $env:WITPROBE_MOON_HOME }
  $configPath = Join-Path $Root 'toolchain.local.json'
  if (Test-Path -LiteralPath $configPath) {
    $localConfig = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    if ($localConfig.toolchain_path) { return $localConfig.toolchain_path }
  }
  if ($env:MOON_HOME) { return $env:MOON_HOME }
  throw 'Run scripts/prepare.ps1 -Toolchain <existing D: MoonBit installation> first.'
}
