param([string]$ToolsRoot,[string]$DownloadCache)
$ErrorActionPreference='Stop'
$PSNativeCommandUseErrorActionPreference=$false
$root=Split-Path $PSScriptRoot -Parent
if(!$ToolsRoot){$ToolsRoot=Join-Path $root 'work\ci\tools'}
if(!$DownloadCache){$DownloadCache=Join-Path $root 'work\ci\downloads'}
foreach($directory in @($root,$ToolsRoot,$DownloadCache)){
  if([IO.Path]::GetPathRoot([IO.Path]::GetFullPath($directory)) -ine 'D:\'){throw 'Bootstrap outputs and project must be on D:.'}
}
$lock=Get-Content -LiteralPath "$root\ci-tools.lock.json" -Raw | ConvertFrom-Json
$pin=Get-Content -LiteralPath "$root\toolchain.lock.json" -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Force -Path $ToolsRoot,$DownloadCache,"$root\work\tmp" | Out-Null
$env:TEMP="$root\work\tmp";$env:TMP=$env:TEMP;$env:TMPDIR=$env:TEMP
$env:PYTHONDONTWRITEBYTECODE='1'
function Get-VerifiedArchive([string]$Name,$Asset){
  $archive=Join-Path $DownloadCache "$Name.zip"
  if(!(Test-Path -LiteralPath $archive)){
    $part="$archive.part"
    Write-Output "Downloading pinned $Name archive..." | Out-Host
    & curl.exe --fail --location --silent --show-error --retry 2 --connect-timeout 30 --max-time 300 --output $part $Asset.url
    if($LASTEXITCODE -ne 0){throw "$Name download failed; partial file retained on D:."}
    if((Get-FileHash -LiteralPath $part -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Asset.sha256){throw "$Name archive changed upstream; review and repin it explicitly. No changed binary is executed."}
    Move-Item -LiteralPath $part -Destination $archive
  }
  if((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Asset.sha256){throw "Cached $Name archive hash mismatch."}
  return $archive
}
$archives=@{}
foreach($name in @('moon','core','node','python')){$archives[$name]=Get-VerifiedArchive $name $lock.$name}
$moonHome=Join-Path $ToolsRoot 'moon'
$nodeRoot=Join-Path $ToolsRoot 'node'
$pythonRoot=Join-Path $ToolsRoot 'python'
foreach($directory in @($moonHome,$nodeRoot,$pythonRoot)){if(Test-Path -LiteralPath $directory){throw "Choose fresh tool directories; preserved $directory"}}
Expand-Archive -LiteralPath $archives.moon -DestinationPath $moonHome
New-Item -ItemType Directory -Force -Path "$moonHome\lib" | Out-Null
Expand-Archive -LiteralPath $archives.core -DestinationPath "$moonHome\lib"
Expand-Archive -LiteralPath $archives.node -DestinationPath $nodeRoot
Expand-Archive -LiteralPath $archives.python -DestinationPath $pythonRoot
$nodeHome=Join-Path $nodeRoot 'node-v24.20.0-win-x64'
$env:MOON_HOME=$moonHome
$env:WITPROBE_MOON_HOME=$moonHome
$env:PATH="$moonHome\bin;$nodeHome;$pythonRoot;$env:PATH"
$env:MOON_DEP_CACHE="$root\work\cache\deps"
$env:MOON_BUILD_CACHE="$root\work\cache\build"
$versions=& "$moonHome\bin\moon.exe" version --all
if($LASTEXITCODE -ne 0 -or !$versions[0].StartsWith("moon $($pin.moon) ") -or !$versions[1].StartsWith("moonc $($pin.moonc) ")){throw 'Pinned MoonBit archive does not match the compiler lock.'}
if((& "$nodeHome\node.exe" --version) -ne $pin.node){throw 'Node version mismatch.'}
if((& "$pythonRoot\python.exe" --version) -ne $pin.python){throw 'Python version mismatch.'}
$result=[ordered]@{moon_home=$moonHome;node_home=$nodeHome;python_home=$pythonRoot;versions=$versions;archive_pins=$lock}
$result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath "$root\work\ci-toolchain.json" -Encoding utf8
if($env:GITHUB_ENV){
  @("MOON_HOME=$moonHome","WITPROBE_MOON_HOME=$moonHome","TEMP=$env:TEMP","TMP=$env:TEMP","TMPDIR=$env:TEMP","PYTHONDONTWRITEBYTECODE=1","MOON_DEP_CACHE=$env:MOON_DEP_CACHE","MOON_BUILD_CACHE=$env:MOON_BUILD_CACHE") | Add-Content -LiteralPath $env:GITHUB_ENV -Encoding utf8
  @("$moonHome\bin",$nodeHome,$pythonRoot) | Add-Content -LiteralPath $env:GITHUB_PATH -Encoding utf8
}
Write-Output "Verified fresh MoonBit, Node and Python tools on D:; manifest: $root\work\ci-toolchain.json"
