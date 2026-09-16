# SPDX-License-Identifier: GPL-3.0-or-later
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [ValidateSet('x64', 'arm64')] [string]$Architecture,
  [string]$ToolchainRoot
)

$ErrorActionPreference = 'Stop'
$projectDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$nativeSource = Join-Path $projectDir '.tooling\native-src\minipro-cae74c0607077d6260b24995f5e4c0d0b66a6a2e.tar.gz'
$expectedSourceHash = '6363acb0b69f6038ff7a64a751bd2b4fa671debde487c83fd4c5c876c95175af'
$toolchainVersion = '20240619'
$toolchainArchive = Join-Path $projectDir ".tooling\native-src\llvm-mingw-$toolchainVersion-ucrt-x86_64.zip"
$toolchainUrl = "https://github.com/mstorsjo/llvm-mingw/releases/download/$toolchainVersion/llvm-mingw-$toolchainVersion-ucrt-x86_64.zip"
$toolchainHash = '810703594a7e3eea03385b5329c7ea3bd65f5e496b44cf1b68c17ff436d265e7'
$zlibVersion = '1.3.2'
$zlibArchive = Join-Path $projectDir ".tooling\native-src\zlib-$zlibVersion.tar.gz"
$zlibUrl = "https://zlib.net/zlib-$zlibVersion.tar.gz"
$zlibHash = 'bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16'
$triple = if ($Architecture -eq 'arm64') { 'aarch64-w64-mingw32' } else { 'x86_64-w64-mingw32' }
$prefix = Join-Path $projectDir ".tooling\native-prefix\windows-$Architecture"
$gitBash = if (Test-Path 'C:\Program Files\Git\bin\bash.exe') { 'C:\Program Files\Git\bin\bash.exe' } else { (Get-Command bash.exe -ErrorAction Stop).Source }

if (-not (Test-Path $nativeSource)) {
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $nativeSource) | Out-Null
  Invoke-WebRequest -Uri 'https://gitlab.com/DavidGriffith/minipro/-/archive/cae74c0607077d6260b24995f5e4c0d0b66a6a2e/minipro-cae74c0607077d6260b24995f5e4c0d0b66a6a2e.tar.gz' -OutFile $nativeSource
}
if ((Get-FileHash -Algorithm SHA256 $nativeSource).Hash.ToLowerInvariant() -ne $expectedSourceHash) { throw 'Pinned MiniPro archive hash mismatch.' }
if (-not $ToolchainRoot) {
  $ToolchainRoot = Join-Path $projectDir ".tooling\native-tools\llvm-mingw-$toolchainVersion-ucrt-x86_64"
}
if (-not (Test-Path (Join-Path $ToolchainRoot 'bin\clang.exe'))) {
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $toolchainArchive) | Out-Null
  if (-not (Test-Path $toolchainArchive)) { Invoke-WebRequest -Uri $toolchainUrl -OutFile $toolchainArchive }
  if ((Get-FileHash -Algorithm SHA256 $toolchainArchive).Hash.ToLowerInvariant() -ne $toolchainHash) { throw 'Pinned LLVM-MinGW archive hash mismatch.' }
  Expand-Archive -Path $toolchainArchive -DestinationPath (Split-Path -Parent $ToolchainRoot) -Force
}
$clang = Join-Path $ToolchainRoot "bin\$triple-clang.exe"
if (-not (Test-Path $clang)) { throw "LLVM-MinGW lacks $triple compiler: $clang" }
$ar = Join-Path $ToolchainRoot 'bin\llvm-ar.exe'
if (-not (Test-Path $ar)) { throw "LLVM-MinGW lacks llvm-ar: $ar" }
$make = Get-Command make.exe -ErrorAction SilentlyContinue
if (-not $make) { throw 'GNU make is required. Run tool/ci/bootstrap_flutter.ps1 first on hosted Windows.' }
$gitUsrBin = Join-Path (Split-Path -Parent (Split-Path -Parent $gitBash)) 'usr\bin'
if (Test-Path $gitUsrBin) { $env:PATH = "$gitUsrBin;$env:PATH" }
$env:SHELL = $gitBash
$env:PATH = "$(Join-Path $ToolchainRoot 'bin');$env:PATH"

$source = Join-Path $projectDir ('.tooling\minipro-windows-' + [guid]::NewGuid().ToString('N'))
$zlibSource = Join-Path ([IO.Path]::GetTempPath()) ('musha-zlib-' + [guid]::NewGuid().ToString('N'))
try {
  $scriptPosix = (& $gitBash -lc 'cygpath -u "$1"' -- (Join-Path $projectDir 'tool\materialize_minipro_sram.sh')).Trim()
  $sourcePosix = (& $gitBash -lc 'cygpath -u "$1"' -- $source).Trim()
  & $gitBash -lc '"$1" "$2"' -- $scriptPosix $sourcePosix
  if ($LASTEXITCODE -ne 0) { throw 'MiniPro SRAM overlay materialization failed. Git Bash is required.' }
  $relativeSource = '.tooling/' + (Split-Path -Leaf $source)
  & git -C $projectDir apply "--directory=$relativeSource" (Join-Path $projectDir 'native\windows\minipro-utf8-paths.patch')
  if ($LASTEXITCODE -ne 0) { throw 'MiniPro UTF-8 Windows path patch failed.' }
  if (-not (Test-Path $zlibArchive)) { Invoke-WebRequest -Uri $zlibUrl -OutFile $zlibArchive }
  if ((Get-FileHash -Algorithm SHA256 $zlibArchive).Hash.ToLowerInvariant() -ne $zlibHash) { throw 'Pinned zlib archive hash mismatch.' }
  New-Item -ItemType Directory -Path $zlibSource | Out-Null
  tar.exe -xzf $zlibArchive -C $zlibSource --strip-components=1
  if ($LASTEXITCODE -ne 0) { throw 'zlib source extraction failed.' }
  $zlibBuild = Join-Path $zlibSource 'build'; New-Item -ItemType Directory -Path $zlibBuild | Out-Null
  $zlibFiles = @('adler32.c','compress.c','crc32.c','deflate.c','gzclose.c','gzlib.c','gzread.c','gzwrite.c','inflate.c','infback.c','inffast.c','inftrees.c','trees.c','uncompr.c','zutil.c')
  foreach ($file in $zlibFiles) { & $clang -O2 -DNDEBUG -I $zlibSource -c (Join-Path $zlibSource $file) -o (Join-Path $zlibBuild ($file -replace '\.c$', '.o')); if ($LASTEXITCODE -ne 0) { throw "zlib compile failed: $file" } }
  $zlibObjects = @(Get-ChildItem $zlibBuild -Filter *.o | ForEach-Object FullName)
  & $ar rcs (Join-Path $zlibBuild 'libz.a') @zlibObjects
  if ($LASTEXITCODE -ne 0) { throw 'zlib archive creation failed.' }
  $zlibInclude = Join-Path $source 'src\zlib'; New-Item -ItemType Directory -Path $zlibInclude | Out-Null
  Copy-Item (Join-Path $zlibSource 'zlib.h'), (Join-Path $zlibSource 'zconf.h') $zlibInclude -Force
  Copy-Item (Join-Path $zlibBuild 'libz.a') (Join-Path $zlibInclude 'libz.a') -Force
  $env:OS = 'Windows_NT'
  & $make.Source -C $source 'PKG_CONFIG=/bin/true' clean
  & $make.Source -C $source 'PKG_CONFIG=/bin/true' "CC=$triple-clang" 'CFLAGS=-O2 -DNDEBUG -Isrc/zlib' 'LDFLAGS=-municode -static-libgcc -Lsrc/zlib'
  if ($LASTEXITCODE -ne 0) { throw 'MiniPro cross-build failed.' }
  New-Item -ItemType Directory -Force -Path (Join-Path $prefix 'bin'), (Join-Path $prefix 'resources\minipro') | Out-Null
  Copy-Item (Join-Path $source 'minipro.exe') (Join-Path $prefix 'bin\minipro.exe') -Force
  & $clang -O2 -DNDEBUG (Join-Path $projectDir 'native\windows\tl866_probe_windows.c') -lsetupapi -o (Join-Path $prefix 'bin\tl866_probe.exe')
  if ($LASTEXITCODE -ne 0) { throw 'Windows SetupAPI probe build failed.' }
  Copy-Item (Join-Path $source 'infoic.xml'), (Join-Path $source 'logicic.xml'), (Join-Path $source 'LICENSE'), (Join-Path $source 'README.md') (Join-Path $prefix 'resources\minipro') -Force
  $expectedMachine = if ($Architecture -eq 'arm64') { 0xaa64 } else { 0x8664 }
  Get-ChildItem (Join-Path $prefix 'bin') -Filter *.exe | ForEach-Object {
    $bytes = [IO.File]::ReadAllBytes($_.FullName); $offset = [BitConverter]::ToInt32($bytes, 0x3c); $machine = [BitConverter]::ToUInt16($bytes, $offset + 4)
    if ($machine -ne $expectedMachine) { throw ('Unexpected PE architecture in {0}: 0x{1:X4}' -f $_.Name, $machine) }
  }
  @("target_architecture=$Architecture", "minipro_commit=cae74c0607077d6260b24995f5e4c0d0b66a6a2e", "llvm_mingw_version=$toolchainVersion", "llvm_mingw_sha256=$toolchainHash", "llvm_mingw_host=x86_64", "zlib_version=$zlibVersion", "zlib_sha256=$zlibHash", "utf8_path_patch=minipro-utf8-paths.patch") | Set-Content -Encoding utf8 (Join-Path $prefix 'BUILD-MANIFEST.txt')
  Write-Host "Built native Windows $Architecture payload at $prefix"
} finally { if (Test-Path $source) { Remove-Item -Recurse -Force $source }; if (Test-Path $zlibSource) { Remove-Item -Recurse -Force $zlibSource } }
