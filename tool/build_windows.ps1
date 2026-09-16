# SPDX-License-Identifier: GPL-3.0-or-later
[CmdletBinding()]
param(
  [ValidateSet('x64', 'arm64')] [string]$Architecture,
  [string]$FlutterBin
)

$ErrorActionPreference = 'Stop'
$projectDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$nativeSource = Join-Path $projectDir '.tooling\native-src\minipro-cae74c0607077d6260b24995f5e4c0d0b66a6a2e.tar.gz'
$libusbSource = Join-Path $projectDir '.tooling\native-src\libusb-1.0.29.tar.bz2'
$zlibSource = Join-Path $projectDir '.tooling\native-src\zlib-1.3.2.tar.gz'
$hostArchitecture = $env:PROCESSOR_ARCHITECTURE.ToLowerInvariant()
$native = if ($hostArchitecture -eq 'arm64') { 'arm64' } elseif ($hostArchitecture -eq 'amd64') { 'x64' } else { throw "Unsupported Windows host architecture: $hostArchitecture" }
if (-not $Architecture) { $Architecture = $native }
if ($Architecture -ne $native) { throw "Native Windows host required (host=$native target=$Architecture)." }
if (-not $FlutterBin) { $FlutterBin = Join-Path $projectDir '.tooling\flutter\bin\flutter.bat' }
if (-not (Test-Path $FlutterBin)) { throw "Pinned Flutter SDK is required: $FlutterBin" }
$dart = Join-Path (Split-Path -Parent $FlutterBin) 'dart.bat'
if (-not (Test-Path $dart)) { throw "Missing Dart SDK beside Flutter: $dart" }

Set-Location $projectDir
& (Join-Path $projectDir 'tool\build_native_windows.ps1') -Architecture $Architecture
if ($LASTEXITCODE -ne 0) { throw 'Native Windows payload build failed.' }
& $FlutterBin pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }
& $FlutterBin build windows --release
if ($LASTEXITCODE -ne 0) { throw 'flutter build windows failed.' }
$bundle = Join-Path $projectDir "build\windows\$Architecture\runner\Release"
$app = Join-Path $bundle 'mushagaeshi_ic_programmer.exe'
if (-not (Test-Path $app)) { throw "Missing complete Windows bundle: $bundle" }
$nativePrefix = Join-Path $projectDir ".tooling\native-prefix\windows-$Architecture"
$payloads = @(
  (Join-Path $nativePrefix 'bin\minipro.exe'), (Join-Path $nativePrefix 'bin\tl866_probe.exe'), (Join-Path $nativePrefix 'bin\libusb-1.0.dll'),
  (Join-Path $nativePrefix 'resources\minipro\infoic.xml'), (Join-Path $nativePrefix 'resources\minipro\logicic.xml'),
  (Join-Path $nativePrefix 'BUILD-MANIFEST.txt'))
foreach ($payload in $payloads) { if (-not (Test-Path $payload)) { throw "Missing native payload: $payload" } }
$packageNative = Join-Path $bundle 'native'; $packageResources = Join-Path $bundle 'resources\minipro'
New-Item -ItemType Directory -Force -Path $packageNative, $packageResources | Out-Null
Copy-Item (Join-Path $nativePrefix 'bin\*.exe'), (Join-Path $nativePrefix 'bin\*.dll') $packageNative -Force
Copy-Item (Join-Path $nativePrefix 'resources\minipro\*') $packageResources -Force
Copy-Item (Join-Path $projectDir 'native\windows\README.md') (Join-Path $packageResources 'WINDOWS_USB_SETUP.md') -Force
Copy-Item (Join-Path $nativePrefix 'BUILD-MANIFEST.txt') (Join-Path $packageResources 'BUILD-MANIFEST.txt') -Force
$miniproSmoke = Join-Path $packageNative 'minipro.exe'
$miniproOutput = & $miniproSmoke --help 2>&1
if ($LASTEXITCODE -ne 1 -or (($miniproOutput -join "`n") -notmatch 'Usage:')) {
  throw 'Packaged MiniPro offline help smoke check failed.'
}
$connectionOutput = & $miniproSmoke -k 2>&1
if ($env:GITHUB_ACTIONS -and ($LASTEXITCODE -eq 0 -or (($connectionOutput -join "`n") -notmatch 'No programmer found\.'))) {
  throw 'CI MiniPro libusb enumeration smoke check did not report the expected absent programmer.'
}
# Exercise UTF-16 command-line -> UTF-8 -> UTF-16 file access without USB I/O.
$unicodeDatabase = Join-Path ([IO.Path]::GetTempPath()) ('musha 日本語 path ' + [guid]::NewGuid().ToString('N'))
try {
  New-Item -ItemType Directory -Path $unicodeDatabase | Out-Null
  Copy-Item (Join-Path $packageResources 'infoic.xml'), (Join-Path $packageResources 'logicic.xml') $unicodeDatabase
  $lookup = & $miniproSmoke --infoic (Join-Path $unicodeDatabase 'infoic.xml') --logicic (Join-Path $unicodeDatabase 'logicic.xml') -q tl866a -L 27C512 2>&1
  if ($LASTEXITCODE -ne 0 -or (($lookup -join "`n") -notmatch '27C512')) {
    throw 'Packaged MiniPro Unicode database lookup failed.'
  }
} finally { if (Test-Path $unicodeDatabase) { Remove-Item -Recurse -Force $unicodeDatabase } }
$probeSmoke = Join-Path $packageNative 'tl866_probe.exe'
$probeJson = & $probeSmoke
if ($LASTEXITCODE -ne 0) { throw 'Packaged SetupAPI probe smoke check failed.' }
try { $probeResult = $probeJson | ConvertFrom-Json -ErrorAction Stop } catch { throw 'Packaged SetupAPI probe did not emit valid JSON.' }
if ($null -eq $probeResult.PSObject.Properties['count'] -or $null -eq $probeResult.PSObject.Properties['devices']) {
  throw 'Packaged SetupAPI probe JSON is missing count or devices.'
}

$dumpbin = Get-Command dumpbin.exe -ErrorAction SilentlyContinue
if (-not $dumpbin) {
  $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
  if (Test-Path $vswhere) {
    $installation = (& $vswhere -latest -products * -property installationPath | Select-Object -First 1).Trim()
    if ($installation) { $dumpbin = Get-ChildItem (Join-Path $installation 'VC\Tools\MSVC') -Filter dumpbin.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 }
  }
}
if (-not $dumpbin) { throw 'Visual Studio dumpbin.exe is required to inspect helper DLL imports.' }
$dumpbinPath = if ($dumpbin -is [IO.FileInfo]) { $dumpbin.FullName } else { $dumpbin.Source }
function Get-DumpbinImports([string]$Path) {
  $imports = (& $dumpbinPath /DEPENDENTS $Path) -join "`n"
  if ($LASTEXITCODE -ne 0) { throw "dumpbin dependency inspection failed: $Path" }
  return $imports
}
$referencedDlls = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
Get-ChildItem $bundle -File -Recurse | Where-Object { $_.Extension -in '.exe', '.dll' } | ForEach-Object {
  $imports = Get-DumpbinImports $_.FullName
  foreach ($match in [regex]::Matches($imports, '(?im)^\s*([A-Za-z0-9_.-]+\.dll)\s*$')) {
    [void]$referencedDlls.Add($match.Groups[1].Value)
  }
}
# InstallRequiredSystemLibraries can add an x64 CRT companion on ARM64. Keep
# only CRT files referenced by at least one packaged PE image.
Get-ChildItem $bundle -File | Where-Object {
  $_.Name -match '^(?:MSVCP|VCRUNTIME|CONCRT)\d+(?:_\d+)?\.dll$' -and
  -not $referencedDlls.Contains($_.Name)
} | ForEach-Object {
  Write-Host "Omitting unreferenced CRT companion: $($_.Name)"
  Remove-Item -LiteralPath $_.FullName -Force
}
$expectedMachine = if ($Architecture -eq 'arm64') { 0xaa64 } else { 0x8664 }
Get-ChildItem $bundle -File -Recurse | Where-Object { $_.Extension -in '.exe', '.dll' } | ForEach-Object {
  $bytes = [IO.File]::ReadAllBytes($_.FullName); $offset = [BitConverter]::ToInt32($bytes, 0x3c); $machine = [BitConverter]::ToUInt16($bytes, $offset + 4)
  if ($machine -ne $expectedMachine) { throw ('Unexpected PE architecture in {0}: 0x{1:X4}' -f $_.FullName, $machine) }
}
foreach ($runtimeName in @($referencedDlls | Where-Object { $_ -match '^(?:MSVCP|VCRUNTIME|CONCRT)\d+(?:_[A-Za-z0-9]+)*\.dll$' })) {
  if (-not (Test-Path (Join-Path $bundle $runtimeName))) {
    throw "Missing app-local MSVC runtime dependency: $runtimeName"
  }
}
Get-ChildItem (Join-Path $bundle 'native') -Filter *.exe | ForEach-Object {
  $imports = Get-DumpbinImports $_.FullName
  if ($imports -match '(?i)libgcc|libwinpthread|libstdc\+\+|msys-|cygwin') {
    throw "Native helper has an unsupported tool-runtime import: $($_.Name)"
  }
}
$miniproImports = Get-DumpbinImports (Join-Path $bundle 'native\minipro.exe')
if ($miniproImports -notmatch '(?im)^\s*libusb-1\.0\.dll\s*$') {
  throw 'MiniPro does not import the bundled libusb-1.0.dll transport.'
}
$dist = Join-Path $projectDir 'dist'; New-Item -ItemType Directory -Force -Path $dist | Out-Null
$stage = Join-Path $dist ('.windows-package.' + [guid]::NewGuid().ToString('N'))
try {
  $packageRoot = Join-Path $stage 'mushagaeshi_ic_programmer'; New-Item -ItemType Directory -Force -Path $stage | Out-Null
  Copy-Item -Recurse -Path $bundle -Destination $packageRoot
  $packagedApp = Join-Path $packageRoot 'mushagaeshi_ic_programmer.exe'
  $gui = $null
  try {
    $gui = Start-Process -FilePath $packagedApp -WorkingDirectory $packageRoot -PassThru
    Start-Sleep -Seconds 5
    $gui.Refresh()
    if ($gui.HasExited) { throw "Packaged GUI exited during launch smoke check: $($gui.ExitCode)" }
    if (-not $gui.CloseMainWindow()) { throw 'Packaged GUI did not accept a normal close request.' }
    if (-not $gui.WaitForExit(10000)) { throw 'Packaged GUI did not close within 10 seconds.' }
    if ($gui.ExitCode -ne 0) { throw "Packaged GUI exited with code $($gui.ExitCode)." }
  } finally {
    if ($gui -and -not $gui.HasExited) { Stop-Process -Id $gui.Id -Force }
  }
  & $dart run tool/ci/package_sources.dart $packageRoot
  if ($LASTEXITCODE -ne 0) { throw 'Matching source package creation failed.' }
  $sourceNative = Join-Path $packageRoot 'SOURCE\third_party\native-sources'; New-Item -ItemType Directory -Force -Path $sourceNative | Out-Null
  Copy-Item $nativeSource (Join-Path $sourceNative 'minipro-cae74c0607077d6260b24995f5e4c0d0b66a6a2e.tar.gz') -Force
  Copy-Item $libusbSource (Join-Path $sourceNative 'libusb-1.0.29.tar.bz2') -Force
  Copy-Item $zlibSource (Join-Path $sourceNative 'zlib-1.3.2.tar.gz') -Force
  Copy-Item (Join-Path $projectDir 'native\windows\minipro-utf8-paths.patch'), (Join-Path $projectDir 'native\windows\tl866_probe_windows.c') $sourceNative -Force
  & $dart run tool/ci/write_distribution_metadata.dart $packageRoot "windows-$Architecture" $FlutterBin
  if ($LASTEXITCODE -ne 0) { throw 'Distribution metadata generation failed.' }
  & $dart run tool/ci/write_checksums.dart $packageRoot
  if ($LASTEXITCODE -ne 0) { throw 'Checksum generation failed.' }
  $archive = Join-Path $dist "musha-ic-prog-windows-$Architecture.zip"; Remove-Item -Force -ErrorAction SilentlyContinue $archive
  Compress-Archive -Path $packageRoot -DestinationPath $archive -CompressionLevel Optimal
  Write-Host "Windows package ready: $archive"
} finally { Remove-Item -Force -Recurse -ErrorAction SilentlyContinue $stage }
