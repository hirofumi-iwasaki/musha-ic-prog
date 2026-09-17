# SPDX-License-Identifier: GPL-3.0-or-later
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [ValidateSet('x64', 'arm64')] [string]$Architecture,
  [Parameter(Mandatory = $true)] [string]$FlutterRoot
)

$ErrorActionPreference = 'Stop'
$expectedRevision = '9584c6713b324636289d067944a46fd6b49df14b'
$hostArchitecture = $env:PROCESSOR_ARCHITECTURE.ToLowerInvariant()
if (($Architecture -eq 'arm64' -and $hostArchitecture -ne 'arm64') -or ($Architecture -eq 'x64' -and $hostArchitecture -ne 'amd64')) { throw "Runner architecture is $hostArchitecture; expected native $Architecture." }
git clone --depth 1 --branch 3.47.4 https://github.com/flutter/flutter.git $FlutterRoot
$revision = (git -C $FlutterRoot rev-parse HEAD).Trim()
if ($revision -ne $expectedRevision) { throw "Flutter revision $revision does not match $expectedRevision." }
$flutter = Join-Path $FlutterRoot 'bin\flutter.bat'
& $flutter --version
if ($LASTEXITCODE -ne 0) { throw 'Flutter bootstrap failed.' }
$dart = Join-Path $FlutterRoot 'bin\cache\dart-sdk\bin\dart.exe'
$bytes = [IO.File]::ReadAllBytes($dart); $offset = [BitConverter]::ToInt32($bytes, 0x3c); $machine = [BitConverter]::ToUInt16($bytes, $offset + 4)
$expectedMachine = if ($Architecture -eq 'arm64') { 0xaa64 } else { 0x8664 }
if ($machine -ne $expectedMachine) { throw ('Dart PE machine is 0x{0:X4}; expected 0x{1:X4}.' -f $machine, $expectedMachine) }
if (-not (Get-Command make.exe -ErrorAction SilentlyContinue)) { choco install make --no-progress -y; if ($LASTEXITCODE -ne 0) { throw 'GNU make installation failed.' } }
if (-not $env:GITHUB_PATH) { throw 'GITHUB_PATH is required in CI.' }
(Join-Path $FlutterRoot 'bin') | Out-File -FilePath $env:GITHUB_PATH -Encoding utf8 -Append
