param([Parameter(Mandatory=$true)][string]$Toolchain)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$root = Split-Path $PSScriptRoot -Parent
$Toolchain = [IO.Path]::GetFullPath($Toolchain)
if ([IO.Path]::GetPathRoot($root) -ine 'D:\' -or [IO.Path]::GetPathRoot($Toolchain) -ine 'D:\') { throw 'This Windows prototype keeps projects and configurable MoonBit home on D:.' }
$moon = Join-Path $Toolchain 'bin\moon.exe'
if (!(Test-Path -LiteralPath $moon)) { throw 'Supply an existing MoonBit installation; this script does not install MoonBit or MSVC.' }
$pin = Get-Content -LiteralPath "$root\toolchain.lock.json" -Raw | ConvertFrom-Json
$versionLines = & $moon version --all
if ($LASTEXITCODE -ne 0 -or !$versionLines[0].StartsWith("moon $($pin.moon) ") -or !$versionLines[1].StartsWith("moonc $($pin.moonc) ")) { throw 'MoonBit does not match the pinned version.' }
$names = @('MOON_HOME','PATH','TEMP','TMP','TMPDIR','MOON_DEP_CACHE','MOON_BUILD_CACHE','GIT_TERMINAL_PROMPT')
$before = @{}
foreach ($name in $names) { $before[$name] = [Environment]::GetEnvironmentVariable($name,'Process') }
New-Item -ItemType Directory -Force -Path "$root\work\tmp","$root\work\downloads","$root\work\vendor","$root\work\tools" | Out-Null
Push-Location $root
try {
  $env:MOON_HOME = $Toolchain
  $env:PATH = "$Toolchain\bin;$env:PATH"
  $env:TEMP = "$root\work\tmp"
  $env:TMP = $env:TEMP
  $env:TMPDIR = $env:TEMP
  $env:MOON_DEP_CACHE = "$root\work\cache\deps"
  $env:MOON_BUILD_CACHE = "$root\work\cache\build"
  $env:GIT_TERMINAL_PROMPT = '0'
  $parser = "$root\work\vendor\wit"
  if (!(Test-Path -LiteralPath $parser)) {
    & git -c credential.helper= clone --config core.autocrlf=false --no-checkout $pin.wit.repository $parser
    if ($LASTEXITCODE) { throw 'Parser clone failed.' }
    & git -C $parser checkout --detach $pin.wit.commit
    if ($LASTEXITCODE) { throw 'Pinned parser checkout failed.' }
  }
  $commit = & git -C $parser rev-parse HEAD
  $dirty = & git -C $parser diff --exit-code --no-ext-diff --no-textconv HEAD --
  $diffExit = $LASTEXITCODE
  $untracked = & git -C $parser ls-files --others --exclude-standard
  if ($diffExit -ne 0 -or $LASTEXITCODE -ne 0 -or $commit -ne $pin.wit.commit -or $dirty -or $untracked) { throw 'Existing parser is not a clean pinned checkout; nothing has been reset.' }
  if (!(Test-Path -LiteralPath "$Toolchain\lib\core\_build\js\release\bundle\bigint\bigint.mi")) {
    & $moon -C "$Toolchain\lib\core" bundle --target js
    if ($LASTEXITCODE) { throw 'JS standard library preparation failed.' }
  }
  if (!(Test-Path -LiteralPath "$Toolchain\registry\index")) {
    & $moon update
    if ($LASTEXITCODE) { throw 'Registry preparation failed.' }
  }
  $toolsDirectory = "$root\work\tools\wasm-tools-$($pin.wasm_tools.version)-x86_64-windows"
  $toolsExe = Join-Path $toolsDirectory 'wasm-tools.exe'
  if (!(Test-Path -LiteralPath $toolsExe)) {
    $archive = "$root\work\downloads\wasm-tools-$($pin.wasm_tools.version)-x86_64-windows.zip"
    if (!(Test-Path -LiteralPath $archive)) { Invoke-WebRequest -Uri $pin.wasm_tools.asset_url -OutFile $archive }
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $pin.wasm_tools.archive_sha256) { throw 'Official tool archive hash mismatch.' }
    Expand-Archive -LiteralPath $archive -DestinationPath "$root\work\tools"
  }
  if ((Get-FileHash -LiteralPath $toolsExe -Algorithm SHA256).Hash.ToLowerInvariant() -ne $pin.wasm_tools.executable_sha256) { throw 'Official tool executable hash mismatch.' }
  @{toolchain_path=$Toolchain} | ConvertTo-Json | Set-Content -LiteralPath "$root\toolchain.local.json" -Encoding utf8
  & $moon check --target js
  if ($LASTEXITCODE) { throw 'Project dependency/type check failed.' }
  'Prepared pinned parser, reference tool and local configuration. Nothing was installed to C:.'
} finally {
  Pop-Location
  foreach ($name in $names) {
    if ($null -eq $before[$name]) { Remove-Item -LiteralPath "Env:\$name" -ErrorAction SilentlyContinue }
    else { [Environment]::SetEnvironmentVariable($name,$before[$name],'Process') }
  }
}
