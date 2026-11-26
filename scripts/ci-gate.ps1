param(
  [Parameter(Mandatory=$true)][string]$Baseline,
  [Parameter(Mandatory=$true)][string]$New,
  [ValidateSet('provider-upgrade','consumer-upgrade')][string]$Direction='provider-upgrade',
  [string]$DependencyMap,
  [string]$Out
)
$PSNativeCommandUseErrorActionPreference = $false
$root = Split-Path $PSScriptRoot -Parent
$arguments = @("$root\witprobe.mjs",'regression','run','--baseline',$Baseline,'--new',$New,'--direction',$Direction)
if ($Out) { $arguments += @('--out',$Out) }
if ($DependencyMap) { $arguments += @('--dependency-map',$DependencyMap) }
& node @arguments
exit $LASTEXITCODE
