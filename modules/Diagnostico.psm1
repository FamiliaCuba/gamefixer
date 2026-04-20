# ============================================================================
#  modules/Diagnostico.psm1
#  Analisis completo del sistema sin cambios destructivos
# ============================================================================

function Invoke-Diagnostico {
    Show-Section "DIAGNOSTICO COMPLETO"

    # 1. Info general
    Write-UI "[1/7] Informacion general del sistema" -Color Cyan
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $cs = Get-CimInstance Win32_ComputerSystem
        $bios = Get-CimInstance Win32_BIOS
        Write-UI ("      OS            : " + $os.Caption + " " + $os.Version) -Color Green
        Write-UI ("      Build         : " + $os.BuildNumber) -Color Green
        Write-UI ("      Fabricante    : " + $cs.Manufacturer) -Color Green
        Write-UI ("      Modelo        : " + $cs.Model) -Color Green
        Write-UI ("      BIOS          : " + $bios.SMBIOSBIOSVersion) -Color Green
        Write-UI ("      Boot time     : " + $os.LastBootUpTime) -Color Green
        Write-Log -Level INFO -Message "Sistema: $($os.Caption) build $($os.BuildNumber) en $($cs.Manufacturer) $($cs.Model)"
    } catch {
        Write-UI ("      [!] " + $_.Exception.Message) -Color Red
    }

    # 2. CPU
    Write-Host ""
    Write-UI "[2/7] CPU" -Color Cyan
    try {
        Get-CimInstance Win32_Processor | ForEach-Object {
            Write-UI ("      " + $_.Name.Trim()) -Color Green
            Write-UI ("      Cores/Threads : {0}/{1}" -f $_.NumberOfCores, $_.NumberOfLogicalProcessors) -Color Green
            Write-UI ("      Velocidad max : {0} MHz" -f $_.MaxClockSpeed) -Color Green
            Write-UI ("      Carga actual  : {0}%" -f $_.LoadPercentage) -Color Green
        }
    } catch { Write-UI ("      [!] " + $_.Exception.Message) -Color Red }

    # 3. GPU
    Write-Host ""
    Write-UI "[3/7] GPU" -Color Cyan
    try {
        Get-CimInstance Win32_VideoController | ForEach-Object {
            Write-UI ("      " + $_.Name) -Color Green
            if ($_.AdapterRAM) {
                $vramGB = [math]::Round($_.AdapterRAM / 1GB, 1)
                Write-UI ("      VRAM          : {0} GB" -f $vramGB) -Color Green
            }
            Write-UI ("      Driver        : " + $_.DriverVersion) -Color Green
        }
        $g = Get-NvidiaGPUStats
        if ($g.Available) {
            Write-UI ("      NVIDIA uso    : {0}% @ {1}°C" -f $g.Usage, $g.Temp) -Color Green
        }
    } catch { Write-UI ("      [!] " + $_.Exception.Message) -Color Red }

    # 4. RAM
    Write-Host ""
    Write-UI "[4/7] Memoria RAM" -Color Cyan
    try {
        $modules = Get-CimInstance Win32_PhysicalMemory
        $total = ($modules | Measure-Object Capacity -Sum).Sum / 1GB
        Write-UI ("      Total fisico  : {0} GB" -f $total) -Color Green
        Write-UI ("      Modulos       : {0}" -f $modules.Count) -Color Green
        foreach ($m in $modules) {
            $gb = [math]::Round($m.Capacity / 1GB, 0)
            Write-UI ("        - Slot {0}: {1}GB @ {2}MHz {3}" -f $m.DeviceLocator, $gb, $m.ConfiguredClockSpeed, $m.Manufacturer) -Color DarkGreen
        }
    } catch { Write-UI ("      [!] " + $_.Exception.Message) -Color Red }

    # 5. Discos
    Write-Host ""
    Write-UI "[5/7] Almacenamiento" -Color Cyan
    try {
        Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
            $totalGB = [math]::Round($_.Size / 1GB, 0)
            $freeGB  = [math]::Round($_.FreeSpace / 1GB, 0)
            $usedPct = [int]((($_.Size - $_.FreeSpace) / $_.Size) * 100)
            $color = if ($usedPct -ge 85) { 'Red' } elseif ($usedPct -ge 70) { 'Yellow' } else { 'Green' }
            Write-UI ("      {0} {1,4}GB libres de {2,4}GB ({3}% usado)" -f $_.DeviceID, $freeGB, $totalGB, $usedPct) -Color $color
        }
    } catch { Write-UI ("      [!] " + $_.Exception.Message) -Color Red }

    # 6. Red
    Write-Host ""
    Write-UI "[6/7] Red" -Color Cyan
    try {
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up'
        foreach ($a in $adapters) {
            Write-UI ("      " + $a.Name + " (" + $a.InterfaceDescription + ")") -Color Green
            $ip = Get-NetIPAddress -InterfaceIndex $a.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            if ($ip) { Write-UI ("        IP: " + $ip.IPAddress) -Color DarkGreen }
            Write-UI ("        Velocidad: " + $a.LinkSpeed) -Color DarkGreen
        }
        $ping = Test-Connection -ComputerName '8.8.8.8' -Count 2 -ErrorAction SilentlyContinue
        if ($ping) {
            $avg = ($ping | Measure-Object ResponseTime -Average).Average
            Write-UI ("      Latencia a 8.8.8.8: {0:N0} ms" -f $avg) -Color Green
        }
    } catch { Write-UI ("      [!] " + $_.Exception.Message) -Color Red }

    # 7. Eventos criticos recientes
    Write-Host ""
    Write-UI "[7/7] Eventos criticos (ultimas 24h)" -Color Cyan
    try {
        $events = Get-WinEvent -FilterHashtable @{
            LogName   = 'System'
            Level     = 1, 2
            StartTime = (Get-Date).AddHours(-24)
        } -MaxEvents 10 -ErrorAction SilentlyContinue

        if ($events) {
            foreach ($e in $events) {
                $msg = $e.Message -split "`n" | Select-Object -First 1
                if ($msg.Length -gt 90) { $msg = $msg.Substring(0, 90) + '...' }
                Write-UI ("      [$($e.LevelDisplayName)] $msg") -Color Yellow
            }
        } else {
            Write-UI "      Sin eventos criticos recientes." -Color Green
        }
    } catch { Write-UI ("      [!] " + $_.Exception.Message) -Color DarkGray }

    Write-Host ""
    Write-UI ("=" * 72) -Color DarkGreen
    Write-UI "  Diagnostico completado. Log: $($Global:GF.LogFile)" -Color Green
}

Export-ModuleMember -Function Invoke-Diagnostico
