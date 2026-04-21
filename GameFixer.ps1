# ============================================================================
#  GAMEFIXER v2.02 - FamiliaCuba Edition
#  Main entry point
#  Herramienta profesional de diagnostico, optimizacion y reparacion de Windows
# ============================================================================

#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$Live,
    [switch]$NoBanner,
    [switch]$NoUpdate,
    [string]$Profile = 'FamiliaCuba'
)

$ErrorActionPreference = 'Stop'

# --- Auto-elevacion a Admin -------------------------------------------------
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal   = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin     = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "  [!] GAMEFIXER requiere privilegios de administrador." -ForegroundColor Yellow
    Write-Host "  [>] Relanzando con elevacion..." -ForegroundColor Cyan
    Start-Sleep -Seconds 1

    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    if ($Live)     { $argList += '-Live' }
    if ($NoBanner) { $argList += '-NoBanner' }
    if ($NoUpdate) { $argList += '-NoUpdate' }
    $argList += @('-Profile', "`"$Profile`"")

    try {
        Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs
    } catch {
        Write-Host "  [X] No se pudo elevar. Ejecuta PowerShell como Administrador manualmente." -ForegroundColor Red
        Read-Host "Presiona ENTER para salir"
    }
    exit
}

# --- Configuracion global ---------------------------------------------------
$Global:GF = @{
    Version            = 'v2.04'
    Build              = '2604'
    Profile            = $Profile
    DryRun             = -not $Live
    Root               = $PSScriptRoot
    ModulesDir         = Join-Path $PSScriptRoot 'modules'
    PluginsDir         = Join-Path $PSScriptRoot 'plugins'
    LogsDir            = Join-Path $PSScriptRoot 'logs'
    BackupsDir         = Join-Path $PSScriptRoot 'backups'
    ReportsDir         = Join-Path $PSScriptRoot 'reports'
    BenchmarksDir      = Join-Path $PSScriptRoot 'benchmarks'
    LogFile            = $null
    StartTime          = Get-Date
    IsAdmin            = $isAdmin
    Hostname           = $env:COMPUTERNAME
    User               = $env:USERNAME
    GPUVendor          = 'nvidia'
    UpdateAvailable    = $null
    DetectedGames      = @()
    DetectedLaunchers  = @()
    Plugins            = @()
}

foreach ($dir in @($Global:GF.LogsDir, $Global:GF.BackupsDir, $Global:GF.ReportsDir, $Global:GF.BenchmarksDir, $Global:GF.PluginsDir)) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}

$Global:GF.LogFile = Join-Path $Global:GF.LogsDir ("session-{0}.log" -f (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding           = [System.Text.Encoding]::UTF8
    chcp 65001 | Out-Null
} catch {}

$Global:GF.BlockFull  = [char]0x2588
$Global:GF.BlockLight = [char]0x2591

# --- Carga de modulos -------------------------------------------------------
$moduleOrder = @(
    'UI.psm1',
    'Logger.psm1',
    'Telemetry.psm1',
    'Updater.psm1',
    'Benchmark.psm1',
    'HtmlReport.psm1',
    'GameDetector.psm1',
    'GameTweaks.psm1',
    'AutoFix.psm1',
    'PluginLoader.psm1',
    'Diagnostico.psm1',
    'OptimizacionGamer.psm1',
    'GPU.psm1',
    'Red.psm1',
    'Reparacion.psm1',
    'Limpieza.psm1',
    'SolucionesComunes.psm1',
    'Rollback.psm1',
    'Salud.psm1',
    'Perfiles.psm1'
)

foreach ($mod in $moduleOrder) {
    $path = Join-Path $Global:GF.ModulesDir $mod
    if (Test-Path $path) {
        Import-Module $path -Force -DisableNameChecking -Global
    } else {
        Write-Host "[!] Modulo no encontrado: $mod" -ForegroundColor Yellow
    }
}

# --- Inicializacion ---------------------------------------------------------
Initialize-Logger
Write-Log -Level INFO -Message "GameFixer $($Global:GF.Version) iniciado por $($Global:GF.User)@$($Global:GF.Hostname)"
Write-Log -Level INFO -Message "DryRun: $($Global:GF.DryRun) | Profile: $($Global:GF.Profile)"

# Cargar plugins
try { Initialize-PluginLoader } catch { Write-Log -Level WARN -Message "Plugin loader fallo: $($_.Exception.Message)" }

# Check silencioso de actualizaciones
if (-not $NoUpdate) {
    try { Invoke-SilentUpdateCheck } catch { Write-Log -Level WARN -Message "Updater silent check fallo: $($_.Exception.Message)" }
}

# Animacion de boot
if (-not $NoBanner) {
    Show-BootAnimation
}

# --- Loop principal ---------------------------------------------------------
function Invoke-MenuChoice {
    param([string]$Choice)

    switch ($Choice) {
        '1' { Invoke-Diagnostico }
        '2' { Invoke-OptimizacionGamer }
        '3' { Invoke-GPUMenu }
        '4' { Invoke-RedMenu }
        '5' { Invoke-Reparacion }
        '6' { Invoke-Limpieza }
        '7' { Invoke-SolucionesComunes }
        '8' { Invoke-Rollback }
        '9' { Invoke-Salud }
        'P' { Invoke-Perfiles }
        'A' { Invoke-AutoFix }
        'B' { Invoke-BenchmarkMenu }
        'G' { Invoke-GameDetectorMenu }
        'T' { Invoke-GameTweaksMenu }
        'X' { Invoke-PluginsMenu }
        'U' { Invoke-UpdaterMenu }
        'L' { Show-Logs }
        'C' { Show-Config }
        'H' { Show-Help }
        'D' {
            $Global:GF.DryRun = -not $Global:GF.DryRun
            $state = if ($Global:GF.DryRun) { 'ACTIVADO' } else { 'DESACTIVADO' }
            Write-UI "`n[>] DRY-RUN $state" -Color Yellow
            Write-Log -Level INFO -Message "DryRun toggled: $($Global:GF.DryRun)"
            Start-Sleep -Seconds 1
        }
        'Q' { return 'EXIT' }
        '' { }
        default {
            Write-UI "`n[!] Opcion invalida: '$Choice'" -Color Red
            Start-Sleep -Seconds 1
        }
    }
    return 'CONTINUE'
}

try {
    do {
        Clear-Host
        Show-TopBar
        Show-Banner
        Show-StatusLine
        Show-TelemetryPanels
        Show-UpdateBanner
        Show-MainMenu
        Show-Footer

        $choice = (Read-Host).Trim().ToUpper()
        Write-Log -Level DEBUG -Message "Menu choice: '$choice'"

        $state = Invoke-MenuChoice -Choice $choice

        # Solo pausar para acciones que NO tienen su propio submenu con loop.
        # Los submenus con loop (3,4,5,6,7,8,P,B,T) se encargan de su propio pause.
        # Acciones de tirada directa: 1,2,9,A,G,X,U,L,C,H,D
        if ($choice -match '^[129AGXULCH]$') {
            Write-Host ""
            Write-UI "  Presiona ENTER para volver al menu principal..." -Color DarkGreen -NoNewline
            [void](Read-Host)
        }
    } while ($state -ne 'EXIT')

    Write-UI "`n  Cerrando GAMEFIXER. Hasta la proxima, $($Global:GF.Profile)." -Color Green
    Write-Log -Level INFO -Message "GameFixer cerrado normalmente"
    Start-Sleep -Seconds 1

} catch {
    Write-UI "`n=== ERROR FATAL ===" -Color Red
    Write-UI $_.Exception.Message -Color Red
    Write-UI $_.ScriptStackTrace -Color DarkRed
    Write-Log -Level ERROR -Message "FATAL: $($_.Exception.Message)"
    Write-Log -Level ERROR -Message $_.ScriptStackTrace
    Read-Host "`nPresiona ENTER para cerrar"
}
