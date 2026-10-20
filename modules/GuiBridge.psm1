# Acciones que la ventana llama por nombre. No abre el menu de consola.

function Invoke-GuiAction {
    param(
        [string]$Name,
        [switch]$Confirm
    )

    $Global:GF.GuiAction = $true
    # Sin consola, Read-Host se quedaria esperando para siempre.
    # 's' solo si la ventana ya pidio confirmacion; si no, se responde que no.
    if ($Confirm) {
        function global:Read-Host { return 's' }
    } else {
        function global:Read-Host { return 'n' }
    }

    # La ventana no tiene consola: el texto tiene que salir por la salida estandar.
    function global:Write-Host {
        [CmdletBinding()]
        param(
            [Parameter(Position = 0)]
            [object]$Object,
            [switch]$NoNewline,
            $Separator,
            $ForegroundColor,
            $BackgroundColor
        )
        $text = ''
        if ($null -ne $Object) { $text = [string]$Object }
        if ($NoNewline) { [Console]::Out.Write($text) } else { [Console]::Out.WriteLine($text) }
    }

    switch ($Name) {
        'diagnostico' { Invoke-Diagnostico }
        'salud'       { Invoke-Salud }
        'optimizar'   { Invoke-OptimizacionGamer }
        'autofix'     { Invoke-AutoFix }
        'limpieza'    { & (Get-Module Limpieza) { Invoke-CleanAll -Targets (Get-CleanupTargets) } }
        'papelera'    { & (Get-Module Limpieza) { Invoke-EmptyRecycleBin } }
        'winsxs'      { & (Get-Module Limpieza) { Invoke-WinSxSCleanup } }
        'sfc'         { & (Get-Module Reparacion) { Invoke-SFC } }
        'dism'        { & (Get-Module Reparacion) { Invoke-DISM } }
        'chkdsk'      { & (Get-Module Reparacion) { Invoke-Chkdsk } }
        'reparar'     { & (Get-Module Reparacion) { Invoke-SFC; Invoke-DISM } }
        'gpuinfo'     { Show-GPUInfo }
        'shaders'     { Clear-ShaderCache }
        'gpuperf'     { Set-GPUMaxPerformance }
        'gpudriver'   { Test-GPUDriverVersion }
        'latencia'    { & (Get-Module Red) { Test-Latency } }
        'resetred'    { & (Get-Module Red) { Reset-Network } }
        'dns-cf'      { & (Get-Module Red) { Set-DNSCloudflare } }
        'dns-google'  { & (Get-Module Red) { Set-DNSGoogle } }
        'dns-reset'   { & (Get-Module Red) { Reset-DNS } }
        'conexiones'  { & (Get-Module Red) { Show-Connections } }
        'stutter'     { & (Get-Module SolucionesComunes) { Fix-Stuttering } }
        'audio'       { & (Get-Module SolucionesComunes) { Fix-Audio } }
        'inputlag'    { & (Get-Module SolucionesComunes) { Fix-InputLag } }
        'hags'        { & (Get-Module SolucionesComunes) { Enable-HAGS } }
        'mouse'       { & (Get-Module SolucionesComunes) { Disable-MouseAccel } }
        'perfil-gamer'     { & (Get-Module Perfiles) { Apply-ProfileGamer } }
        'perfil-oficina'   { & (Get-Module Perfiles) { Apply-ProfileOficina } }
        'perfil-ahorro'    { & (Get-Module Perfiles) { Apply-ProfileAhorro } }
        'perfil-streaming' { & (Get-Module Perfiles) { Apply-ProfileStreaming } }
        'backups'     { & (Get-Module Rollback) { Show-Backups } }
        'rollback'    { & (Get-Module Rollback) { Restore-LastBackup } }
        'restorepoint'{ & (Get-Module Rollback) { New-SystemRestorePoint } }
        'bench-cpu'   { $r = Invoke-CPUBenchmark; Show-BenchResult -Result $r; Save-BenchResult -Type 'CPU' -Result $r }
        'bench-ram'   { $r = Invoke-RAMBenchmark; Show-BenchResult -Result $r; Save-BenchResult -Type 'RAM' -Result $r }
        'bench-disk'  { $r = Invoke-DiskBenchmark; Save-BenchResult -Type 'Disk' -Result $r }
        'bench-net'   { $r = Invoke-NetworkBenchmark; Show-BenchResult -Result $r; Save-BenchResult -Type 'Network' -Result $r }
        'bench-full'  { Invoke-FullBenchmark }
        'juegos'      { Show-GuiGames }
        'startup'     { Show-GuiStartup }
        'autodiag'    { Invoke-AutoDiagnostic }
        'plugins'     { Show-GuiPlugins }
        'soporte'     {
            $note = [Environment]::GetEnvironmentVariable('GF_SUPPORT_NOTE')
            if ($null -eq $note) { $note = '' }
            New-SupportPackage -Full $true -GuiNote $note
        }
        default {
            if ($Name -like 'tweak:*') {
                Invoke-GuiTweak -Func ($Name.Substring(6))
            } elseif ($Name -like 'startup-off:*') {
                $rest = $Name.Substring(12)
                $pipe = $rest.IndexOf('|')
                if ($pipe -lt 1) {
                    Write-UI ("Accion desconocida: " + $Name) -Color Red
                    exit 1
                }
                Disable-GuiStartup -Hive $rest.Substring(0, $pipe) -Name $rest.Substring($pipe + 1)
            } else {
                Write-UI ("Accion desconocida: " + $Name) -Color Red
                exit 1
            }
        }
    }
}

function Get-StartupEntries {
    $rows = @()
    $places = @(
        @{ Hive = 'HKCU';  Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKLM';  Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'WOW64'; Path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' }
    )
    foreach ($p in $places) {
        if (-not (Test-Path $p.Path)) { continue }
        $item = Get-Item -Path $p.Path -ErrorAction SilentlyContinue
        if (-not $item) { continue }
        foreach ($prop in @($item.Property)) {
            if (-not $prop) { continue }
            $val = $null
            try { $val = (Get-ItemProperty -Path $p.Path -Name $prop -ErrorAction Stop).$prop } catch { continue }
            $rows += [pscustomobject]@{ Hive = $p.Hive; Name = [string]$prop; Command = [string]$val }
        }
    }
    return $rows
}

function Show-GuiStartup {
    $rows = @(Get-StartupEntries)
    Write-UI ("Inicio: " + $rows.Count) -Color Cyan
    foreach ($r in $rows) {
        $name = ($r.Name -replace '\|', ' ').Trim()
        if (-not $name) { continue }
        Write-UI ("INICIO|" + $r.Hive + "|" + $name) -Color Green
    }
    if ($rows.Count -eq 0) {
        Write-UI "No hay programas de inicio en el registro." -Color Yellow
    }
}

function Disable-GuiStartup {
    param([string]$Hive, [string]$Name)
    $path = $null
    if ($Hive -eq 'HKCU') { $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' }
    elseif ($Hive -eq 'HKLM') { $path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' }
    elseif ($Hive -eq 'WOW64') { $path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' }
    if (-not $path) {
        Write-UI "No se reconoce el origen del inicio." -Color Red
        return
    }
    if ($Name -match '[\r\n"]') {
        Write-UI "Nombre no permitido." -Color Red
        return
    }
    $exists = $null
    try { $exists = Get-ItemProperty -Path $path -Name $Name -ErrorAction Stop } catch { $exists = $null }
    if (-not $exists) {
        Write-UI "Ese inicio ya no está." -Color Yellow
        return
    }
    $do = {
        Remove-ItemProperty -LiteralPath $path -Name $Name -ErrorAction Stop
    }.GetNewClosure()
    Invoke-LoggedAction -Description ("Quitar del inicio: " + $Name) -Action $do
    if ($Global:GF.DryRun) {
        Write-UI ("Prueba: se quitaría " + $Name + " del inicio.") -Color Yellow
        return
    }
    $still = $null
    try { $still = Get-ItemProperty -Path $path -Name $Name -ErrorAction Stop } catch { $still = $null }
    if (-not $still) { Write-UI ("Quitado del inicio: " + $Name) -Color Green }
}

function Show-GuiGames {
    Write-UI "Buscando juegos instalados..." -Color Cyan
    $launchers = @(Get-InstalledLaunchers)
    $launcherNames = @($launchers | ForEach-Object { $_.Name })
    if ($launcherNames.Count -eq 0) {
        Write-UI "Launchers: ninguno" -Color Cyan
    } else {
        Write-UI ("Launchers: " + ($launcherNames -join ', ')) -Color Cyan
    }
    Set-GameSizeMeasure $false
    $games = @()
    try {
        $games = @(Get-InstalledGames -Launchers $launchers)
    } finally {
        Set-GameSizeMeasure $true
    }
    $games = @($games | Sort-Object Launcher, Name)
    Write-UI ("Juegos: " + $games.Count) -Color Cyan
    foreach ($g in $games) {
        $name = $g.Name
        if (-not $name) { continue }
        $name = ($name -replace '\|', ' ').Trim()
        Write-UI ("JUEGO|" + $g.Launcher + "|" + $name) -Color Green
    }
    if ($games.Count -eq 0) {
        Write-UI "No se detectaron juegos instalados." -Color Yellow
    }
}

function Show-GuiPlugins {
    $files = @(Get-ChildItem $Global:GF.PluginsDir -Filter *.psm1 -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) {
        Write-UI "No hay plugins en la carpeta plugins." -Color Yellow
        return
    }
    foreach ($f in $files) {
        Write-UI ("  " + $f.Name) -Color Green
    }
}

function Invoke-GuiTweak {
    param([string]$Func)
    $ok = @(
        'Apply-CS2Tweaks','Apply-ValorantTweaks','Apply-R6Tweaks','Apply-ApexTweaks',
        'Apply-FortniteTweaks','Apply-WarzoneTweaks','Apply-BattlefieldTweaks',
        'Apply-DeltaForceTweaks','Apply-TheFinalsTweaks','Apply-MarvelRivalsTweaks',
        'Apply-LolTweaks','Apply-Dota2Tweaks','Apply-RustTweaks','Apply-DayZTweaks',
        'Apply-ArkTweaks','Apply-GTAVTweaks','Apply-RDR2Tweaks','Apply-CyberpunkTweaks',
        'Apply-EldenRingTweaks','Apply-MinecraftTweaks','Apply-TarkovTweaks','Apply-PUBGTweaks'
    )
    if ($ok -notcontains $Func) {
        Write-UI ("Ajuste no permitido: " + $Func) -Color Red
        exit 1
    }
    & (Get-Module GameTweaks) { & $args[0] } $Func
}

Export-ModuleMember -Function Invoke-GuiAction
