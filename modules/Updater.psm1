# ============================================================================
#  modules/Updater.psm1
#  Auto-update desde GitHub Releases
# ============================================================================

# Configuracion del repositorio
$Script:UpdaterConfig = @{
    Owner        = 'FamiliaCuba'
    Repo         = 'gamefixer'
    VersionFile  = 'version.txt'
    ApiBase      = 'https://api.github.com'
    RawBase      = 'https://raw.githubusercontent.com'
    UserAgent    = 'GameFixer-Updater/1.0'
    TimeoutSec   = 10
}

function Get-RemoteVersion {
    <#
    .SYNOPSIS
    Lee version.txt desde la rama main del repo. Devuelve string con la version o $null si falla.
    #>
    $url = "$($Script:UpdaterConfig.RawBase)/$($Script:UpdaterConfig.Owner)/$($Script:UpdaterConfig.Repo)/main/$($Script:UpdaterConfig.VersionFile)"
    try {
        $resp = Invoke-WebRequest -Uri $url -UseBasicParsing `
            -UserAgent $Script:UpdaterConfig.UserAgent `
            -TimeoutSec $Script:UpdaterConfig.TimeoutSec `
            -ErrorAction Stop
        $version = $resp.Content.Trim() -replace '^v', ''
        if ($version -match '^\d+(\.\d+)+$') {
            return $version
        }
        Write-Log -Level WARN -Message "Updater: version.txt tiene formato invalido: '$version'"
        return $null
    } catch {
        Write-Log -Level WARN -Message "Updater: no se pudo leer version remota - $($_.Exception.Message)"
        return $null
    }
}

function Get-LatestReleaseInfo {
    <#
    .SYNOPSIS
    Consulta la GitHub API para info del ultimo release. Devuelve PSCustomObject o $null.
    #>
    $url = "$($Script:UpdaterConfig.ApiBase)/repos/$($Script:UpdaterConfig.Owner)/$($Script:UpdaterConfig.Repo)/releases/latest"
    try {
        $resp = Invoke-WebRequest -Uri $url -UseBasicParsing `
            -UserAgent $Script:UpdaterConfig.UserAgent `
            -TimeoutSec $Script:UpdaterConfig.TimeoutSec `
            -ErrorAction Stop
        $json = $resp.Content | ConvertFrom-Json
        return [pscustomobject]@{
            TagName     = $json.tag_name
            Name        = $json.name
            Body        = $json.body
            PublishedAt = $json.published_at
            ZipUrl      = $json.zipball_url
            HtmlUrl     = $json.html_url
        }
    } catch {
        Write-Log -Level WARN -Message "Updater: no se pudo consultar GitHub API - $($_.Exception.Message)"
        return $null
    }
}

function Compare-SemVer {
    <#
    .SYNOPSIS
    Compara dos versiones semver-like (ej '2.1' vs '2.10'). Devuelve -1, 0, 1.
    #>
    param([string]$Current, [string]$Remote)

    $c = $Current -replace '^v', ''
    $r = $Remote  -replace '^v', ''

    $cParts = $c -split '\.' | ForEach-Object { [int]$_ }
    $rParts = $r -split '\.' | ForEach-Object { [int]$_ }

    $max = [math]::Max($cParts.Count, $rParts.Count)
    for ($i = 0; $i -lt $max; $i++) {
        $cv = if ($i -lt $cParts.Count) { $cParts[$i] } else { 0 }
        $rv = if ($i -lt $rParts.Count) { $rParts[$i] } else { 0 }
        if ($cv -lt $rv) { return -1 }
        if ($cv -gt $rv) { return  1 }
    }
    return 0
}

function Test-UpdateAvailable {
    <#
    .SYNOPSIS
    Verifica si hay una version mas reciente. Devuelve hashtable con info.
    #>
    $currentVersion = $Global:GF.Version -replace '^v', ''
    $remoteVersion  = Get-RemoteVersion

    if (-not $remoteVersion) {
        return @{ Available = $false; Reason = 'No se pudo consultar GitHub' }
    }

    $cmp = Compare-SemVer -Current $currentVersion -Remote $remoteVersion
    if ($cmp -lt 0) {
        return @{
            Available = $true
            Current   = $currentVersion
            Remote    = $remoteVersion
        }
    }
    return @{
        Available = $false
        Current   = $currentVersion
        Remote    = $remoteVersion
        Reason    = 'Ya estas en la ultima version'
    }
}

function Invoke-SilentUpdateCheck {
    <#
    .SYNOPSIS
    Check silencioso al arrancar. Solo muestra algo si hay update disponible.
    #>
    Write-Log -Level INFO -Message "Updater: verificando actualizaciones..."
    $check = Test-UpdateAvailable
    if ($check.Available) {
        Write-Host ""
        Write-UI ('+' + ('-' * 70) + '+') -Color Yellow
        Write-UI "| " -Color Yellow -NoNewline
        Write-Badge -Text " UPDATE DISPONIBLE " -Bg DarkYellow -Fg Black
        Write-UI ("  v{0} -> v{1}" -f $check.Current, $check.Remote) -Color Yellow -NoNewline
        $pad = 70 - (" UPDATE DISPONIBLE   v$($check.Current) -> v$($check.Remote)".Length) - 2
        if ($pad -gt 0) { Write-UI (' ' * $pad) -NoNewline }
        Write-UI " |" -Color Yellow
        Write-UI ("| Usa [U] en el menu para actualizar." + (' ' * 33) + "|") -Color Yellow
        Write-UI ('+' + ('-' * 70) + '+') -Color Yellow
        Write-Log -Level INFO -Message "Updater: nueva version $($check.Remote) disponible"
        $Global:GF.UpdateAvailable = $check
    } else {
        Write-Log -Level INFO -Message "Updater: sin actualizaciones ($($check.Reason))"
        $Global:GF.UpdateAvailable = $null
    }
}

function Invoke-UpdaterMenu {
    Show-Section "ACTUALIZACIONES"

    Write-UI "Version local:  v$($Global:GF.Version -replace '^v', '')" -Color Cyan
    Write-UI "Consultando GitHub..." -Color DarkGreen
    Write-Host ""

    $info = Get-LatestReleaseInfo
    if (-not $info) {
        Write-UI "  [!] No se pudo contactar GitHub. Verifica tu conexion." -Color Red
        return
    }

    $remoteVer = $info.TagName -replace '^v', ''
    $currentVer = $Global:GF.Version -replace '^v', ''
    $cmp = Compare-SemVer -Current $currentVer -Remote $remoteVer

    Write-UI "Version remota: v$remoteVer ($($info.Name))" -Color Cyan
    Write-UI "Publicado:      $($info.PublishedAt)" -Color DarkGreen
    Write-Host ""

    if ($cmp -ge 0) {
        Write-UI "  Ya estas en la ultima version." -Color Green
        return
    }

    Write-UI "=== CHANGELOG ===" -Color Yellow
    foreach ($line in $info.Body -split "`n") {
        Write-UI ("  " + $line.Trim()) -Color Green
    }
    Write-Host ""

    Write-UI "  [?] Descargar e instalar v$remoteVer ahora? (s/N): " -Color Yellow -NoNewline
    $r = Read-Host
    if ($r.Trim().ToLower() -ne 's') {
        Write-UI "  Actualizacion cancelada." -Color DarkGray
        return
    }

    Install-Update -ReleaseInfo $info
}

function Install-Update {
    param([Parameter(Mandatory=$true)]$ReleaseInfo)

    Write-Host ""
    Write-UI "[1/5] Preparando directorio temporal..." -Color Cyan
    $tempRoot = Join-Path $env:TEMP "gamefixer-update-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $zipPath = Join-Path $tempRoot 'release.zip'
    $extractPath = Join-Path $tempRoot 'extract'
    Write-Log -Level INFO -Message "Updater: temp dir = $tempRoot"

    Write-UI "[2/5] Descargando release..." -Color Cyan
    Write-UI ("      " + $ReleaseInfo.ZipUrl) -Color DarkGray
    try {
        Invoke-WebRequest -Uri $ReleaseInfo.ZipUrl `
            -OutFile $zipPath -UseBasicParsing `
            -UserAgent $Script:UpdaterConfig.UserAgent `
            -ErrorAction Stop
        $sizeKB = [math]::Round((Get-Item $zipPath).Length / 1KB, 0)
        Write-UI "      Descargado: $sizeKB KB" -Color Green
    } catch {
        Write-UI ("      [X] Error: " + $_.Exception.Message) -Color Red
        Write-Log -Level ERROR -Message "Updater: download fail - $($_.Exception.Message)"
        return
    }

    Write-UI "[3/5] Descomprimiendo..." -Color Cyan
    try {
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        # GitHub zipball extrae a una carpeta con nombre tipo 'FamiliaCuba-gamefixer-<hash>'
        $innerDir = Get-ChildItem $extractPath -Directory | Select-Object -First 1
        if (-not $innerDir) {
            Write-UI "      [X] ZIP vacio o corrupto" -Color Red
            return
        }
        Write-UI "      Origen: $($innerDir.Name)" -Color Green
    } catch {
        Write-UI ("      [X] " + $_.Exception.Message) -Color Red
        return
    }

    Write-UI "[4/5] Backup de version actual..." -Color Cyan
    $backupDir = Join-Path $Global:GF.BackupsDir "pre-update-v$($Global:GF.Version -replace '^v', '')-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

    # Backup de los archivos que vamos a reemplazar
    $filesToBackup = @('GameFixer.ps1','GameFixer.bat','README.md')
    foreach ($f in $filesToBackup) {
        $src = Join-Path $Global:GF.Root $f
        if (Test-Path $src) {
            Copy-Item $src (Join-Path $backupDir $f) -Force
        }
    }
    if (Test-Path $Global:GF.ModulesDir) {
        Copy-Item $Global:GF.ModulesDir (Join-Path $backupDir 'modules') -Recurse -Force
    }
    Write-UI "      Backup: $backupDir" -Color Green
    Write-Log -Level INFO -Message "Updater: backup creado en $backupDir"

    Write-UI "[5/5] Aplicando nuevos archivos..." -Color Cyan

    # Copiar archivos nuevos encima
    $sourceRoot = $innerDir.FullName

    # Archivos de la raiz
    foreach ($f in @('GameFixer.ps1','GameFixer.bat','README.md','version.txt')) {
        $src = Join-Path $sourceRoot $f
        if (Test-Path $src) {
            Copy-Item $src (Join-Path $Global:GF.Root $f) -Force
            Write-UI "      OK $f" -Color Green
        }
    }

    # Carpeta modules
    $srcModules = Join-Path $sourceRoot 'modules'
    if (Test-Path $srcModules) {
        Get-ChildItem $srcModules -File | ForEach-Object {
            Copy-Item $_.FullName (Join-Path $Global:GF.ModulesDir $_.Name) -Force
            Write-UI "      OK modules/$($_.Name)" -Color Green
        }
    }

    # Limpiar temp
    Remove-Item $tempRoot -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-UI ("=" * 72) -Color DarkGreen
    Write-UI "  Actualizacion completada a v$($ReleaseInfo.TagName -replace '^v', '')." -Color Green
    Write-UI "  Reiniciando GAMEFIXER..." -Color Green
    Write-Log -Level INFO -Message "Updater: actualizacion OK a $($ReleaseInfo.TagName)"
    Start-Sleep -Seconds 2

    # Re-lanzar el script
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$($Global:GF.Root)\GameFixer.ps1`"")
    Start-Process -FilePath 'powershell.exe' -ArgumentList $argList
    exit
}

Export-ModuleMember -Function Get-RemoteVersion, Get-LatestReleaseInfo, `
    Compare-SemVer, Test-UpdateAvailable, Invoke-SilentUpdateCheck, `
    Invoke-UpdaterMenu, Install-Update
