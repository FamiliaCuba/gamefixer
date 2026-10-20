$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$stage = Join-Path $env:TEMP 'gamefixer-stage'
$zip = Join-Path $env:TEMP 'gamefixer-payload.zip'
$outDir = Join-Path $root 'dist'
$out = Join-Path $outDir 'GameFixer.exe'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage | Out-Null
Copy-Item (Join-Path $root 'GameFixer.ps1') $stage
Copy-Item (Join-Path $root 'version.txt') $stage
Copy-Item (Join-Path $root 'LICENSE') $stage
Copy-Item (Join-Path $root 'modules') (Join-Path $stage 'modules') -Recurse
Copy-Item (Join-Path $root 'plugins') (Join-Path $stage 'plugins') -Recurse
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$net = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$wpf = Join-Path $net 'WPF'
$manifest = Join-Path $PSScriptRoot 'app.manifest'
$icon = Join-Path $PSScriptRoot 'GameFixer.ico'
$src = Join-Path $PSScriptRoot 'GameFixerUi.cs'
& $csc /nologo /optimize /target:winexe `
  /r:System.dll `
  "/r:$net\System.Xaml.dll" `
  "/r:$wpf\WindowsBase.dll" `
  "/r:$wpf\PresentationCore.dll" `
  "/r:$wpf\PresentationFramework.dll" `
  "/win32manifest:$manifest" `
  "/win32icon:$icon" `
  "/resource:$zip,GF.payload" `
  "/out:$out" `
  $src
if ($LASTEXITCODE -ne 0) { throw "csc failed $LASTEXITCODE" }
Write-Host "OK $out"
