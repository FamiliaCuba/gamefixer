# ============================================================================
#  modules/Telemetry.psm1
#  Lectura de stats del sistema en tiempo real
# ============================================================================

function Get-GPUVRam {
    <#
    .SYNOPSIS
    Lee la VRAM correcta de la GPU. Win32_VideoController.AdapterRAM es UInt32
    que satura a 4 GB, por lo que GPUs de 8/12/16/24 GB muestran siempre 4.
    Prioridad:
      1) nvidia-smi (mas preciso)
      2) Registro HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968...} \HardwareInformation.qwMemorySize (QWORD, reporta real)
      3) Fallback al AdapterRAM
    #>
    param(
        [string]$GpuName,
        [long]$Fallback = 0
    )

    # 1) nvidia-smi
    if (Get-Command 'nvidia-smi' -ErrorAction SilentlyContinue) {
        try {
            $out = & nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>$null
            if ($LASTEXITCODE -eq 0 -and $out) {
                # nvidia-smi devuelve en MiB
                $lines = @($out -split "`n" | Where-Object { $_ -match '^\s*\d' })
                foreach ($line in $lines) {
                    $mib = [int]($line.Trim())
                    if ($mib -gt 0) {
                        return [math]::Round($mib / 1024, 1)
                    }
                }
            }
        } catch {}
    }

    # 2) Registro (qwMemorySize es QWORD de 64 bits, valor correcto)
    try {
        $classKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
        if (Test-Path $classKey) {
            $subkeys = Get-ChildItem $classKey -ErrorAction SilentlyContinue |
                       Where-Object { $_.PSChildName -match '^\d{4}$' }
            foreach ($sk in $subkeys) {
                $props = Get-ItemProperty $sk.PSPath -ErrorAction SilentlyContinue
                # Match con nombre o tomar cualquiera si no se especifica
                $matchName = if ($GpuName) {
                    $props.DriverDesc -like "*$GpuName*" -or $GpuName -like "*$($props.DriverDesc)*"
                } else { $true }
                if ($matchName -and $props.'HardwareInformation.qwMemorySize') {
                    $bytes = [long]$props.'HardwareInformation.qwMemorySize'
                    if ($bytes -gt 0) {
                        return [math]::Round($bytes / 1GB, 1)
                    }
                }
                # Fallback al campo viejo 'HardwareInformation.MemorySize' (DWORD, limitado a 4GB)
                if ($matchName -and $props.'HardwareInformation.MemorySize') {
                    $bytes = [long]$props.'HardwareInformation.MemorySize'
                    if ($bytes -gt 0) {
                        return [math]::Round($bytes / 1GB, 1)
                    }
                }
            }
        }
    } catch {}

    # 3) Fallback
    if ($Fallback -gt 0) {
        return [math]::Round($Fallback / 1GB, 1)
    }
    return 0
}

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

    # --- Discos (TODOS los locales, no solo C:) ---
    $allDisks = @()
    try {
        $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
        $diskTotalGB = 0
        $diskUsedGB  = 0
        foreach ($d in $disks) {
            $totGB  = [math]::Round($d.Size / 1GB, 0)
            $usedGB = [math]::Round(($d.Size - $d.FreeSpace) / 1GB, 0)
            $pct    = if ($d.Size -gt 0) { [int]((($d.Size - $d.FreeSpace) / $d.Size) * 100) } else { 0 }
            $diskTotalGB += $totGB
            $diskUsedGB  += $usedGB
            $allDisks += [pscustomobject]@{
                Drive    = $d.DeviceID
                TotalGB  = $totGB
                UsedGB   = $usedGB
                FreeGB   = $totGB - $usedGB
                Percent  = $pct
            }
        }
        $diskPct = if ($diskTotalGB -gt 0) { [int](($diskUsedGB / $diskTotalGB) * 100) } else { 0 }
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
        Disks        = $allDisks
        OS           = "$osName ($osVersion)"
        NetStatus    = $netStatus
        Services     = $servicesStatus
        LastRun      = $lastRun
    }
}

Export-ModuleMember -Function Get-TelemetryStats, Get-NvidiaGPUStats, Get-CPUTemp, Get-GPUVRam
