# ============================================================================
#  modules/Telemetry.psm1
#  Lectura de stats del sistema en tiempo real
# ============================================================================

function Get-NvidiaGPUStats {
    <#
    .SYNOPSIS
    Lee la GPU usando nvidia-smi si esta disponible.
    Devuelve hashtable con Usage (0-100) y Temp.
    #>
    $smi = Get-Command 'nvidia-smi' -ErrorAction SilentlyContinue
    if (-not $smi) { return @{ Usage = 0; Temp = 0; Available = $false } }

    try {
        $out = & nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>$null
        if ($LASTEXITCODE -eq 0 -and $out) {
            $parts = ($out -split ',').Trim()
            return @{
                Usage     = [int]$parts[0]
                Temp      = [int]$parts[1]
                Available = $true
            }
        }
    } catch {}
    return @{ Usage = 0; Temp = 0; Available = $false }
}

function Get-CPUTemp {
    <#
    .SYNOPSIS
    Intenta leer temperatura CPU (requiere MSAcpi_ThermalZoneTemperature).
    No todos los sistemas exponen esto; devuelve 0 si no se puede.
    #>
    try {
        $t = Get-CimInstance -Namespace 'root/WMI' -ClassName 'MSAcpi_ThermalZoneTemperature' -ErrorAction SilentlyContinue
        if ($t) {
            $k = ($t | Select-Object -First 1).CurrentTemperature / 10
            return [int]($k - 273.15)
        }
    } catch {}
    return 0
}

function Get-TelemetryStats {
    # --- CPU ---
    try {
        $cpu = [int](Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average
    } catch { $cpu = 0 }

    $cpuTemp = Get-CPUTemp

    # --- GPU (NVIDIA) ---
    $gpuInfo = Get-NvidiaGPUStats

    # --- RAM ---
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $ramTotalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        $ramUsedGB  = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 1)
        $ramPct     = [int](($ramUsedGB / $ramTotalGB) * 100)
    } catch { $ramPct = 0; $ramTotalGB = 0; $ramUsedGB = 0 }

    # --- Disk C: ---
    try {
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
        $diskTotalGB = [math]::Round($disk.Size / 1GB, 0)
        $diskUsedGB  = [math]::Round(($disk.Size - $disk.FreeSpace) / 1GB, 0)
        $diskPct     = [int](($diskUsedGB / $diskTotalGB) * 100)
    } catch { $diskPct = 0; $diskTotalGB = 0; $diskUsedGB = 0 }

    # --- OS ---
    try {
        $osInfo = Get-CimInstance Win32_OperatingSystem
        $osName = $osInfo.Caption -replace 'Microsoft ', '' -replace 'Windows ', 'Win '
        $osVersion = $osInfo.Version
    } catch { $osName = 'Windows'; $osVersion = '?' }

    # --- Red ---
    try {
        $ping = Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue
        $netStatus = if ($ping) { 'ONLINE' } else { 'OFFLINE' }

        if ($ping) {
            $p = Test-Connection -ComputerName '8.8.8.8' -Count 1 -ErrorAction SilentlyContinue
            if ($p) { $netStatus = "ONLINE $($p.ResponseTime)ms" }
        }
    } catch { $netStatus = 'UNKNOWN' }

    # --- Servicios clave ---
    $servicesStatus = 'OK'
    try {
        $critical = @('wuauserv','BITS','Winmgmt','EventLog')
        $stopped = @($critical | ForEach-Object { Get-Service -Name $_ -ErrorAction SilentlyContinue } |
                    Where-Object { $_.Status -ne 'Running' })
        if ($stopped.Count -gt 0) {
            $servicesStatus = "$($stopped.Count) detenidos"
        }
    } catch {}

    # --- Last run ---
    $lastRun = 'nunca'
    try {
        $logs = Get-ChildItem $Global:GF.LogsDir -Filter 'session-*.log' -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -ne $Global:GF.LogFile } |
                Sort-Object LastWriteTime -Descending
        if ($logs) {
            $diff = (Get-Date) - $logs[0].LastWriteTime
            if ($diff.TotalDays -ge 1) { $lastRun = "hace $([int]$diff.TotalDays)d" }
            elseif ($diff.TotalHours -ge 1) { $lastRun = "hace $([int]$diff.TotalHours)h" }
            else { $lastRun = "hace $([int]$diff.TotalMinutes)m" }
        }
    } catch {}

    return [pscustomobject]@{
        CPU          = $cpu
        CPUTemp      = $cpuTemp
        GPU          = $gpuInfo.Usage
        GPUTemp      = $gpuInfo.Temp
        GPUAvailable = $gpuInfo.Available
        RAM          = $ramPct
        RAMUsedGB    = $ramUsedGB
        RAMTotalGB   = $ramTotalGB
        Disk         = $diskPct
        DiskUsedGB   = $diskUsedGB
        DiskTotalGB  = $diskTotalGB
        OS           = "$osName ($osVersion)"
        NetStatus    = $netStatus
        Services     = $servicesStatus
        LastRun      = $lastRun
    }
}

Export-ModuleMember -Function Get-TelemetryStats, Get-NvidiaGPUStats, Get-CPUTemp
