# ============================================================================
#  modules/UI.psm1
#  Helpers de interfaz: colores, banner, paneles, animaciones, temas
# ============================================================================

# ----------------------------------------------------------------------------
#  SISTEMA DE TEMAS
#  Cada tema mapea "roles semanticos" a ConsoleColor reales.
#  Roles: Primary, Secondary, Accent, Warning, Danger, Dim, Highlight, Label
# ----------------------------------------------------------------------------

$Script:Themes = @{
    matrix = @{
        Primary   = 'Green'         # texto principal, valores OK
        Secondary = 'DarkGreen'     # separadores, bordes atenuados
        Accent    = 'Yellow'        # teclas del menu [1][2][3]
        Warning   = 'Yellow'
        Danger    = 'Red'
        Dim       = 'DarkGray'      # texto muy apagado
        Highlight = 'Cyan'          # titulos de seccion
        Label     = 'Cyan'          # labels CPU/GPU/RAM
        BadgeBg   = 'DarkYellow'
        BadgeFg   = 'Black'
    }
    cyberpunk = @{
        Primary   = 'Magenta'
        Secondary = 'DarkMagenta'
        Accent    = 'Yellow'
        Warning   = 'Yellow'
        Danger    = 'Red'
        Dim       = 'DarkGray'
        Highlight = 'Cyan'
        Label     = 'Cyan'
        BadgeBg   = 'DarkMagenta'
        BadgeFg   = 'White'
    }
    fallout = @{
        Primary   = 'DarkYellow'    # ambar clasico Pip-Boy
        Secondary = 'DarkGray'
        Accent    = 'Yellow'
        Warning   = 'Yellow'
        Danger    = 'Red'
        Dim       = 'DarkGray'
        Highlight = 'DarkYellow'
        Label     = 'Yellow'
        BadgeBg   = 'DarkYellow'
        BadgeFg   = 'Black'
    }
    dracula = @{
        Primary   = 'Magenta'       # violeta
        Secondary = 'DarkMagenta'
        Accent    = 'Green'         # verde menta para acentos
        Warning   = 'Yellow'
        Danger    = 'Red'
        Dim       = 'DarkGray'
        Highlight = 'Cyan'          # rosa/cyan para titulos
        Label     = 'Cyan'
        BadgeBg   = 'DarkMagenta'
        BadgeFg   = 'White'
    }
}

function Get-ThemeColor {
    <#
    .SYNOPSIS
    Devuelve el ConsoleColor real de un rol semantico en el tema actual.
    Si no hay tema cargado o el rol no existe, devuelve un default sensato.
    #>
    param(
        [string]$Role = 'Primary',
        [ConsoleColor]$Default = 'Green'
    )

    $themeName = 'matrix'
    if ($Global:GF -and $Global:GF.Config -and $Global:GF.Config.theme) {
        $themeName = $Global:GF.Config.theme
    }

    $theme = $Script:Themes[$themeName]
    if (-not $theme) { $theme = $Script:Themes['matrix'] }

    if ($theme.ContainsKey($Role)) {
        return [ConsoleColor]$theme[$Role]
    }
    return $Default
}

function ConvertTo-ThemeColor {
    <#
    .SYNOPSIS
    Traduce un ConsoleColor "matrix-default" al equivalente en el tema activo.
    Asi el codigo viejo que pasa -Color Green automaticamente se adapta.
    #>
    param([ConsoleColor]$Color)

    $themeName = 'matrix'
    if ($Global:GF -and $Global:GF.Config -and $Global:GF.Config.theme) {
        $themeName = $Global:GF.Config.theme
    }

    # Si el tema es matrix, pasamos directo (comportamiento original)
    if ($themeName -eq 'matrix' -or -not $Script:Themes[$themeName]) {
        return $Color
    }

    # Mapeo: el color original matrix -> rol -> color del tema activo
    $map = @{
        'Green'      = 'Primary'
        'DarkGreen'  = 'Secondary'
        'Yellow'     = 'Accent'
        'DarkYellow' = 'Warning'
        'Red'        = 'Danger'
        'DarkRed'    = 'Danger'
        'Cyan'       = 'Highlight'
        'DarkCyan'   = 'Label'
        'DarkGray'   = 'Dim'
        'Gray'       = 'Dim'
    }

    $role = $map[$Color.ToString()]
    if ($role) {
        return (Get-ThemeColor -Role $role -Default $Color)
    }
    return $Color
}

function Write-UI {
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [AllowEmptyString()]
        [string]$Text,
        [ConsoleColor]$Color = 'Green',
        [switch]$NoNewline
    )
    $themedColor = ConvertTo-ThemeColor -Color $Color
    $prev = [Console]::ForegroundColor
    [Console]::ForegroundColor = $themedColor
    if ($NoNewline) { [Console]::Write($Text) } else { [Console]::WriteLine($Text) }
    [Console]::ForegroundColor = $prev
}

function Write-Badge {
    param(
        [string]$Text,
        [ConsoleColor]$Bg = 'DarkYellow',
        [ConsoleColor]$Fg = 'Black'
    )
    $prevBg = [Console]::BackgroundColor
    $prevFg = [Console]::ForegroundColor
    [Console]::BackgroundColor = $Bg
    [Console]::ForegroundColor = $Fg
    [Console]::Write($Text)
    [Console]::BackgroundColor = $prevBg
    [Console]::ForegroundColor = $prevFg
}

function Write-TypeLine {
    param([string]$Text, [ConsoleColor]$Color = 'Green', [int]$DelayMs = 15)
    $prev = [Console]::ForegroundColor
    [Console]::ForegroundColor = $Color
    foreach ($char in $Text.ToCharArray()) {
        [Console]::Write($char)
        Start-Sleep -Milliseconds $DelayMs
    }
    [Console]::WriteLine()
    [Console]::ForegroundColor = $prev
}

function Show-BootAnimation {
    Clear-Host
    Write-Host ""
    $lines = @(
        '[OK] Inicializando kernel de diagnostico........',
        '[OK] Cargando modulos de reparacion.............',
        '[OK] Detectando hardware NVIDIA.................',
        '[OK] Montando sistema de logging................',
        '[OK] Verificando permisos de administrador......',
        '[OK] GAMEFIXER listo.'
    )
    foreach ($l in $lines) {
        Write-TypeLine -Text ("  " + $l) -Color Green -DelayMs 8
        Start-Sleep -Milliseconds 80
    }
    Start-Sleep -Milliseconds 400
}

function Show-Banner {
    $banner = @'
 ██████╗  █████╗ ███╗   ███╗███████╗███████╗██╗██╗  ██╗███████╗██████╗
██╔════╝ ██╔══██╗████╗ ████║██╔════╝██╔════╝██║╚██╗██╔╝██╔════╝██╔══██╗
██║  ███╗███████║██╔████╔██║█████╗  █████╗  ██║ ╚███╔╝ █████╗  ██████╔╝
██║   ██║██╔══██║██║╚██╔╝██║██╔══╝  ██╔══╝  ██║ ██╔██╗ ██╔══╝  ██╔══██╗
╚██████╔╝██║  ██║██║ ╚═╝ ██║███████╗██║     ██║██╔╝ ██╗███████╗██║  ██║
 ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
'@
    foreach ($line in $banner -split "`n") {
        Write-UI $line.TrimEnd() -Color Green
    }
}

function Show-TopBar {
    $uptime = (Get-Date) - $Global:GF.StartTime
    $uptimeStr = '{0:D2}:{1:D2}:{2:D2}' -f $uptime.Hours, $uptime.Minutes, $uptime.Seconds
    $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $adminStr = if ($Global:GF.IsAdmin) { 'YES' } else { 'NO' }
    $adminColor = if ($Global:GF.IsAdmin) { 'Red' } else { 'DarkGray' }

    Write-UI "> session: " -Color DarkGreen -NoNewline
    Write-UI $Global:GF.Hostname -Color Yellow -NoNewline
    Write-UI " | admin: " -Color DarkGreen -NoNewline
    Write-UI $adminStr -Color $adminColor -NoNewline
    Write-UI " | uptime: " -Color DarkGreen -NoNewline
    Write-UI $uptimeStr -Color Cyan -NoNewline
    Write-UI " | " -Color DarkGreen -NoNewline
    Write-UI $now -Color Cyan
}

function Show-StatusLine {
    # Version ya incluye la 'v' (ej: 'v2.1'), asi que NO anteponer otra
    $line = "$($Global:GF.Version) build $($Global:GF.Build) | profile: $($Global:GF.Profile)"
    Write-UI $line -Color DarkGreen -NoNewline
    Write-UI "    " -NoNewline
    if ($Global:GF.DryRun) {
        Write-Badge -Text ' MODO PRUEBA - SIMULA ' -Bg DarkYellow -Fg Black
    } else {
        Write-Badge -Text ' MODO REAL - APLICA CAMBIOS ' -Bg DarkRed -Fg White
    }
    Write-Host ""
    Write-UI ('-' * 76) -Color DarkGreen
}

# ----------------------------------------------------------------------------
#  PANELES EN DOS COLUMNAS (usando SetCursorPosition)
# ----------------------------------------------------------------------------

function Write-BarAt {
    param(
        [int]$Row,
        [int]$Col,
        [string]$Label,
        [int]$Percent,
        [string]$Extra = '',
        [int]$Width = 18
    )
    if ($Percent -lt 0)   { $Percent = 0 }
    if ($Percent -gt 100) { $Percent = 100 }

    $filled = [int][math]::Round(($Percent / 100) * $Width)
    $empty  = $Width - $filled

    $valColor = 'Green'
    if ($Percent -ge 85)      { $valColor = 'Red' }
    elseif ($Percent -ge 70)  { $valColor = 'Yellow' }

    [Console]::SetCursorPosition($Col, $Row)
    Write-UI ("{0,-4} " -f $Label)                           -Color Cyan       -NoNewline
    Write-UI "["                                             -Color Green      -NoNewline
    Write-UI ($Global:GF.BlockFull.ToString()  * $filled)    -Color Green      -NoNewline
    Write-UI ($Global:GF.BlockLight.ToString() * $empty)     -Color DarkGreen  -NoNewline
    Write-UI "] "                                            -Color Green      -NoNewline
    Write-UI ("{0,3}%" -f $Percent)                          -Color $valColor  -NoNewline
    if ($Extra) {
        Write-UI (" " + $Extra) -Color DarkGray -NoNewline
    }
}

function Write-LabelAt {
    param(
        [int]$Row,
        [int]$Col,
        [string]$Label,
        [string]$Value,
        [ConsoleColor]$ValColor = 'Green'
    )
    [Console]::SetCursorPosition($Col, $Row)
    Write-UI ("{0,-10}: " -f $Label) -Color DarkGreen -NoNewline
    Write-UI $Value -Color $ValColor -NoNewline
}

function Show-TelemetryPanels {
    $stats = Get-TelemetryStats

    $colL = 0      # columna izquierda (HARDWARE)
    $colR = 42     # columna derecha  (SYSTEM HEALTH)

    $startRow = [Console]::CursorTop

    # Cabeceras
    [Console]::SetCursorPosition($colL, $startRow)
    Write-UI "+-- HARDWARE " -Color Cyan -NoNewline
    Write-UI ('-' * 27) -Color Cyan -NoNewline
    Write-UI "+" -Color Cyan -NoNewline

    [Console]::SetCursorPosition($colR, $startRow)
    Write-UI "+-- SYSTEM HEALTH " -Color Cyan -NoNewline
    Write-UI ('-' * 15) -Color Cyan -NoNewline
    Write-UI "+" -Color Cyan

    # Numero de filas depende de cuantos discos hay (max 4 para no romper layout)
    $diskCount = if ($stats.Disks) { [math]::Min($stats.Disks.Count, 4) } else { 1 }
    $contentRows = 3 + $diskCount  # CPU + GPU + RAM + N discos
    $healthLabels = @('OS','Net','Services','Last run','Disks','Admin')

    # Reservar espacio
    $reserveRows = [math]::Max($contentRows, $healthLabels.Count) + 1
    for ($i = 0; $i -lt $reserveRows; $i++) { Write-Host "" }

    # HARDWARE (columna izquierda)
    Write-BarAt -Row ($startRow + 1) -Col ($colL + 2) -Label "CPU"  -Percent $stats.CPU  -Extra ("{0}C" -f $stats.CPUTemp)
    Write-BarAt -Row ($startRow + 2) -Col ($colL + 2) -Label "GPU"  -Percent $stats.GPU  -Extra ("{0}C" -f $stats.GPUTemp)
    Write-BarAt -Row ($startRow + 3) -Col ($colL + 2) -Label "RAM"  -Percent $stats.RAM  -Extra ("{0}/{1}GB" -f $stats.RAMUsedGB, $stats.RAMTotalGB)

    # Una barra por disco (hasta 4)
    if ($stats.Disks -and $stats.Disks.Count -gt 0) {
        $shown = [math]::Min($stats.Disks.Count, 4)
        for ($i = 0; $i -lt $shown; $i++) {
            $d = $stats.Disks[$i]
            $label = $d.Drive.TrimEnd(':')
            Write-BarAt -Row ($startRow + 4 + $i) -Col ($colL + 2) -Label $label `
                -Percent $d.Percent -Extra ("{0}/{1}GB" -f $d.UsedGB, $d.TotalGB)
        }
    } else {
        Write-BarAt -Row ($startRow + 4) -Col ($colL + 2) -Label "DISK" -Percent $stats.Disk -Extra ("{0}/{1}GB" -f $stats.DiskUsedGB, $stats.DiskTotalGB)
    }

    # SYSTEM HEALTH (columna derecha)
    $osShort = $stats.OS
    if ($osShort.Length -gt 28) { $osShort = $osShort.Substring(0, 28) }
    $netShort = $stats.NetStatus
    if ($netShort.Length -gt 28) { $netShort = $netShort.Substring(0, 28) }

    Write-LabelAt -Row ($startRow + 1) -Col ($colR + 2) -Label "OS"       -Value $osShort
    Write-LabelAt -Row ($startRow + 2) -Col ($colR + 2) -Label "Net"      -Value $netShort
    $svcColor = if ($stats.Services -eq 'OK') { 'Green' } else { 'Yellow' }
    Write-LabelAt -Row ($startRow + 3) -Col ($colR + 2) -Label "Services" -Value $stats.Services -ValColor $svcColor
    Write-LabelAt -Row ($startRow + 4) -Col ($colR + 2) -Label "Last run" -Value $stats.LastRun
    if ($stats.Disks) {
        $disksInfo = "$($stats.Disks.Count) drives ($($stats.DiskTotalGB)GB)"
        Write-LabelAt -Row ($startRow + 5) -Col ($colR + 2) -Label "Storage" -Value $disksInfo
    }
    $adminTxt = if ($Global:GF.IsAdmin) { 'YES' } else { 'NO' }
    $adminCol = if ($Global:GF.IsAdmin) { 'Green' } else { 'Yellow' }
    Write-LabelAt -Row ($startRow + 6) -Col ($colR + 2) -Label "Admin"    -Value $adminTxt -ValColor $adminCol

    # Pies de los paneles (se ajustan dinamicamente)
    $footerRow = $startRow + $reserveRows
    [Console]::SetCursorPosition($colL, $footerRow)
    Write-UI ('+' + ('-' * 39) + '+') -Color Cyan -NoNewline
    [Console]::SetCursorPosition($colR, $footerRow)
    Write-UI ('+' + ('-' * 33) + '+') -Color Cyan

    # Mover cursor a la siguiente linea limpia
    [Console]::SetCursorPosition(0, $footerRow + 1)
    Write-Host ""
}

# ----------------------------------------------------------------------------
#  MENU PRINCIPAL (dos columnas con SetCursorPosition)
# ----------------------------------------------------------------------------
function Show-MainMenu {
    Write-UI ("=== MENU PRINCIPAL " + ("=" * 57)) -Color Cyan
    Write-Host ""

    # Fila destacada: AutoFix arriba del todo
    Write-UI "  " -NoNewline
    Write-Badge -Text ' [A] AUTO-FIX ' -Bg DarkGreen -Fg White
    Write-UI "  Pipeline completo en un solo click (recomendado)" -Color Yellow
    Write-Host ""

    $items = @(
        @{ Key='1'; Text='Diagnostico';        Desc='analisis completo del PC' },
        @{ Key='2'; Text='Optimizar Gaming';   Desc='tweaks para maximo FPS' },
        @{ Key='3'; Text='GPU/Graficos';       Desc='drivers NVIDIA, shader cache' },
        @{ Key='4'; Text='Red/Internet';       Desc='DNS, latencia, velocidad' },
        @{ Key='5'; Text='Reparar Windows';    Desc='archivos de sistema (SFC/DISM)' },
        @{ Key='6'; Text='Limpieza';           Desc='temp, cache, papelera' },
        @{ Key='7'; Text='Arreglar Juegos';    Desc='fixes comunes de juegos' },
        @{ Key='8'; Text='Seguridad/Backup';   Desc='respaldos, restaurar, TPM' },
        @{ Key='9'; Text='Salud del PC';       Desc='discos, errores, temperaturas' },
        @{ Key='P'; Text='Perfiles Windows';   Desc='energia: gamer/oficina/ahorro' }
    )

    $half = [math]::Ceiling($items.Count / 2)
    $colL = 2
    $colR = 40

    for ($i = 0; $i -lt $half; $i++) {
        $left  = $items[$i]
        $right = if (($i + $half) -lt $items.Count) { $items[$i + $half] } else { $null }

        $row = [Console]::CursorTop

        [Console]::SetCursorPosition($colL, $row)
        Write-UI ("[{0}] " -f $left.Key) -Color Yellow -NoNewline
        Write-UI $left.Text              -Color Green  -NoNewline

        if ($right) {
            [Console]::SetCursorPosition($colR, $row)
            Write-UI ("[{0}] " -f $right.Key) -Color Yellow -NoNewline
            Write-UI $right.Text              -Color Green  -NoNewline
        }

        Write-Host ""
        $row2 = [Console]::CursorTop

        [Console]::SetCursorPosition($colL + 4, $row2)
        Write-UI ("> " + $left.Desc) -Color DarkGray -NoNewline

        if ($right) {
            [Console]::SetCursorPosition($colR + 4, $row2)
            Write-UI ("> " + $right.Desc) -Color DarkGray -NoNewline
        }

        Write-Host ""
    }
    Write-Host ""

    # Segunda fila de opciones avanzadas
    Write-UI "  FEATURES AVANZADAS:" -Color Cyan
    Write-UI "  [B] " -Color Yellow -NoNewline
    Write-UI "Benchmarks          " -Color Green -NoNewline
    Write-UI "  [G] " -Color Yellow -NoNewline
    Write-UI "Detectar Juegos     " -Color Green -NoNewline
    Write-UI "  [T] " -Color Yellow -NoNewline
    Write-UI "Ajustes por Juego" -Color Green

    Write-UI "  [M] " -Color Yellow -NoNewline
    Write-UI "Monitor en Vivo (htop)  " -Color Green -NoNewline
    Write-UI " [X] " -Color Yellow -NoNewline
    Write-UI "Plugins" -Color Green

    Write-UI "  [S] " -Color Yellow -NoNewline
    Write-UI "Preferencias           " -Color Green -NoNewline
    Write-UI " [E] " -Color Yellow -NoNewline
    Write-UI "Guardar/Cargar perfiles" -Color Green

    Write-UI "  [R] " -Color Yellow -NoNewline
    Write-UI "Reporte de Soporte " -Color Green -NoNewline
    Write-UI "(envia info de tu PC al tecnico)" -Color DarkGray
    Write-Host ""
}

function Show-UpdateBanner {
    # Muestra un banner si $Global:GF.UpdateAvailable esta seteado
    if (-not $Global:GF.UpdateAvailable) { return }
    $u = $Global:GF.UpdateAvailable
    if (-not $u.Available) { return }

    Write-UI ('+' + ('-' * 74) + '+') -Color Yellow
    Write-UI '| ' -Color Yellow -NoNewline
    Write-Badge -Text ' UPDATE ' -Bg DarkYellow -Fg Black
    Write-UI ("  v{0} -> v{1}   [U] para actualizar" -f $u.Current, $u.Remote) -Color Yellow -NoNewline
    $msgLen = 3 + 8 + ("  v{0} -> v{1}   [U] para actualizar" -f $u.Current, $u.Remote).Length
    $pad = 76 - $msgLen - 1
    if ($pad -gt 0) { Write-UI (' ' * $pad) -NoNewline }
    Write-UI '|' -Color Yellow
    Write-UI ('+' + ('-' * 74) + '+') -Color Yellow
    Write-Host ""
}

function Show-Footer {
    Write-UI ('-' * 76) -Color DarkGreen
    Write-UI "  " -NoNewline
    Write-UI "[U]" -Color Yellow -NoNewline
    Write-UI " update  " -Color DarkGreen -NoNewline
    Write-UI "[L]" -Color Yellow -NoNewline
    Write-UI " logs  " -Color DarkGreen -NoNewline
    Write-UI "[I]" -Color Yellow -NoNewline
    Write-UI " info  " -Color DarkGreen -NoNewline
    Write-UI "[H]" -Color Yellow -NoNewline
    Write-UI " help  " -Color DarkGreen -NoNewline
    Write-UI "[D]" -Color Yellow -NoNewline
    Write-UI " modo prueba  " -Color DarkGreen -NoNewline
    Write-UI "[Q]" -Color Yellow -NoNewline
    Write-UI " salir" -Color DarkGreen
    Write-Host ""
    Write-UI "  Log activo: " -Color DarkGreen -NoNewline
    Write-UI $Global:GF.LogFile -Color DarkGray
    Write-Host ""
    Write-UI "  > Selecciona una opcion: " -Color Cyan -NoNewline
}

function Pause-Submenu {
    Write-Host ""
    Write-UI "  Presiona ENTER para volver al submenu..." -Color DarkGreen -NoNewline
    [void](Read-Host)
}

function Show-Section {
    param([string]$Title)
    Write-Host ""
    Write-UI ("=== " + $Title.ToUpper() + " " + ("=" * [math]::Max(1, 72 - $Title.Length))) -Color Cyan
    Write-Host ""
}

function Confirm-Action {
    param([string]$Message)
    if ($Global:GF.DryRun) {
        Write-UI "    [PRUEBA] Se saltaria: $Message" -Color DarkYellow
        return $false
    }
    Write-UI "    [?] $Message (s/N): " -Color Yellow -NoNewline
    $r = Read-Host
    return $r.Trim().ToLower() -eq 's'
}

function Show-Logs {
    Show-Section "LOGS DE LA SESION"
    if (Test-Path $Global:GF.LogFile) {
        Get-Content $Global:GF.LogFile -Tail 40 | ForEach-Object {
            $color = 'Gray'
            if ($_ -match 'ERROR') { $color = 'Red' }
            elseif ($_ -match 'WARN') { $color = 'Yellow' }
            elseif ($_ -match 'INFO') { $color = 'Green' }
            elseif ($_ -match 'DEBUG') { $color = 'DarkGray' }
            Write-UI $_ -Color $color
        }
    } else {
        Write-UI "  Sin logs aun." -Color DarkGray
    }
}

function Show-Config {
    Show-Section "CONFIGURACION ACTUAL"
    Write-UI "  Version      : $($Global:GF.Version)"     -Color Green
    Write-UI "  Build        : $($Global:GF.Build)"       -Color Green
    Write-UI "  Perfil       : $($Global:GF.Profile)"     -Color Green
    Write-UI "  DryRun       : $($Global:GF.DryRun)"      -Color Green
    Write-UI "  GPU Vendor   : $($Global:GF.GPUVendor)"   -Color Green
    Write-UI "  Root         : $($Global:GF.Root)"        -Color Green
    Write-UI "  Logs dir     : $($Global:GF.LogsDir)"     -Color Green
    Write-UI "  Backups dir  : $($Global:GF.BackupsDir)"  -Color Green
    Write-UI "  Log file     : $($Global:GF.LogFile)"     -Color Green
    Write-UI "  Hostname     : $($Global:GF.Hostname)"    -Color Green
    Write-UI "  User         : $($Global:GF.User)"        -Color Green
    Write-UI "  Admin        : $($Global:GF.IsAdmin)"     -Color Green
}

function Show-Help {
    Show-Section "AYUDA"
    Write-UI "  GAMEFIXER es una herramienta de diagnostico, optimizacion y reparacion"  -Color Green
    Write-UI "  de Windows orientada a gaming. Cada opcion ejecuta un flujo especifico." -Color Green
    Write-Host ""
    Write-UI "  MODO PRUEBA:" -Color Yellow
    Write-UI "    Por defecto el script corre en modo MODO PRUEBA: muestra lo que HARIA"     -Color Green
    Write-UI "    sin aplicar cambios. Usa [D] para desactivarlo o lanza con -Live."     -Color Green
    Write-Host ""
    Write-UI "  LOGS:" -Color Yellow
    Write-UI "    Cada sesion genera un log en /logs con timestamps de cada accion."     -Color Green
    Write-Host ""
    Write-UI "  BACKUPS:" -Color Yellow
    Write-UI "    Antes de tocar el registro o servicios, se crea un backup en /backups" -Color Green
    Write-UI "    que puedes restaurar desde [8] Rollback."                              -Color Green
    Write-Host ""
    Write-UI "  OPCIONES DE LANZAMIENTO:" -Color Yellow
    Write-UI "    -Live               Ejecuta cambios reales (no MODO PRUEBA)"               -Color Green
    Write-UI "    -NoBanner           Salta la animacion de boot"                        -Color Green
    Write-UI "    -Profile <nombre>   Carga un perfil especifico"                        -Color Green
}

Export-ModuleMember -Function Write-UI, Write-Badge, Write-TypeLine, Write-BarAt, `
    Write-LabelAt, Show-BootAnimation, Show-Banner, Show-TopBar, Show-StatusLine, `
    Show-TelemetryPanels, Show-UpdateBanner, Show-MainMenu, Show-Footer, `
    Show-Section, Show-Logs, Show-Config, Show-Help, Confirm-Action, Pause-Submenu, `
    Get-ThemeColor, ConvertTo-ThemeColor
