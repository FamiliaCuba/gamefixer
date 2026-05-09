# ============================================================================
#  modules/SupportReport.psm1
#  Paquete de soporte: recolecta info del sistema, la sanitiza,
#  genera ZIP y lo envia a un webhook de Discord configurado.
# ============================================================================

# Categorias predefinidas de problemas (el usuario puede elegir una + descripcion libre)
$Script:ProblemCategories = @(
    @{ Code='fps-low';       Name='Bajo FPS en juegos' }
    @{ Code='stutter';       Name='Tirones / stuttering / microlag' }
    @{ Code='crash';         Name='Juego se cierra solo / crash' }
    @{ Code='bsod';          Name='Pantalla azul (BSOD)' }
    @{ Code='boot-slow';     Name='Windows tarda en arrancar' }
    @{ Code='temp-high';     Name='Temperaturas altas' }
    @{ Code='net-lag';       Name='Lag/ping alto online' }
    @{ Code='no-audio';      Name='Problemas de audio' }
    @{ Code='no-game-start'; Name='Juego no abre / no arranca' }
    @{ Code='windows-error'; Name='Error de Windows (explicar abajo)' }
    @{ Code='other';         Name='Otro (describir abajo)' }
)

function Invoke-SupportReport {
    <#
    .SYNOPSIS
    Menu principal del generador de reporte de soporte.
    #>
    do {
        Show-Section "REPORTE DE SOPORTE"

        Write-UI "  Genera un paquete con info de tu PC para recibir soporte tecnico." -Color Cyan
        Write-UI "  Se sanitizan datos privados (usuario, MAC, IP, serials) antes de enviar." -Color DarkGray
        Write-Host ""

        $webhookConfigured = Test-SupportWebhookConfigured
        if ($webhookConfigured) {
            Write-UI "  [OK] Discord webhook configurado - los reportes se envian automaticamente" -Color Green
        } else {
            Write-UI "  [!] Sin webhook configurado - los reportes quedan en /reports/ para envio manual" -Color Yellow
        }
        Write-Host ""

        Write-UI "  [1] Generar reporte completo (recomendado)" -Color Yellow
        Write-UI "  [2] Solo info del hardware (rapido, sin logs)" -Color Yellow
        Write-UI "  [3] Auto-diagnostico y sugerencias (sin enviar)" -Color Yellow
        Write-UI "  [4] Ver reportes generados anteriormente" -Color Yellow
        Write-UI "  [5] Configurar Discord webhook (primera vez)" -Color Yellow
        Write-UI "  [6] Test del webhook (verificar que funciona)" -Color Yellow
        Write-UI "  [B] Volver al menu principal" -Color Yellow
        Write-Host ""
        Write-UI "  > " -Color Cyan -NoNewline
        $sub = (Read-Host).Trim().ToUpper()

        switch ($sub) {
            '1' { New-SupportPackage -Full $true;  Pause-Submenu }
            '2' { New-SupportPackage -Full $false; Pause-Submenu }
            '3' { Invoke-AutoDiagnostic;           Pause-Submenu }
            '4' { Show-SupportReports;             Pause-Submenu }
            '5' { Set-SupportWebhook;              Pause-Submenu }
            '6' { Test-SupportWebhook;             Pause-Submenu }
            'B' { return }
            default { }
        }
    } while ($true)
}

# ============================================================================
#  CONFIGURACION DEL WEBHOOK
# ============================================================================

function Test-SupportWebhookConfigured {
    if ($null -eq $Global:GF.Config) { return $false }
    $url = $Global:GF.Config.supportWebhook
    return ($null -ne $url -and $url -like 'https://discord.com/api/webhooks/*')
}

function Set-SupportWebhook {
    Write-Host ""
    Write-UI "=== CONFIGURACION DE DISCORD WEBHOOK ===" -Color Cyan
    Write-Host ""
    Write-UI "  Un webhook te permite recibir reportes en un canal privado de Discord." -Color Green
    Write-UI "  Los usuarios no ven el URL, solo el soporte." -Color Green
    Write-Host ""
    Write-UI "  Como crearlo (si no tienes uno):" -Color Yellow
    Write-UI "    1. Crea un servidor de Discord privado (solo tu)" -Color DarkGray
    Write-UI "    2. Crea un canal llamado #gamefixer-support" -Color DarkGray
    Write-UI "    3. Click derecho en el canal > Editar canal > Integraciones > Webhooks" -Color DarkGray
    Write-UI "    4. Crear webhook > Copiar URL" -Color DarkGray
    Write-UI "    5. Pega el URL aqui abajo" -Color DarkGray
    Write-Host ""
    Write-UI "  URL del webhook (empieza con https://discord.com/api/webhooks/):" -Color Cyan
    Write-UI "  > " -Color Yellow -NoNewline
    $url = (Read-Host).Trim()

    if ($url -eq '') {
        Write-UI "  Cancelado (sin cambios)" -Color Yellow
        return
    }

    if ($url -notlike 'https://discord.com/api/webhooks/*') {
        Write-UI "  [X] URL invalida. Debe empezar con 'https://discord.com/api/webhooks/'" -Color Red
        return
    }

    # Guardar en config.json
    try {
        if ($null -eq $Global:GF.Config.PSObject.Properties['supportWebhook']) {
            $Global:GF.Config | Add-Member -NotePropertyName 'supportWebhook' -NotePropertyValue $url -Force
        } else {
            $Global:GF.Config.supportWebhook = $url
        }
        Save-Config | Out-Null
        Write-UI "  [OK] Webhook guardado en config.json" -Color Green
        Write-UI "  Podes probarlo con la opcion [6] del menu" -Color DarkGreen
    } catch {
        Write-UI ("  [X] Error guardando: " + $_.Exception.Message) -Color Red
    }
}

function Test-SupportWebhook {
    if (-not (Test-SupportWebhookConfigured)) {
        Write-Host ""
        Write-UI "  [!] No hay webhook configurado. Usa la opcion [5] primero." -Color Yellow
        return
    }

    Write-Host ""
    Write-UI "  Enviando mensaje de prueba a Discord..." -Color Cyan

    $payload = @{
        username = "GameFixer Support"
        embeds = @(
            @{
                title = "Test de conexion"
                description = "Si ves este mensaje, el webhook funciona correctamente."
                color = 3066993  # verde
                fields = @(
                    @{ name = "Usuario"; value = "$($Global:GF.User)@$($Global:GF.Hostname)"; inline = $true }
                    @{ name = "GameFixer"; value = $Global:GF.Version; inline = $true }
                    @{ name = "Fecha"; value = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'); inline = $true }
                )
                footer = @{ text = "GameFixer Support Bot" }
            }
        )
    } | ConvertTo-Json -Depth 5

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $resp = Invoke-WebRequest -Uri $Global:GF.Config.supportWebhook -Method POST `
            -Body $payload -ContentType 'application/json' -UseBasicParsing -TimeoutSec 15
        if ($resp.StatusCode -in 200, 204) {
            Write-UI "  [OK] Webhook funciona. Revisa tu Discord." -Color Green
            if (Test-SoundEnabled) { Play-SuccessChime }
        } else {
            Write-UI ("  [!] Respuesta inesperada: " + $resp.StatusCode) -Color Yellow
        }
    } catch {
        Write-UI ("  [X] Error: " + $_.Exception.Message) -Color Red
        Write-UI "  Verifica que el URL del webhook sea correcto" -Color DarkGray
    }
}

# ============================================================================
#  GENERACION DEL PAQUETE DE SOPORTE
# ============================================================================

function New-SupportPackage {
    param([bool]$Full = $true)

    Write-Host ""
    Write-UI "=== GENERANDO REPORTE DE SOPORTE ===" -Color Cyan
    Write-Host ""

    # Paso 1: Pedir descripcion del problema
    $problem = Get-ProblemDescription
    if (-not $problem) {
        Write-UI "  Cancelado" -Color Yellow
        return
    }

    # Paso 2: Generar ID de soporte
    $supportId = New-SupportId
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $reportDir = Join-Path $Global:GF.Root "reports\support_$supportId"
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }

    Write-UI ("  ID de soporte: " + $supportId) -Color Green
    Write-UI ("  Carpeta: " + $reportDir) -Color DarkGray
    Write-Host ""

    # Paso 3: Colectar informacion
    Write-UI "  [1/7] Recolectando info de hardware..." -Color Cyan
    $hardware = Get-HardwareInfo
    $hardware | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $reportDir 'hardware.json') -Encoding UTF8

    Write-UI "  [2/7] Recolectando info de Windows..." -Color Cyan
    $windows = Get-WindowsInfo
    $windows | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $reportDir 'windows.json') -Encoding UTF8

    Write-UI "  [3/7] Recolectando drivers y servicios..." -Color Cyan
    $drivers = Get-DriversInfo
    $drivers | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $reportDir 'drivers.json') -Encoding UTF8

    Write-UI "  [4/7] Recolectando config de red y gaming..." -Color Cyan
    $gaming = Get-GamingConfigInfo
    $gaming | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $reportDir 'gaming.json') -Encoding UTF8

    if ($Full) {
        Write-UI "  [5/7] Recolectando eventos de Windows (ultimos 7 dias)..." -Color Cyan
        $events = Get-RecentEvents
        $events | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $reportDir 'events.json') -Encoding UTF8

        Write-UI "  [6/7] Copiando logs de GameFixer..." -Color Cyan
        $logsDir = Join-Path $reportDir 'gamefixer-logs'
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
        $recentLogs = Get-ChildItem (Join-Path $Global:GF.Root 'logs') -Filter '*.log' -ErrorAction SilentlyContinue |
                      Sort-Object LastWriteTime -Descending | Select-Object -First 5
        foreach ($log in $recentLogs) {
            Copy-Item $log.FullName -Destination $logsDir
        }
    } else {
        Write-UI "  [5/7] Eventos Windows: omitido (modo rapido)" -Color DarkGray
        Write-UI "  [6/7] Logs GameFixer: omitido (modo rapido)" -Color DarkGray
    }

    Write-UI "  [7/7] Ejecutando auto-diagnostico..." -Color Cyan
    $diagnostic = Get-AutoDiagnostic -Hardware $hardware -Gaming $gaming -Drivers $drivers
    $diagnostic | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $reportDir 'diagnostic.json') -Encoding UTF8

    # Paso 4: Crear manifest con resumen
    $manifest = [ordered]@{
        SupportId    = $supportId
        Generated    = $timestamp
        GameFixerVer = $Global:GF.Version
        FullReport   = $Full
        Problem      = $problem
        Diagnostic   = @{
            IssuesFound = $diagnostic.Issues.Count
            WarningsFound = $diagnostic.Warnings.Count
        }
        Summary = @{
            CPU    = $hardware.CPU.Name
            GPU    = $hardware.GPU.Name
            RAM    = ("{0} GB" -f $hardware.RAM.TotalGB)
            OS     = $windows.OSVersion
            Drives = $hardware.Disks.Count
        }
    }
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $reportDir 'manifest.json') -Encoding UTF8

    # Paso 5: Crear README humano-legible
    $readme = @"
===========================================================
  GAMEFIXER SUPPORT REPORT
===========================================================

ID de soporte : $supportId
Generado      : $timestamp
GameFixer     : $($Global:GF.Version)

--- RESUMEN ---
CPU     : $($hardware.CPU.Name)
GPU     : $($hardware.GPU.Name)
RAM     : $($hardware.RAM.TotalGB) GB
OS      : $($windows.OSVersion)
Discos  : $($hardware.Disks.Count)

--- PROBLEMA REPORTADO ---
Categoria : $($problem.Category)
Descripcion:
$($problem.Description)

--- AUTO-DIAGNOSTICO ---
Problemas detectados: $($diagnostic.Issues.Count)
Advertencias       : $($diagnostic.Warnings.Count)

$(foreach ($i in $diagnostic.Issues) { "[!] $($i.Title): $($i.Detail)`n    Sugerencia: $($i.Suggestion)`n" })

--- ARCHIVOS INCLUIDOS ---
- manifest.json       : Resumen y metadata
- hardware.json       : Specs de CPU, GPU, RAM, discos
- windows.json        : Version de Windows, build, features
- drivers.json        : Drivers instalados y versiones
- gaming.json         : Config de red, servicios, plan de energia
- diagnostic.json     : Auto-diagnostico con sugerencias
$(if ($Full) { "- events.json         : Errores de Event Viewer (ultimos 7 dias)`n- gamefixer-logs/     : Logs de sesiones anteriores" })

--- DATOS SANITIZADOS (NO SE INCLUYEN) ---
- Nombre de usuario de Windows
- Nombre de la PC
- Direcciones MAC
- Serials de discos
- IP publica

===========================================================
Enviar este ZIP completo a tu soporte tecnico, o mencionar
el ID de soporte: $supportId
===========================================================
"@
    $readme | Set-Content -Path (Join-Path $reportDir 'README.txt') -Encoding UTF8

    # Paso 6: Comprimir en ZIP
    $zipPath = Join-Path $Global:GF.Root "reports\SupportPackage_$($supportId)_$timestamp.zip"
    try {
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
        Compress-Archive -Path "$reportDir\*" -DestinationPath $zipPath -Force
        $zipSizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
        Write-UI ("  [OK] Paquete creado: " + $zipPath) -Color Green
        Write-UI ("       Tamaño: $zipSizeMB MB") -Color DarkGray
    } catch {
        Write-UI ("  [X] Error comprimiendo: " + $_.Exception.Message) -Color Red
        return
    }

    # Paso 7: Mostrar diagnostico en pantalla antes de enviar
    Write-Host ""
    Show-DiagnosticSummary -Diagnostic $diagnostic

    # Paso 8: Enviar a Discord si esta configurado
    Write-Host ""
    if (Test-SupportWebhookConfigured) {
        Write-UI "  Enviando reporte detallado a Discord (5-6 mensajes)..." -Color Cyan
        $sent = Send-SupportToDiscord -ZipPath $zipPath -Manifest $manifest `
            -Diagnostic $diagnostic -Problem $problem `
            -Hardware $hardware -Windows $windows `
            -Drivers $drivers -Gaming $gaming
        if ($sent) {
            Write-UI "  [OK] Reporte enviado al soporte tecnico" -Color Green
            Write-UI ("  Tu ID de soporte: " + $supportId) -Color Cyan
            Write-UI "  Comparte este ID al comunicarte con el soporte" -Color DarkGray
        } else {
            Write-UI "  [!] Algunos mensajes fallaron, el ZIP esta disponible localmente" -Color Yellow
        }
    } else {
        Write-UI "  [!] Sin webhook configurado: el ZIP esta en /reports/" -Color Yellow
        Write-UI ("  Podes enviarlo manualmente. ID: " + $supportId) -Color Cyan
    }

    Write-Log -Level INFO -Message "Support report generado: $supportId"
}

function New-SupportId {
    # Formato: GF-XXXX-XXXX (16 chars total, legible en voz)
    $chars = '23456789ABCDEFGHJKMNPQRSTUVWXYZ'  # sin 0/O, 1/I/L para evitar confusion
    $rng = New-Object Random
    $part1 = -join (1..4 | ForEach-Object { $chars[$rng.Next(0, $chars.Length)] })
    $part2 = -join (1..4 | ForEach-Object { $chars[$rng.Next(0, $chars.Length)] })
    return "GF-$part1-$part2"
}

function Get-ProblemDescription {
    Write-Host ""
    Write-UI "  Que tipo de problema estas experimentando?" -Color Cyan
    Write-Host ""
    for ($i = 0; $i -lt $Script:ProblemCategories.Count; $i++) {
        $cat = $Script:ProblemCategories[$i]
        Write-UI ("    [{0,2}] {1}" -f ($i + 1), $cat.Name) -Color Yellow
    }
    Write-UI "    [B] Cancelar" -Color DarkGray
    Write-Host ""
    Write-UI "  > Numero: " -Color Cyan -NoNewline
    $sel = (Read-Host).Trim().ToUpper()
    if ($sel -eq 'B') { return $null }

    $idx = 0
    if (-not [int]::TryParse($sel, [ref]$idx) -or $idx -lt 1 -or $idx -gt $Script:ProblemCategories.Count) {
        Write-UI "  Seleccion invalida" -Color Red
        Start-Sleep -Seconds 1
        return $null
    }
    $category = $Script:ProblemCategories[$idx - 1]

    Write-Host ""
    Write-UI "  Describe el problema con tus palabras (opcional pero recomendado):" -Color Cyan
    Write-UI "  Ej: 'Warzone me da 40fps cuando antes tenia 120, pasa desde el update de ayer'" -Color DarkGray
    Write-UI "  > " -Color Yellow -NoNewline
    $description = (Read-Host).Trim()

    return @{
        Category      = $category.Name
        CategoryCode  = $category.Code
        Description   = if ($description) { $description } else { '(sin descripcion)' }
    }
}

# ============================================================================
#  COLECTORES DE INFO (sanitizan datos sensibles)
# ============================================================================

function ConvertTo-SanitizedString {
    param([string]$Text)
    if (-not $Text) { return '' }
    # Username -> USER
    $Text = $Text -replace [regex]::Escape($env:USERNAME), 'USER'
    $Text = $Text -replace [regex]::Escape($env:COMPUTERNAME), 'PCNAME'
    # MAC addresses
    $Text = $Text -replace '([0-9A-F]{2}[:-]){5}[0-9A-F]{2}', 'XX:XX:XX:XX:XX:XX'
    # IPs privadas y publicas (pero preservar loopback)
    $Text = $Text -replace '\b(?!127\.0\.0\.1)(?:\d{1,3}\.){3}\d{1,3}\b', 'X.X.X.X'
    return $Text
}

function Get-HardwareInfo {
    $info = [ordered]@{}

    # CPU
    try {
        $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
        $info.CPU = [ordered]@{
            Name              = $cpu.Name.Trim()
            Cores             = $cpu.NumberOfCores
            LogicalProcessors = $cpu.NumberOfLogicalProcessors
            MaxClockGHz       = [math]::Round($cpu.MaxClockSpeed / 1000, 2)
            CurrentClockMHz   = $cpu.CurrentClockSpeed
            Manufacturer      = $cpu.Manufacturer
            Socket            = $cpu.SocketDesignation
            L2CacheKB         = $cpu.L2CacheSize
            L3CacheKB         = $cpu.L3CacheSize
            Virtualization    = $cpu.VirtualizationFirmwareEnabled
        }

        # Carga actual
        try {
            $loadPct = (Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average
            $info.CPU.CurrentLoadPercent = [int]$loadPct
        } catch {}
    } catch { $info.CPU = @{ Error = $_.Exception.Message } }

    # GPU (todas + principal)
    try {
        $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
        $mainGpu = $gpus | Where-Object { $_.Name -notmatch 'Microsoft Basic|Remote' } | Select-Object -First 1
        if (-not $mainGpu) { $mainGpu = $gpus[0] }

        $vram = if (Get-Command Get-GPUVRam -ErrorAction SilentlyContinue) {
            Get-GPUVRam -GpuName $mainGpu.Name -Fallback $mainGpu.AdapterRAM
        } else { [math]::Round($mainGpu.AdapterRAM / 1GB, 1) }

        $info.GPU = [ordered]@{
            Name             = $mainGpu.Name
            DriverVersion    = $mainGpu.DriverVersion
            DriverDate       = if ($mainGpu.DriverDate) { $mainGpu.DriverDate.ToString('yyyy-MM-dd') } else { $null }
            VRAMGB           = $vram
            CurrentH         = $mainGpu.CurrentHorizontalResolution
            CurrentV         = $mainGpu.CurrentVerticalResolution
            RefreshRate      = $mainGpu.CurrentRefreshRate
            AllGPUs          = @($gpus | ForEach-Object { $_.Name })
        }

        # Stats en vivo de NVIDIA si esta disponible
        if (Get-Command 'nvidia-smi' -ErrorAction SilentlyContinue) {
            try {
                $nvStats = & nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw,fan.speed --format=csv,noheader,nounits 2>$null
                if ($nvStats) {
                    $parts = $nvStats -split ','
                    $info.GPU.LiveTempC      = [int]$parts[0].Trim()
                    $info.GPU.LiveUsagePct   = [int]$parts[1].Trim()
                    $info.GPU.VRAMUsedMB     = [int]$parts[2].Trim()
                    $info.GPU.VRAMTotalMB    = [int]$parts[3].Trim()
                    $info.GPU.PowerDrawW     = if ($parts[4].Trim() -eq '[N/A]') { $null } else { [double]$parts[4].Trim() }
                    $info.GPU.FanSpeedPct    = if ($parts[5].Trim() -eq '[N/A]') { $null } else { [int]$parts[5].Trim() }
                }
            } catch {}
        }
    } catch { $info.GPU = @{ Error = $_.Exception.Message } }

    # RAM
    try {
        $mem = Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $totalGB = [math]::Round(($mem | Measure-Object Capacity -Sum).Sum / 1GB, 1)
        $freeGB = if ($os) { [math]::Round($os.FreePhysicalMemory / 1MB, 1) } else { 0 }
        $info.RAM = [ordered]@{
            TotalGB = $totalGB
            FreeGB  = $freeGB
            UsedGB  = [math]::Round($totalGB - $freeGB, 1)
            UsedPercent = if ($totalGB -gt 0) { [int](($totalGB - $freeGB) / $totalGB * 100) } else { 0 }
            Modules = @($mem | ForEach-Object {
                @{
                    SizeGB        = [math]::Round($_.Capacity / 1GB, 1)
                    SpeedMHz      = $_.Speed
                    Manufacturer  = $_.Manufacturer
                    PartNumber    = if ($_.PartNumber) { $_.PartNumber.Trim() } else { $null }
                    FormFactor    = switch ($_.FormFactor) { 8 {'DIMM'} 12 {'SODIMM'} default {[string]$_.FormFactor} }
                    MemoryType    = switch ($_.SMBIOSMemoryType) { 26 {'DDR4'} 34 {'DDR5'} 24 {'DDR3'} default {'Other'} }
                }
            })
        }
    } catch { $info.RAM = @{ Error = $_.Exception.Message } }

    # Discos con uso (sanitiza serial)
    try {
        $info.Disks = @()
        $physical = @(Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue)
        $logical = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue)

        foreach ($ld in $logical) {
            $sizeGB = [math]::Round($ld.Size / 1GB, 1)
            $freeGB = [math]::Round($ld.FreeSpace / 1GB, 1)
            $usedPct = if ($ld.Size -gt 0) { [int](($ld.Size - $ld.FreeSpace) / $ld.Size * 100) } else { 0 }

            # Detectar tipo (SSD/HDD) via MSFT_PhysicalDisk
            $mediaType = 'Unknown'
            try {
                $part = Get-Partition -DriveLetter $ld.DeviceID[0] -ErrorAction SilentlyContinue
                if ($part) {
                    $pdisk = Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DeviceId -eq $part.DiskNumber }
                    if ($pdisk) {
                        $mediaType = [string]$pdisk.MediaType
                        if ($pdisk.BusType -eq 'NVMe') { $mediaType = 'NVMe SSD' }
                    }
                }
            } catch {}

            $info.Disks += [ordered]@{
                Drive       = $ld.DeviceID
                SizeGB      = $sizeGB
                FreeGB      = $freeGB
                UsedPercent = $usedPct
                FileSystem  = $ld.FileSystem
                MediaType   = $mediaType
                VolumeName  = if ($ld.VolumeName) { $ld.VolumeName } else { '(sin etiqueta)' }
            }
        }

        # Info de los drives fisicos (modelo, sin serial)
        $info.PhysicalDisks = @(
            $physical | ForEach-Object {
                [ordered]@{
                    Model         = $_.Model.Trim()
                    SizeGB        = [math]::Round($_.Size / 1GB, 0)
                    InterfaceType = $_.InterfaceType
                    Partitions    = $_.Partitions
                    # NO SerialNumber
                }
            }
        )
    } catch { $info.Disks = @() }

    # Placa madre
    try {
        $board = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
        $info.Motherboard = [ordered]@{
            Manufacturer = $board.Manufacturer
            Product      = $board.Product
            Version      = $board.Version
        }
    } catch { $info.Motherboard = @{} }

    # BIOS
    try {
        $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
        $info.BIOS = [ordered]@{
            Manufacturer = $bios.Manufacturer
            Version      = $bios.Version
            SMBIOSVersion = $bios.SMBIOSBIOSVersion
            ReleaseDate  = if ($bios.ReleaseDate) { $bios.ReleaseDate.ToString('yyyy-MM-dd') } else { $null }
        }
    } catch { $info.BIOS = @{} }

    # Monitores
    try {
        $info.Monitors = @(
            Get-CimInstance WmiMonitorID -Namespace 'root/wmi' -ErrorAction SilentlyContinue | ForEach-Object {
                $mfg = if ($_.ManufacturerName) { [System.Text.Encoding]::ASCII.GetString($_.ManufacturerName).Trim(([char]0)) } else { '' }
                $name = if ($_.UserFriendlyName) { [System.Text.Encoding]::ASCII.GetString($_.UserFriendlyName).Trim(([char]0)) } else { '' }
                [ordered]@{
                    Manufacturer = $mfg
                    Name = $name
                    YearOfManufacture = $_.YearOfManufacture
                }
            }
        )
    } catch { $info.Monitors = @() }

    return $info
}

function Get-WindowsInfo {
    $info = [ordered]@{}

    # Version base del OS
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $info.OSVersion       = $os.Caption
        $info.OSBuild         = $os.BuildNumber
        $info.OSArchitecture  = $os.OSArchitecture
        $info.InstallDate     = if ($os.InstallDate) { $os.InstallDate.ToString('yyyy-MM-dd') } else { $null }
        $info.LastBootUpTime  = if ($os.LastBootUpTime) { $os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm') } else { $null }
        $info.UptimeHours     = if ($os.LastBootUpTime) { [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalHours, 1) } else { 0 }
        $info.SystemDir       = $os.SystemDirectory
        $info.Language        = $os.OSLanguage
    } catch {}

    # Feature update y release
    try {
        $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
        $info.DisplayVersion    = $cv.DisplayVersion       # ej: '23H2'
        $info.ReleaseId         = $cv.ReleaseId
        $info.UBR               = $cv.UBR
        $info.EditionID         = $cv.EditionID            # Pro, Home, etc
        $info.ProductName       = $cv.ProductName
        $info.CurrentBuild      = $cv.CurrentBuild
    } catch {}

    # Region, idioma, teclado
    try {
        $info.Locale        = (Get-Culture).Name
        $info.TimeZone      = (Get-TimeZone).Id
        $info.KeyboardLayout = (Get-WinUserLanguageList -ErrorAction SilentlyContinue)[0].InputMethodTips -join ','
    } catch {}

    # Features de gaming en registro
    try {
        $info.GameBar        = Get-RegValueSafe 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled'
        $info.GameDVR        = Get-RegValueSafe 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled'
        $info.HAGS           = Get-RegValueSafe 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode'
        $info.SystemResp     = Get-RegValueSafe 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'SystemResponsiveness'
        $info.FullscreenOpts = Get-RegValueSafe 'HKCU:\System\GameConfigStore' 'GameDVR_FSEBehaviorMode'
        $info.MouseAccel     = Get-RegValueSafe 'HKCU:\Control Panel\Mouse' 'MouseSpeed'
    } catch {}

    # === SEGURIDAD ===
    $info.Security = Get-WindowsSecurityInfo
    $info.TPM      = Get-TPMInfo
    $info.Defender = Get-DefenderInfo
    $info.Firewall = Get-FirewallInfo
    $info.BitLocker = Get-BitLockerInfo
    $info.UAC      = Get-UACInfo

    # === ACTUALIZACIONES ===
    $info.Updates = Get-WindowsUpdatesInfo

    # === VIRTUALIZACION Y BOOT ===
    $info.Boot = Get-BootInfo

    # === POLITICAS Y RESTRICCIONES ===
    $info.Policies = Get-WindowsPoliciesInfo

    return $info
}

function Get-WindowsSecurityInfo {
    $sec = [ordered]@{}
    try {
        # Secure Boot
        $sec.SecureBootEnabled = try {
            (Confirm-SecureBootUEFI -ErrorAction SilentlyContinue) -eq $true
        } catch { $null }

        # UEFI vs Legacy BIOS
        try {
            $firmware = Get-CimInstance -Namespace 'root\cimv2\security\microsofttpm' -ClassName Win32_Tpm -ErrorAction SilentlyContinue
            $sec.FirmwareType = if ($env:firmware_type) { $env:firmware_type } else { 'Unknown' }
        } catch {}

        # Virtualization Based Security (VBS)
        try {
            $vbs = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
            if ($vbs) {
                $sec.VBS_Running             = ($vbs.SecurityServicesRunning -contains 1)
                $sec.VBS_Configured          = ($vbs.SecurityServicesConfigured -contains 1)
                $sec.HVCI_Running            = ($vbs.SecurityServicesRunning -contains 2)
                $sec.CredentialGuardRunning  = ($vbs.SecurityServicesRunning -contains 3)
            }
        } catch {}

        # Memory Integrity (Core Isolation)
        try {
            $mi = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -ErrorAction SilentlyContinue
            $sec.MemoryIntegrityEnabled = ($mi.Enabled -eq 1)
        } catch {}

        # SmartScreen
        try {
            $ss = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -ErrorAction SilentlyContinue
            $sec.SmartScreenAppCheck = $ss.SmartScreenEnabled
        } catch {}

    } catch {}
    return $sec
}

function Get-TPMInfo {
    $tpm = [ordered]@{}
    try {
        $t = Get-Tpm -ErrorAction SilentlyContinue
        if ($t) {
            $tpm.Present         = $t.TpmPresent
            $tpm.Ready           = $t.TpmReady
            $tpm.Enabled         = $t.TpmEnabled
            $tpm.Activated       = $t.TpmActivated
            $tpm.Owned           = $t.TpmOwned
            $tpm.ManufacturerId  = $t.ManufacturerId
            $tpm.ManufacturerVersion = $t.ManufacturerVersion
            $tpm.AutoProvisioning = $t.AutoProvisioning
        } else {
            $tpm.Present = $false
        }
    } catch {
        $tpm.Error = $_.Exception.Message
    }
    return $tpm
}

function Get-DefenderInfo {
    $def = [ordered]@{}
    try {
        $status = Get-MpComputerStatus -ErrorAction SilentlyContinue
        if ($status) {
            $def.AntivirusEnabled            = $status.AntivirusEnabled
            $def.AntispywareEnabled          = $status.AntispywareEnabled
            $def.RealTimeProtectionEnabled   = $status.RealTimeProtectionEnabled
            $def.BehaviorMonitorEnabled      = $status.BehaviorMonitorEnabled
            $def.TamperProtected             = $status.IsTamperProtected
            $def.AMEngineVersion             = $status.AMEngineVersion
            $def.AntivirusSignatureVersion   = $status.AntivirusSignatureVersion
            $def.AntivirusSignatureAge       = $status.AntivirusSignatureAge
            $def.LastQuickScan               = if ($status.QuickScanEndTime) { $status.QuickScanEndTime.ToString('yyyy-MM-dd') } else { 'Nunca' }
            $def.LastFullScan                = if ($status.FullScanEndTime) { $status.FullScanEndTime.ToString('yyyy-MM-dd') } else { 'Nunca' }
            $def.QuickScanAgeDays            = $status.QuickScanAge
        }

        # Prefs de Defender
        $pref = Get-MpPreference -ErrorAction SilentlyContinue
        if ($pref) {
            $def.DisableRealtimeMonitoring   = $pref.DisableRealtimeMonitoring
            $def.ExclusionPath_Count         = @($pref.ExclusionPath).Count
            $def.ExclusionProcess_Count      = @($pref.ExclusionProcess).Count
        }

        # Detectar antivirus de terceros
        try {
            $avs = @(Get-CimInstance -Namespace 'root\SecurityCenter2' -ClassName 'AntiVirusProduct' -ErrorAction SilentlyContinue |
                     ForEach-Object { $_.displayName })
            $def.ThirdPartyAV = $avs
        } catch {}

    } catch {
        $def.Error = $_.Exception.Message
    }
    return $def
}

function Get-FirewallInfo {
    $fw = [ordered]@{}
    try {
        $profiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue
        foreach ($p in $profiles) {
            $fw[$p.Name] = [ordered]@{
                Enabled = $p.Enabled
                DefaultInboundAction = [string]$p.DefaultInboundAction
                DefaultOutboundAction = [string]$p.DefaultOutboundAction
            }
        }
    } catch {
        $fw.Error = $_.Exception.Message
    }
    return $fw
}

function Get-BitLockerInfo {
    $bl = [ordered]@{}
    try {
        $volumes = Get-BitLockerVolume -ErrorAction SilentlyContinue
        if ($volumes) {
            $bl.Volumes = @($volumes | ForEach-Object {
                [ordered]@{
                    MountPoint         = $_.MountPoint
                    EncryptionMethod   = [string]$_.EncryptionMethod
                    ProtectionStatus   = [string]$_.ProtectionStatus
                    VolumeStatus       = [string]$_.VolumeStatus
                    EncryptionPercent  = $_.EncryptionPercentage
                }
            })
        } else {
            $bl.Volumes = @()
            $bl.Note = 'BitLocker no configurado o no disponible'
        }
    } catch {
        $bl.Error = $_.Exception.Message
    }
    return $bl
}

function Get-UACInfo {
    $uac = [ordered]@{}
    try {
        $k = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
        $uac.Enabled             = (Get-RegValueSafe $k 'EnableLUA') -eq 1
        $uac.ConsentPromptAdmin  = Get-RegValueSafe $k 'ConsentPromptBehaviorAdmin'
        $uac.ConsentPromptUser   = Get-RegValueSafe $k 'ConsentPromptBehaviorUser'
        $uac.PromptOnSecureDesk  = Get-RegValueSafe $k 'PromptOnSecureDesktop'
    } catch {}
    return $uac
}

function Get-WindowsUpdatesInfo {
    $upd = [ordered]@{}
    try {
        # Estado del servicio
        $wu = Get-Service -Name 'wuauserv' -ErrorAction SilentlyContinue
        if ($wu) {
            $upd.ServiceStatus = [string]$wu.Status
            $upd.ServiceStartType = [string]$wu.StartType
        }

        # Ultimas actualizaciones instaladas (via WMI rapido)
        $session = New-Object -ComObject Microsoft.Update.Session -ErrorAction SilentlyContinue
        if ($session) {
            $searcher = $session.CreateUpdateSearcher()
            $total = $searcher.GetTotalHistoryCount()
            if ($total -gt 0) {
                $history = $searcher.QueryHistory(0, [math]::Min($total, 10))
                $upd.RecentUpdates = @($history | ForEach-Object {
                    [ordered]@{
                        Title  = $_.Title
                        Date   = if ($_.Date) { $_.Date.ToString('yyyy-MM-dd') } else { $null }
                        Result = switch ($_.ResultCode) { 1 {'InProgress'} 2 {'Succeeded'} 3 {'SucceededWithErrors'} 4 {'Failed'} 5 {'Aborted'} default {'Unknown'} }
                    }
                })
                $upd.LastUpdate = if ($upd.RecentUpdates[0]) { $upd.RecentUpdates[0].Date } else { $null }
            }
        }

        # Pending reboot?
        $upd.PendingReboot = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
                             (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
    } catch {
        $upd.Error = $_.Exception.Message
    }
    return $upd
}

function Get-BootInfo {
    $boot = [ordered]@{}
    try {
        # Fast Startup
        $fs = Get-RegValueSafe 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled'
        $boot.FastStartupEnabled = ($fs -eq 1)

        # Hibernation
        $boot.HibernationEnabled = Test-Path "$env:SystemDrive\hiberfil.sys"

        # Page file
        $pageFile = Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($pageFile) {
            $boot.PageFileLocation = $pageFile.Name
            $boot.PageFileSizeMB   = $pageFile.AllocatedBaseSize
        }

        # Autostart entries (top 20)
        $boot.AutoStartCount = @(Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue).Count

        # Core count detectado
        $boot.LogicalProcessors = [Environment]::ProcessorCount
    } catch {}
    return $boot
}

function Get-WindowsPoliciesInfo {
    $pol = [ordered]@{}
    try {
        # Remote Desktop
        $pol.RDP_Enabled = (Get-RegValueSafe 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections') -eq 0

        # Windows telemetry level
        $pol.TelemetryLevel = Get-RegValueSafe 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry'

        # Cortana
        $pol.CortanaDisabled = (Get-RegValueSafe 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCortana') -eq 0

        # OneDrive
        $pol.OneDriveDisabled = (Get-RegValueSafe 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' 'DisableFileSyncNGSC') -eq 1
    } catch {}
    return $pol
}

function Get-DriversInfo {
    $info = [ordered]@{}

    # NVIDIA
    if (Get-Command 'nvidia-smi' -ErrorAction SilentlyContinue) {
        try {
            $nvOutput = & nvidia-smi --query-gpu=driver_version,name,memory.total --format=csv,noheader 2>$null
            $info.NVIDIA = @{ Output = $nvOutput }
        } catch {}
    }

    # Drivers de sistema (top 30 mas recientes)
    try {
        $info.RecentDrivers = @(Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
            Where-Object { $_.DriverDate -ne $null } |
            Sort-Object DriverDate -Descending |
            Select-Object -First 30 |
            ForEach-Object {
                [ordered]@{
                    Name      = $_.DeviceName
                    Version   = $_.DriverVersion
                    Date      = $_.DriverDate
                    Manufacturer = $_.Manufacturer
                }
            })
    } catch {}

    # Servicios criticos para gaming
    try {
        $criticalServices = @('XblAuthManager','XblGameSave','XboxGipSvc','XboxNetApiSvc','Steam Client Service',
                              'NVDisplay.ContainerLocalSystem','nvsvc','AMD External Events Utility',
                              'DPS','DiagTrack','WSearch','SysMain','Themes','AudioSrv')
        $info.Services = @(Get-Service -ErrorAction SilentlyContinue |
            Where-Object { $criticalServices -contains $_.Name -or $_.DisplayName -match 'NVIDIA|AMD|Intel Graphics' } |
            ForEach-Object {
                [ordered]@{
                    Name = $_.Name
                    DisplayName = $_.DisplayName
                    Status = [string]$_.Status
                    StartType = [string]$_.StartType
                }
            })
    } catch {}

    return $info
}

function Get-GamingConfigInfo {
    $info = [ordered]@{}

    # Plan de energia
    try {
        $scheme = (powercfg /getactivescheme 2>$null | Out-String).Trim()
        if ($scheme -match '\(([^)]+)\)') {
            $info.PowerPlan = $matches[1]
        } else {
            $info.PowerPlan = $scheme
        }

        # Todos los planes disponibles
        $allPlans = (powercfg /list 2>$null | Out-String) -split "`n" |
                    Where-Object { $_ -match '\(([^)]+)\)' } |
                    ForEach-Object { $matches[1] }
        $info.AvailablePowerPlans = @($allPlans)
    } catch {}

    # DNS configurado (sanitizado pero util)
    try {
        $dnsConfig = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                     Where-Object { $_.ServerAddresses.Count -gt 0 } |
                     Select-Object -First 1
        if ($dnsConfig) {
            $info.DNS = @{
                Servers = @($dnsConfig.ServerAddresses)
                Interface = $dnsConfig.InterfaceAlias
                # Identificar DNS populares
                Provider = switch -Regex ($dnsConfig.ServerAddresses[0]) {
                    '^1\.1\.1\.1' { 'Cloudflare' }
                    '^1\.0\.0\.1' { 'Cloudflare' }
                    '^8\.8\.8\.8' { 'Google' }
                    '^8\.8\.4\.4' { 'Google' }
                    '^9\.9\.9\.9' { 'Quad9' }
                    '^208\.67\.' { 'OpenDNS' }
                    '^192\.168\.' { 'Router local' }
                    default { 'ISP / Otro' }
                }
            }
        }
    } catch {}

    # Adaptadores de red (detallado, sin MAC)
    try {
        $info.NetAdapters = @(Get-NetAdapter -ErrorAction SilentlyContinue |
            Where-Object { $_.Status -eq 'Up' } |
            ForEach-Object {
                [ordered]@{
                    Name = $_.Name
                    InterfaceDescription = $_.InterfaceDescription
                    LinkSpeed = $_.LinkSpeed
                    MediaType = $_.MediaType
                    MediaConnectionState = [string]$_.MediaConnectionState
                }
            })
    } catch {}

    # Conexion a internet: ping a Google/Cloudflare para latencia
    try {
        $pings = Test-Connection -ComputerName '1.1.1.1' -Count 3 -ErrorAction SilentlyContinue
        if ($pings) {
            $avgMs = [int]($pings | Measure-Object ResponseTime -Average).Average
            $info.InternetLatency = @{
                CloudflareMs = $avgMs
                Quality = if ($avgMs -lt 20) { 'Excelente' } elseif ($avgMs -lt 50) { 'Bueno' } elseif ($avgMs -lt 100) { 'Aceptable' } else { 'Alto' }
            }
        }
    } catch {}

    # TCP settings relevantes para gaming
    try {
        $tcpGlobal = Get-NetTCPSetting -SettingName Internet -ErrorAction SilentlyContinue
        if ($tcpGlobal) {
            $info.TCPSettings = @{
                AutoTuningLevelLocal = [string]$tcpGlobal.AutoTuningLevelLocal
                CongestionProvider = [string]$tcpGlobal.CongestionProvider
                EcnCapability = [string]$tcpGlobal.EcnCapability
            }
        }
    } catch {}

    # Nagle's algorithm (afecta latencia en juegos)
    try {
        $interfaces = Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' -ErrorAction SilentlyContinue
        $nagleDisabled = 0
        $totalInterfaces = 0
        foreach ($i in $interfaces) {
            $totalInterfaces++
            $p = Get-ItemProperty $i.PSPath -ErrorAction SilentlyContinue
            if ($p.TcpAckFrequency -eq 1 -and $p.TCPNoDelay -eq 1) {
                $nagleDisabled++
            }
        }
        $info.NagleDisabled = @{
            Count = $nagleDisabled
            Total = $totalInterfaces
        }
    } catch {}

    # Launchers gaming instalados
    if (Get-Command Get-InstalledLaunchers -ErrorAction SilentlyContinue) {
        try {
            $info.GamingLaunchers = @((Get-InstalledLaunchers) | ForEach-Object { $_.Name })
        } catch {}
    }

    # Procesos consumiendo RAM (top 15)
    try {
        $info.TopProcesses = @(Get-Process -ErrorAction SilentlyContinue |
            Where-Object { $_.WorkingSet64 -gt 50MB } |
            Sort-Object WorkingSet64 -Descending |
            Select-Object -First 15 |
            ForEach-Object {
                [ordered]@{
                    Name = $_.ProcessName
                    RAM_MB = [int]($_.WorkingSet64 / 1MB)
                    CPU_Sec = [math]::Round($_.CPU, 1)
                }
            })
    } catch {}

    # Overlays / anticheats detectados (que pueden afectar FPS)
    try {
        $overlaysActivos = @()
        $overlayProcs = @('DiscordOverlay','NahimicService','Rivatuner','RTSSHooks','MSIAfterburner',
                          'NVIDIA Share','GeForce Experience','EAAntiCheat','BEService','vgc',
                          'FACEIT','EasyAntiCheat','Razer Cortex','Logi Overlay')
        foreach ($pn in $overlayProcs) {
            $p = Get-Process -Name $pn -ErrorAction SilentlyContinue
            if ($p) { $overlaysActivos += $pn }
        }
        $info.OverlaysYAnticheats = $overlaysActivos
    } catch {}

    # Apps instaladas (solo nombres, sorted)
    try {
        $apps = @()
        $keys = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
        )
        foreach ($k in $keys) {
            Get-ChildItem $k -ErrorAction SilentlyContinue | ForEach-Object {
                $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
                if ($p.DisplayName) { $apps += $p.DisplayName }
            }
        }
        $info.InstalledAppsCount = ($apps | Sort-Object -Unique).Count
    } catch {}

    return $info
}

function Get-RecentEvents {
    $info = [ordered]@{}
    $since = (Get-Date).AddDays(-7)

    try {
        # System errors
        $sysErrors = Get-WinEvent -FilterHashtable @{
            LogName = 'System'; Level = 1,2,3; StartTime = $since
        } -MaxEvents 50 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, @{Name='Message';Expression={
            if ($_.Message) { ConvertTo-SanitizedString -Text ($_.Message.Substring(0, [math]::Min(300, $_.Message.Length))) } else { '' }
        }}

        $info.SystemErrors = @($sysErrors)

        # Application errors
        $appErrors = Get-WinEvent -FilterHashtable @{
            LogName = 'Application'; Level = 1,2; StartTime = $since
        } -MaxEvents 30 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, @{Name='Message';Expression={
            if ($_.Message) { ConvertTo-SanitizedString -Text ($_.Message.Substring(0, [math]::Min(300, $_.Message.Length))) } else { '' }
        }}

        $info.ApplicationErrors = @($appErrors)
    } catch {
        $info.Error = $_.Exception.Message
    }

    return $info
}

# ============================================================================
#  AUTO-DIAGNOSTICO (reglas expertas)
# ============================================================================

function Get-AutoDiagnostic {
    param($Hardware, $Gaming, $Drivers)

    $result = [ordered]@{
        Issues   = @()
        Warnings = @()
        Info     = @()
    }

    # Regla 1: GPU muy caliente si se detecta
    if (Get-Command 'nvidia-smi' -ErrorAction SilentlyContinue) {
        try {
            $temp = & nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>$null
            if ($temp -and [int]$temp -gt 80) {
                $result.Issues += @{
                    Title = "GPU a temperatura alta"
                    Detail = "La GPU reporta $temp C en idle/bajo uso"
                    Suggestion = "Revisar limpieza de filtros, flujo de aire y pasta termica"
                    Severity = 'high'
                }
            }
        } catch {}
    }

    # Regla 2: Drivers viejos (> 6 meses)
    if ($Hardware.GPU.DriverDate) {
        try {
            $driverDate = [datetime]$Hardware.GPU.DriverDate
            $monthsOld = ((Get-Date) - $driverDate).Days / 30
            if ($monthsOld -gt 6) {
                $result.Warnings += @{
                    Title = "Driver de GPU desactualizado"
                    Detail = "Tu driver tiene $([int]$monthsOld) meses"
                    Suggestion = "Descargar ultimo driver desde nvidia.com o amd.com"
                    Severity = 'medium'
                }
            }
        } catch {}
    }

    # Regla 3: RAM baja para gaming moderno
    if ($Hardware.RAM.TotalGB -lt 16) {
        $result.Warnings += @{
            Title = "RAM limitada para gaming"
            Detail = "Solo tenes $($Hardware.RAM.TotalGB) GB de RAM, juegos modernos piden 16 GB+"
            Suggestion = "Considerar upgrade a 16GB o 32GB"
            Severity = 'medium'
        }
    }

    # Regla 4: Plan de energia no optimo
    if ($Gaming.PowerPlan -and $Gaming.PowerPlan -notmatch 'Alto|High|Ultimate|Maximo') {
        $result.Issues += @{
            Title = "Plan de energia subóptimo"
            Detail = "Plan activo: $($Gaming.PowerPlan)"
            Suggestion = "Cambiar a 'Alto rendimiento' o 'Ultimate performance'. Usa [P] en GameFixer"
            Severity = 'medium'
        }
    }

    # Regla 5: GameMode desactivado
    # Valor 1 = activo, 0 o null = inactivo
    $gmKey = 'HKCU:\Software\Microsoft\GameBar'
    $gm = Get-RegValueSafe $gmKey 'AutoGameModeEnabled'
    if ($null -eq $gm -or $gm -eq 0) {
        $result.Info += @{
            Title = "Game Mode de Windows desactivado"
            Detail = "Windows Game Mode optimiza prioridades cuando jugas"
            Suggestion = "Activar en Configuracion > Juegos > Modo de juego"
            Severity = 'low'
        }
    }

    # Regla 6: HAGS (hardware accelerated GPU scheduling)
    $hags = Get-RegValueSafe 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode'
    if ($hags -eq 1) {
        $result.Info += @{
            Title = "HAGS esta desactivado"
            Detail = "Hardware Accelerated GPU Scheduling puede mejorar FPS en tarjetas modernas"
            Suggestion = "Activar en Configuracion > Pantalla > Graficos > Cambiar config predeterminada"
            Severity = 'low'
        }
    }

    # Regla 7: Disco casi lleno
    foreach ($disk in $Hardware.Disks) {
        # No tenemos FreeSpace aqui, lo calculamos aparte si es necesario
    }
    try {
        $logical = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue
        foreach ($ld in $logical) {
            $pctUsed = if ($ld.Size -gt 0) { [int](($ld.Size - $ld.FreeSpace) / $ld.Size * 100) } else { 0 }
            if ($pctUsed -gt 90) {
                $result.Issues += @{
                    Title = "Disco $($ld.DeviceID) casi lleno ($pctUsed%)"
                    Detail = "Libre: $([math]::Round($ld.FreeSpace / 1GB, 1)) GB"
                    Suggestion = "Usar [6] Limpieza en GameFixer o desinstalar juegos no usados"
                    Severity = 'high'
                }
            }
        }
    } catch {}

    # Regla 8: Servicios molestos activados
    $annoyingServices = @('DiagTrack','SysMain','WSearch')
    foreach ($svcName in $annoyingServices) {
        $svc = $Drivers.Services | Where-Object { $_.Name -eq $svcName }
        if ($svc -and $svc.Status -eq 'Running') {
            $detail = switch ($svcName) {
                'DiagTrack' { "Telemetria (puede consumir RAM/ancho de banda)" }
                'SysMain'   { "SuperFetch (puede causar I/O alto en juegos)" }
                'WSearch'   { "Indexacion de Windows (usa CPU)" }
            }
            $result.Info += @{
                Title = "Servicio '$svcName' activo"
                Detail = $detail
                Suggestion = "Desactivar con GameFixer [2] Optimizar Gaming"
                Severity = 'low'
            }
        }
    }

    return $result
}

function Invoke-AutoDiagnostic {
    Write-Host ""
    Write-UI "  Ejecutando auto-diagnostico..." -Color Cyan
    $hardware = Get-HardwareInfo
    $gaming = Get-GamingConfigInfo
    $drivers = Get-DriversInfo
    $diag = Get-AutoDiagnostic -Hardware $hardware -Gaming $gaming -Drivers $drivers
    Show-DiagnosticSummary -Diagnostic $diag
}

function Show-DiagnosticSummary {
    param($Diagnostic)

    Write-UI "===  RESULTADOS DEL AUTO-DIAGNOSTICO ===" -Color Cyan
    Write-Host ""

    if ($Diagnostic.Issues.Count -eq 0 -and $Diagnostic.Warnings.Count -eq 0 -and $Diagnostic.Info.Count -eq 0) {
        Write-UI "  [OK] No se detectaron problemas obvios" -Color Green
        return
    }

    if ($Diagnostic.Issues.Count -gt 0) {
        Write-UI "  PROBLEMAS DETECTADOS:" -Color Red
        foreach ($i in $Diagnostic.Issues) {
            Write-UI ("    [!] " + $i.Title) -Color Red
            Write-UI ("        " + $i.Detail) -Color DarkGray
            Write-UI ("        Sugerencia: " + $i.Suggestion) -Color Yellow
            Write-Host ""
        }
    }

    if ($Diagnostic.Warnings.Count -gt 0) {
        Write-UI "  ADVERTENCIAS:" -Color Yellow
        foreach ($w in $Diagnostic.Warnings) {
            Write-UI ("    [?] " + $w.Title) -Color Yellow
            Write-UI ("        " + $w.Detail) -Color DarkGray
            Write-UI ("        Sugerencia: " + $w.Suggestion) -Color DarkYellow
            Write-Host ""
        }
    }

    if ($Diagnostic.Info.Count -gt 0) {
        Write-UI "  SUGERENCIAS ADICIONALES:" -Color Cyan
        foreach ($inf in $Diagnostic.Info) {
            Write-UI ("    [i] " + $inf.Title) -Color Cyan
            Write-UI ("        " + $inf.Suggestion) -Color DarkGray
            Write-Host ""
        }
    }
}

# ============================================================================
#  ENVIO A DISCORD
# ============================================================================

function Send-SupportToDiscord {
    param(
        $ZipPath,
        $Manifest,
        $Diagnostic,
        $Problem,
        $Hardware,
        $Windows,
        $Drivers,
        $Gaming
    )

    $webhook = $Global:GF.Config.supportWebhook
    if (-not $webhook) { return $false }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Discord permite 10 embeds por mensaje, 6000 chars total por mensaje.
    # Para legibilidad, dividimos en 4-5 mensajes tematicos consecutivos.

    $overallSuccess = $true

    # ============================================================
    # MENSAJE 1: Cabecera + Problema + Auto-diagnostico (el principal)
    # ============================================================
    $headerColor = if ($Diagnostic.Issues.Count -gt 0) { 15158332 }      # rojo
                   elseif ($Diagnostic.Warnings.Count -gt 0) { 16761095 } # amarillo
                   else { 3066993 }                                       # verde

    $issuesList = if ($Diagnostic.Issues.Count -gt 0) {
        ($Diagnostic.Issues | ForEach-Object { "**[!] $($_.Title)**`n$($_.Detail)`n*Sugerencia:* $($_.Suggestion)" } | Select-Object -First 6) -join "`n`n"
    } else { "*Ninguno detectado*" }

    $warningsList = if ($Diagnostic.Warnings.Count -gt 0) {
        ($Diagnostic.Warnings | ForEach-Object { "**[?] $($_.Title)**`n$($_.Detail)" } | Select-Object -First 5) -join "`n`n"
    } else { "*Ninguna*" }

    $infoList = if ($Diagnostic.Info.Count -gt 0) {
        ($Diagnostic.Info | ForEach-Object { "• $($_.Title)" } | Select-Object -First 8) -join "`n"
    } else { "" }

    $mainEmbed = @{
        title       = "🎮 Reporte de Soporte: $($Manifest.SupportId)"
        description = "**Problema reportado:** $($Problem.Category)`n`n**Descripción:**`n$(Limit-TextLength $Problem.Description 900)"
        color       = $headerColor
        fields      = @(
            @{ name = "📊 Resumen del auto-diagnóstico"
               value = "🔴 Problemas: **$($Diagnostic.Issues.Count)**  |  🟡 Advertencias: **$($Diagnostic.Warnings.Count)**  |  🔵 Info: **$($Diagnostic.Info.Count)**"
               inline = $false }
        )
        footer = @{ text = "ID: $($Manifest.SupportId) | Generado: $($Manifest.Generated) | GameFixer $($Manifest.GameFixerVer)" }
    }

    if ($Diagnostic.Issues.Count -gt 0) {
        $mainEmbed.fields += @{ name = "🔴 PROBLEMAS DETECTADOS"; value = Limit-TextLength $issuesList 1024; inline = $false }
    }
    if ($Diagnostic.Warnings.Count -gt 0) {
        $mainEmbed.fields += @{ name = "🟡 ADVERTENCIAS"; value = Limit-TextLength $warningsList 1024; inline = $false }
    }
    if ($infoList) {
        $mainEmbed.fields += @{ name = "🔵 Sugerencias adicionales"; value = Limit-TextLength $infoList 1024; inline = $false }
    }

    $msg1 = @{
        username = "GameFixer Support"
        embeds = @($mainEmbed)
        content = "🆕 **Nuevo reporte de soporte - ID: `$($Manifest.SupportId)`**"
    }
    $overallSuccess = (Send-DiscordMessage -Webhook $webhook -Payload $msg1) -and $overallSuccess

    # ============================================================
    # MENSAJE 2: Hardware detallado
    # ============================================================
    $hwEmbed = @{
        title = "💻 Hardware"
        color = 3447003  # azul
        fields = @()
    }

    # CPU
    if ($Hardware.CPU) {
        $cpuText = @"
**Modelo:** $($Hardware.CPU.Name)
**Cores:** $($Hardware.CPU.Cores) físicos / $($Hardware.CPU.LogicalProcessors) lógicos
**Reloj:** $($Hardware.CPU.MaxClockGHz) GHz (actual: $($Hardware.CPU.CurrentClockMHz) MHz)
**Carga actual:** $($Hardware.CPU.CurrentLoadPercent)%
**Virtualización:** $(if ($Hardware.CPU.Virtualization) { '✅ habilitada' } else { '❌ deshabilitada' })
"@
        $hwEmbed.fields += @{ name = "🧠 CPU"; value = Limit-TextLength $cpuText 1024; inline = $false }
    }

    # GPU
    if ($Hardware.GPU) {
        $gpuText = "**Modelo:** $($Hardware.GPU.Name)`n"
        $gpuText += "**Driver:** $($Hardware.GPU.DriverVersion) ($($Hardware.GPU.DriverDate))`n"
        $gpuText += "**VRAM:** $($Hardware.GPU.VRAMGB) GB`n"
        $gpuText += "**Resolución:** $($Hardware.GPU.CurrentH)x$($Hardware.GPU.CurrentV) @ $($Hardware.GPU.RefreshRate) Hz`n"
        if ($Hardware.GPU.LiveTempC) {
            $gpuText += "**Temperatura actual:** $($Hardware.GPU.LiveTempC)°C`n"
            $gpuText += "**Uso actual:** $($Hardware.GPU.LiveUsagePct)%`n"
            $gpuText += "**VRAM en uso:** $($Hardware.GPU.VRAMUsedMB)/$($Hardware.GPU.VRAMTotalMB) MB`n"
            if ($Hardware.GPU.PowerDrawW) { $gpuText += "**Consumo:** $($Hardware.GPU.PowerDrawW) W`n" }
            if ($Hardware.GPU.FanSpeedPct) { $gpuText += "**Ventilador:** $($Hardware.GPU.FanSpeedPct)%`n" }
        }
        if ($Hardware.GPU.AllGPUs.Count -gt 1) {
            $gpuText += "**Todas las GPUs:** $(($Hardware.GPU.AllGPUs) -join ', ')"
        }
        $hwEmbed.fields += @{ name = "🎨 GPU"; value = Limit-TextLength $gpuText 1024; inline = $false }
    }

    # RAM
    if ($Hardware.RAM) {
        $modulesText = ($Hardware.RAM.Modules | ForEach-Object {
            "  • $($_.SizeGB) GB $($_.MemoryType) @ $($_.SpeedMHz) MHz - $($_.Manufacturer.Trim())"
        }) -join "`n"
        $ramText = @"
**Total:** $($Hardware.RAM.TotalGB) GB
**En uso:** $($Hardware.RAM.UsedGB) GB ($($Hardware.RAM.UsedPercent)%)
**Libre:** $($Hardware.RAM.FreeGB) GB

**Módulos:**
$modulesText
"@
        $hwEmbed.fields += @{ name = "🧮 RAM"; value = Limit-TextLength $ramText 1024; inline = $false }
    }

    # Placa + BIOS
    if ($Hardware.Motherboard -and $Hardware.BIOS) {
        $mbText = @"
**Placa:** $($Hardware.Motherboard.Manufacturer) $($Hardware.Motherboard.Product)
**BIOS:** $($Hardware.BIOS.Manufacturer) v$($Hardware.BIOS.SMBIOSVersion) ($($Hardware.BIOS.ReleaseDate))
"@
        $hwEmbed.fields += @{ name = "🔧 Placa madre / BIOS"; value = Limit-TextLength $mbText 1024; inline = $false }
    }

    # Discos
    if ($Hardware.Disks -and $Hardware.Disks.Count -gt 0) {
        $disksText = ($Hardware.Disks | ForEach-Object {
            $icon = if ($_.MediaType -match 'SSD|NVMe') { '⚡' } else { '💿' }
            $fullWarn = if ($_.UsedPercent -gt 90) { ' ⚠️' } else { '' }
            "$icon **$($_.Drive)** $($_.MediaType) - $($_.UsedPercent)% lleno ($($_.FreeGB) GB libres de $($_.SizeGB) GB)$fullWarn"
        }) -join "`n"
        $hwEmbed.fields += @{ name = "💾 Discos"; value = Limit-TextLength $disksText 1024; inline = $false }
    }

    # Monitores
    if ($Hardware.Monitors -and $Hardware.Monitors.Count -gt 0) {
        $monText = ($Hardware.Monitors | ForEach-Object {
            "  • $($_.Manufacturer) $($_.Name) ($($_.YearOfManufacture))"
        }) -join "`n"
        $hwEmbed.fields += @{ name = "🖥️ Monitores"; value = Limit-TextLength $monText 1024; inline = $false }
    }

    $msg2 = @{
        username = "GameFixer Support"
        embeds = @($hwEmbed)
    }
    $overallSuccess = (Send-DiscordMessage -Webhook $webhook -Payload $msg2) -and $overallSuccess

    # ============================================================
    # MENSAJE 3: Windows + Seguridad
    # ============================================================
    $winEmbed = @{
        title = "🪟 Windows y Seguridad"
        color = 5793266  # gris-azul
        fields = @()
    }

    # OS
    $osText = @"
**Versión:** $($Windows.OSVersion)
**Edición:** $($Windows.EditionID) $($Windows.DisplayVersion)
**Build:** $($Windows.CurrentBuild).$($Windows.UBR)
**Arquitectura:** $($Windows.OSArchitecture)
**Instalado el:** $($Windows.InstallDate)
**Uptime:** $($Windows.UptimeHours) horas desde el último reinicio
**Idioma:** $($Windows.Locale) | **Zona:** $($Windows.TimeZone)
"@
    $winEmbed.fields += @{ name = "📋 Sistema operativo"; value = Limit-TextLength $osText 1024; inline = $false }

    # Seguridad critica
    if ($Windows.Security) {
        $secText = @"
**Secure Boot:** $(Format-BoolEmoji $Windows.Security.SecureBootEnabled)
**VBS (Virtualization-Based Security):** $(Format-BoolEmoji $Windows.Security.VBS_Running)
**HVCI (Hypervisor Code Integrity):** $(Format-BoolEmoji $Windows.Security.HVCI_Running)
**Memory Integrity (Core Isolation):** $(Format-BoolEmoji $Windows.Security.MemoryIntegrityEnabled)
**Credential Guard:** $(Format-BoolEmoji $Windows.Security.CredentialGuardRunning)
**SmartScreen:** $(if ($Windows.Security.SmartScreenAppCheck) { '✅ activo' } else { '⚠️ desactivado' })
"@
        $winEmbed.fields += @{ name = "🛡️ Seguridad del sistema"; value = Limit-TextLength $secText 1024; inline = $false }
    }

    # TPM
    if ($Windows.TPM) {
        $tpmText = @"
**Presente:** $(Format-BoolEmoji $Windows.TPM.Present)
**Activo y listo:** $(Format-BoolEmoji $Windows.TPM.Ready)
**Habilitado:** $(Format-BoolEmoji $Windows.TPM.Enabled)
**Con propietario:** $(Format-BoolEmoji $Windows.TPM.Owned)
**Fabricante:** $($Windows.TPM.ManufacturerId)
**Versión:** $($Windows.TPM.ManufacturerVersion)
"@
        $winEmbed.fields += @{ name = "🔐 TPM"; value = Limit-TextLength $tpmText 1024; inline = $false }
    }

    # Windows Defender
    if ($Windows.Defender) {
        $defText = @"
**Antivirus activo:** $(Format-BoolEmoji $Windows.Defender.AntivirusEnabled)
**Protección en tiempo real:** $(Format-BoolEmoji $Windows.Defender.RealTimeProtectionEnabled)
**Tamper Protection:** $(Format-BoolEmoji $Windows.Defender.TamperProtected)
**Motor:** $($Windows.Defender.AMEngineVersion)
**Firmas:** $($Windows.Defender.AntivirusSignatureVersion) ($($Windows.Defender.AntivirusSignatureAge) días)
**Último quick scan:** $($Windows.Defender.LastQuickScan)
**Último full scan:** $($Windows.Defender.LastFullScan)
**Exclusiones:** $($Windows.Defender.ExclusionPath_Count) rutas, $($Windows.Defender.ExclusionProcess_Count) procesos
"@
        if ($Windows.Defender.ThirdPartyAV -and $Windows.Defender.ThirdPartyAV.Count -gt 0) {
            $defText += "`n**Antivirus de terceros:** $($Windows.Defender.ThirdPartyAV -join ', ')"
        }
        $winEmbed.fields += @{ name = "🦠 Windows Defender"; value = Limit-TextLength $defText 1024; inline = $false }
    }

    # Firewall
    if ($Windows.Firewall) {
        $fwText = ''
        foreach ($profile in @('Domain','Private','Public')) {
            if ($Windows.Firewall.$profile) {
                $enabled = $Windows.Firewall.$profile.Enabled
                $fwText += "**$profile`:** $(Format-BoolEmoji $enabled)`n"
            }
        }
        if ($fwText) {
            $winEmbed.fields += @{ name = "🔥 Firewall"; value = Limit-TextLength $fwText.Trim() 1024; inline = $false }
        }
    }

    # BitLocker
    if ($Windows.BitLocker.Volumes -and $Windows.BitLocker.Volumes.Count -gt 0) {
        $blText = ($Windows.BitLocker.Volumes | ForEach-Object {
            "  • $($_.MountPoint) - $($_.ProtectionStatus) - $($_.VolumeStatus) ($($_.EncryptionPercent)%)"
        }) -join "`n"
        $winEmbed.fields += @{ name = "🔒 BitLocker"; value = Limit-TextLength $blText 1024; inline = $false }
    }

    # UAC
    if ($Windows.UAC) {
        $uacLevel = switch ($Windows.UAC.ConsentPromptAdmin) {
            0 { 'Sin notificaciones (inseguro)' }
            1 { 'Notificar siempre en escritorio seguro' }
            2 { 'Notificar siempre' }
            5 { 'Default (notificar solo cambios del sistema)' }
            default { "Valor $($Windows.UAC.ConsentPromptAdmin)" }
        }
        $uacText = "**Activado:** $(Format-BoolEmoji $Windows.UAC.Enabled)`n**Nivel:** $uacLevel"
        $winEmbed.fields += @{ name = "🔔 Control de cuentas (UAC)"; value = $uacText; inline = $false }
    }

    # Updates
    if ($Windows.Updates) {
        $updText = "**Servicio:** $($Windows.Updates.ServiceStatus) ($($Windows.Updates.ServiceStartType))`n"
        $updText += "**Pending reboot:** $(Format-BoolEmoji $Windows.Updates.PendingReboot)`n"
        if ($Windows.Updates.LastUpdate) { $updText += "**Última actualización:** $($Windows.Updates.LastUpdate)`n" }
        if ($Windows.Updates.RecentUpdates) {
            $updText += "`n**Últimas 5:**`n"
            $updText += ($Windows.Updates.RecentUpdates | Select-Object -First 5 | ForEach-Object {
                "  • $($_.Date) - $($_.Result) - $(Limit-TextLength $_.Title 60)"
            }) -join "`n"
        }
        $winEmbed.fields += @{ name = "🔄 Windows Update"; value = Limit-TextLength $updText 1024; inline = $false }
    }

    $msg3 = @{
        username = "GameFixer Support"
        embeds = @($winEmbed)
    }
    $overallSuccess = (Send-DiscordMessage -Webhook $webhook -Payload $msg3) -and $overallSuccess

    # ============================================================
    # MENSAJE 4: Gaming config + red + procesos
    # ============================================================
    $gamingEmbed = @{
        title = "🎮 Configuración Gaming y Red"
        color = 10181046  # purpura
        fields = @()
    }

    # Config gaming Windows
    $gamingText = @"
**Plan de energía:** $(if ($Gaming.PowerPlan) { $Gaming.PowerPlan } else { 'Desconocido' })
**Game Mode:** $(Format-BoolEmoji ($Windows.GameBar -eq 1))
**Game DVR:** $(if ($Windows.GameDVR -eq 1) { '✅ activo' } elseif ($Windows.GameDVR -eq 0) { '⚠️ desactivado' } else { '?' })
**HAGS (GPU Scheduling):** $(if ($Windows.HAGS -eq 2) { '✅ activo' } elseif ($Windows.HAGS -eq 1) { '⚠️ desactivado' } else { '?' })
**SystemResponsiveness:** $(if ($Windows.SystemResp -eq 0) { '✅ optimizado (0)' } else { "$($Windows.SystemResp) (default=20)" })
**Fast Startup:** $(Format-BoolEmoji $Windows.Boot.FastStartupEnabled)
**Hibernación:** $(Format-BoolEmoji $Windows.Boot.HibernationEnabled)
**Apps autoinicio:** $($Windows.Boot.AutoStartCount)
"@
    $gamingEmbed.fields += @{ name = "⚙️ Ajustes Gaming"; value = Limit-TextLength $gamingText 1024; inline = $false }

    # Red
    if ($Gaming.DNS) {
        $dnsText = "**Servidores:** $($Gaming.DNS.Servers -join ', ')`n**Proveedor:** $($Gaming.DNS.Provider)"
        $gamingEmbed.fields += @{ name = "🌐 DNS"; value = Limit-TextLength $dnsText 1024; inline = $false }
    }

    if ($Gaming.NetAdapters -and $Gaming.NetAdapters.Count -gt 0) {
        $adapText = ($Gaming.NetAdapters | ForEach-Object {
            "  • $($_.Name) ($($_.MediaType)) - $($_.LinkSpeed)"
        }) -join "`n"
        $gamingEmbed.fields += @{ name = "🔌 Adaptadores activos"; value = Limit-TextLength $adapText 1024; inline = $false }
    }

    if ($Gaming.InternetLatency) {
        $gamingEmbed.fields += @{ name = "📡 Latencia a internet"
            value = "**$($Gaming.InternetLatency.CloudflareMs) ms** a Cloudflare - *$($Gaming.InternetLatency.Quality)*"
            inline = $false }
    }

    if ($Gaming.TCPSettings) {
        $tcpText = @"
**Auto-tuning:** $($Gaming.TCPSettings.AutoTuningLevelLocal)
**Congestion provider:** $($Gaming.TCPSettings.CongestionProvider)
**ECN:** $($Gaming.TCPSettings.EcnCapability)
**Nagle deshabilitado:** $($Gaming.NagleDisabled.Count)/$($Gaming.NagleDisabled.Total) interfaces
"@
        $gamingEmbed.fields += @{ name = "🔧 TCP/IP avanzado"; value = Limit-TextLength $tcpText 1024; inline = $false }
    }

    # Overlays y anticheats
    if ($Gaming.OverlaysYAnticheats -and $Gaming.OverlaysYAnticheats.Count -gt 0) {
        $ovText = ($Gaming.OverlaysYAnticheats | ForEach-Object { "  • $_" }) -join "`n"
        $gamingEmbed.fields += @{ name = "🎭 Overlays/Anticheats activos"; value = Limit-TextLength $ovText 1024; inline = $false }
    }

    # Launchers
    if ($Gaming.GamingLaunchers -and $Gaming.GamingLaunchers.Count -gt 0) {
        $launchText = $Gaming.GamingLaunchers -join ', '
        $gamingEmbed.fields += @{ name = "🕹️ Launchers instalados"; value = Limit-TextLength $launchText 1024; inline = $false }
    }

    $msg4 = @{
        username = "GameFixer Support"
        embeds = @($gamingEmbed)
    }
    $overallSuccess = (Send-DiscordMessage -Webhook $webhook -Payload $msg4) -and $overallSuccess

    # ============================================================
    # MENSAJE 5: Procesos top + drivers + politicas
    # ============================================================
    $processEmbed = @{
        title = "📊 Procesos y Servicios"
        color = 16776960  # amarillo
        fields = @()
    }

    # Top procesos
    if ($Gaming.TopProcesses -and $Gaming.TopProcesses.Count -gt 0) {
        $procText = "``````{0,-25}{1,8}{2,10}`n" -f 'Proceso','RAM MB','CPU seg'
        $procText = "``````{0,-25}{1,8}{2,10}`n" -f 'PROCESO','RAM MB','CPU seg'
        $procText += ('-' * 43) + "`n"
        foreach ($p in ($Gaming.TopProcesses | Select-Object -First 12)) {
            $procText += ("{0,-25}{1,8}{2,10}`n" -f $p.Name, $p.RAM_MB, $p.CPU_Sec)
        }
        $procText += "``````"
        $processEmbed.fields += @{ name = "🔝 Top procesos por RAM"; value = Limit-TextLength $procText 1024; inline = $false }
    }

    # Servicios criticos gaming
    if ($Drivers.Services -and $Drivers.Services.Count -gt 0) {
        $svcText = ($Drivers.Services | ForEach-Object {
            $icon = if ($_.Status -eq 'Running') { '✅' } else { '⚫' }
            "$icon $($_.Name) - $($_.Status) ($($_.StartType))"
        } | Select-Object -First 10) -join "`n"
        $processEmbed.fields += @{ name = "⚙️ Servicios relevantes"; value = Limit-TextLength $svcText 1024; inline = $false }
    }

    # Driver NVIDIA
    if ($Drivers.NVIDIA) {
        $nvText = "``````$($Drivers.NVIDIA.Output)`````` "
        $processEmbed.fields += @{ name = "🟢 NVIDIA (nvidia-smi)"; value = Limit-TextLength $nvText 1024; inline = $false }
    }

    # Politicas de Windows
    if ($Windows.Policies) {
        $polText = @"
**RDP habilitado:** $(Format-BoolEmoji $Windows.Policies.RDP_Enabled)
**Cortana:** $(if ($Windows.Policies.CortanaDisabled) { '❌ deshabilitado' } else { '✅ default' })
**Telemetría:** $(switch ($Windows.Policies.TelemetryLevel) { 0 {'❌ deshabilitada (Enterprise)'} 1 {'⚠️ básica'} 2 {'⚠️ mejorada'} 3 {'⚠️ completa'} default {'default'} })
**OneDrive bloqueado:** $(Format-BoolEmoji $Windows.Policies.OneDriveDisabled)
"@
        $processEmbed.fields += @{ name = "📜 Políticas del sistema"; value = Limit-TextLength $polText 1024; inline = $false }
    }

    $msg5 = @{
        username = "GameFixer Support"
        embeds = @($processEmbed)
    }
    $overallSuccess = (Send-DiscordMessage -Webhook $webhook -Payload $msg5) -and $overallSuccess

    # ============================================================
    # MENSAJE 6: ZIP adjunto (backup para deep-dive)
    # ============================================================
    if ($ZipPath -and (Test-Path $ZipPath)) {
        $zipSizeMB = (Get-Item $ZipPath).Length / 1MB
        if ($zipSizeMB -le 24) {
            $zipEmbed = @{
                title = "📎 ZIP de respaldo adjunto"
                description = "Si necesitás profundizar, el ZIP incluye todos los JSONs raw y los logs de GameFixer."
                color = 8421504  # gris
                footer = @{ text = "Fin del reporte $($Manifest.SupportId)" }
            }

            $payload_json = @{
                username = "GameFixer Support"
                embeds = @($zipEmbed)
            } | ConvertTo-Json -Depth 5 -Compress

            # Multipart con archivo
            $boundary = [System.Guid]::NewGuid().ToString()
            $LF = "`r`n"
            $bodyLines = New-Object System.Collections.ArrayList
            [void]$bodyLines.Add("--$boundary")
            [void]$bodyLines.Add('Content-Disposition: form-data; name="payload_json"')
            [void]$bodyLines.Add('Content-Type: application/json')
            [void]$bodyLines.Add('')
            [void]$bodyLines.Add($payload_json)
            [void]$bodyLines.Add("--$boundary")
            [void]$bodyLines.Add("Content-Disposition: form-data; name=`"files[0]`"; filename=`"$([IO.Path]::GetFileName($ZipPath))`"")
            [void]$bodyLines.Add('Content-Type: application/zip')
            [void]$bodyLines.Add('')

            $preamble = ($bodyLines -join $LF) + $LF
            $epilogue = "$LF--$boundary--$LF"
            $fileBytes = [System.IO.File]::ReadAllBytes($ZipPath)
            $enc = [System.Text.Encoding]::UTF8
            $preambleBytes = $enc.GetBytes($preamble)
            $epilogueBytes = $enc.GetBytes($epilogue)
            $body = New-Object byte[] ($preambleBytes.Length + $fileBytes.Length + $epilogueBytes.Length)
            [Buffer]::BlockCopy($preambleBytes, 0, $body, 0, $preambleBytes.Length)
            [Buffer]::BlockCopy($fileBytes, 0, $body, $preambleBytes.Length, $fileBytes.Length)
            [Buffer]::BlockCopy($epilogueBytes, 0, $body, $preambleBytes.Length + $fileBytes.Length, $epilogueBytes.Length)

            try {
                $resp = Invoke-WebRequest -Uri $webhook -Method POST `
                    -Body $body `
                    -ContentType "multipart/form-data; boundary=$boundary" `
                    -UseBasicParsing -TimeoutSec 60
                if ($resp.StatusCode -notin 200, 204) { $overallSuccess = $false }
            } catch {
                Write-UI ("  [!] ZIP no se pudo adjuntar: " + $_.Exception.Message) -Color DarkYellow
            }
        }
    }

    return $overallSuccess
}

function Send-DiscordMessage {
    param($Webhook, $Payload)
    try {
        $json = $Payload | ConvertTo-Json -Depth 10
        $resp = Invoke-WebRequest -Uri $Webhook -Method POST `
            -Body $json -ContentType 'application/json; charset=utf-8' `
            -UseBasicParsing -TimeoutSec 30
        # Discord limita a 30 mensajes/minuto por webhook; delay pequeno para no pegar rate limit
        Start-Sleep -Milliseconds 600
        return ($resp.StatusCode -in 200, 204)
    } catch {
        Write-UI ("  [!] Discord respondio error: " + $_.Exception.Message) -Color DarkYellow
        return $false
    }
}

function Format-BoolEmoji {
    param($Value)
    if ($Value -eq $true) { return '✅ sí' }
    if ($Value -eq $false) { return '❌ no' }
    return '❓ desconocido'
}

function Limit-TextLength {
    param([string]$Text, [int]$MaxLength = 1024)
    if (-not $Text) { return '' }
    if ($Text.Length -le $MaxLength) { return $Text }
    return $Text.Substring(0, $MaxLength - 3) + '...'
}

function Show-SupportReports {
    Write-Host ""
    $reportsDir = Join-Path $Global:GF.Root 'reports'
    if (-not (Test-Path $reportsDir)) {
        Write-UI "  No hay reportes generados aun" -Color Yellow
        return
    }

    $zips = @(Get-ChildItem $reportsDir -Filter 'SupportPackage_*.zip' -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending)
    if ($zips.Count -eq 0) {
        Write-UI "  No hay reportes generados aun" -Color Yellow
        return
    }

    Write-UI ("  Reportes en " + $reportsDir + ":") -Color Cyan
    foreach ($z in $zips | Select-Object -First 20) {
        $sizeMB = [math]::Round($z.Length / 1MB, 2)
        Write-UI ("    " + $z.Name + " (" + $sizeMB + " MB) - " + $z.LastWriteTime) -Color Green
    }

    Write-Host ""
    Write-UI "  Abrir carpeta de reportes? (s/N): " -Color Yellow -NoNewline
    $r = Read-Host
    if ($r.Trim().ToLower() -eq 's') {
        Start-Process $reportsDir
    }
}

Export-ModuleMember -Function Invoke-SupportReport, New-SupportPackage, Invoke-AutoDiagnostic, `
    Send-SupportToDiscord, Send-DiscordMessage, `
    Test-SupportWebhookConfigured, Set-SupportWebhook, Test-SupportWebhook, `
    Get-HardwareInfo, Get-WindowsInfo, Get-DriversInfo, Get-GamingConfigInfo, `
    Get-WindowsSecurityInfo, Get-TPMInfo, Get-DefenderInfo, Get-FirewallInfo, `
    Get-BitLockerInfo, Get-UACInfo, Get-WindowsUpdatesInfo, Get-BootInfo, `
    Get-WindowsPoliciesInfo, Get-AutoDiagnostic, Format-BoolEmoji, Limit-TextLength
