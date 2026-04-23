# ============================================================================
#  modules/Dashboard.psm1
#  Dashboard en tiempo real con sparklines Unicode estilo htop
# ============================================================================

$Script:SparkChars = @(
    [char]0x2581, [char]0x2582, [char]0x2583, [char]0x2584,
    [char]0x2585, [char]0x2586, [char]0x2587, [char]0x2588
)

function ConvertTo-Sparkline {
    param([int[]]$Values, [int]$Max = 100)

    # Inicializacion defensiva para tests que importan el modulo en contextos distintos
    if (-not $Script:SparkChars -or $Script:SparkChars.Count -eq 0) {
        $Script:SparkChars = @(
            [char]0x2581, [char]0x2582, [char]0x2583, [char]0x2584,
            [char]0x2585, [char]0x2586, [char]0x2587, [char]0x2588
        )
    }

    # IMPORTANTE: no usar "-not $Values" porque @(0) se evalua como $false
    # y la funcion saldria temprano. Chequear explicitamente $null y Count.
    if ($null -eq $Values -or $Values.Count -eq 0) { return '' }
    if ($Max -le 0) { $Max = 1 }

    $sb = New-Object System.Text.StringBuilder
    foreach ($v in $Values) {
        if ($null -eq $v) { [void]$sb.Append(' '); continue }
        $norm = [math]::Max(0, [math]::Min($Max, $v))
        $idx = [int]([math]::Floor(($norm / $Max) * ($Script:SparkChars.Count - 1)))
        if ($idx -lt 0) { $idx = 0 }
        if ($idx -ge $Script:SparkChars.Count) { $idx = $Script:SparkChars.Count - 1 }
        [void]$sb.Append($Script:SparkChars[$idx])
    }
    return $sb.ToString()
}

function Get-BarColor {
    param([int]$Percent)
    if ($Percent -ge 85) { return 'Red' }
    if ($Percent -ge 70) { return 'Yellow' }
    return 'Green'
}

function Get-QuickCPU {
    # Get-Counter es 10x mas rapido que WMI para CPU
    try {
        $c = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction Stop -SampleInterval 1 -MaxSamples 1
        return [int]$c.CounterSamples[0].CookedValue
    } catch {
        try {
            $c = (Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average
            return [int]$c
        } catch { return 0 }
    }
}

function Get-QuickRAM {
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $totalKB = $os.TotalVisibleMemorySize
        $freeKB = $os.FreePhysicalMemory
        $usedKB = $totalKB - $freeKB
        $pct = [int](($usedKB / $totalKB) * 100)
        $usedGB = [math]::Round($usedKB / 1MB, 1)
        $totalGB = [math]::Round($totalKB / 1MB, 1)
        return @{ Percent = $pct; UsedGB = $usedGB; TotalGB = $totalGB }
    } catch {
        return @{ Percent = 0; UsedGB = 0; TotalGB = 0 }
    }
}

function Get-QuickGPU {
    # nvidia-smi es rapido
    try {
        if (Get-Command 'nvidia-smi' -ErrorAction SilentlyContinue) {
            $out = & nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>$null
            if ($out) {
                $parts = $out -split ','
                return @{ Usage = [int]($parts[0].Trim()); Temp = [int]($parts[1].Trim()) }
            }
        }
    } catch {}
    return @{ Usage = 0; Temp = 0 }
}

function Get-QuickCPUTemp {
    # La temperatura de CPU no siempre esta disponible, pero intentamos WMI
    try {
        $t = Get-CimInstance -Namespace 'root/WMI' -ClassName 'MSAcpi_ThermalZoneTemperature' -ErrorAction SilentlyContinue
        if ($t) {
            return [int](($t[0].CurrentTemperature - 2732) / 10)
        }
    } catch {}
    return 0
}

function Get-QuickNetRate {
    # Usa Get-Counter para rate de red en tiempo real (mucho mas rapido que NetAdapterStatistics)
    try {
        $c = Get-Counter '\Network Interface(*)\Bytes Received/sec' -ErrorAction Stop -SampleInterval 1 -MaxSamples 1
        $bytesPerSec = ($c.CounterSamples | Where-Object { $_.InstanceName -notmatch 'Loopback|isatap|Teredo' } | Measure-Object CookedValue -Sum).Sum
        return [int](($bytesPerSec * 8) / 1MB)  # Mbps
    } catch { return 0 }
}

function Get-QuickDisks {
    try {
        return @(
            Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue |
            ForEach-Object {
                $total = [math]::Round($_.Size / 1GB, 0)
                $used = [math]::Round(($_.Size - $_.FreeSpace) / 1GB, 0)
                $pct = if ($_.Size -gt 0) { [int](($_.Size - $_.FreeSpace) / $_.Size * 100) } else { 0 }
                [pscustomobject]@{
                    Drive = $_.DeviceID
                    TotalGB = $total
                    UsedGB = $used
                    Percent = $pct
                }
            }
        )
    } catch { return @() }
}

function Show-DashboardLine {
    param(
        [string]$Label,
        [int]$Current,
        [string]$Unit = '%',
        [string]$Extra = '',
        $History,
        [int]$Max = 100,
        [int]$Width = 78
    )

    $barWidth = 25
    $filled = if ($Max -gt 0) { [int](($Current / $Max) * $barWidth) } else { 0 }
    if ($filled -lt 0) { $filled = 0 }
    if ($filled -gt $barWidth) { $filled = $barWidth }
    $empty = $barWidth - $filled

    $color = Get-BarColor -Percent ([math]::Min(100, ($Current * 100 / [math]::Max(1,$Max))))
    $sparkline = if ($History) { ConvertTo-Sparkline -Values @($History) -Max $Max } else { '' }

    # Linea: LABEL [====bar====] 75% history_sparkline Extra
    $labelPart = "  {0,-4} [" -f $Label
    $valuePart = " {0,4}{1}" -f $Current, $Unit

    Write-UI $labelPart -Color Cyan -NoNewline
    Write-UI ($Global:GF.BlockFull.ToString()  * $filled) -Color $color -NoNewline
    Write-UI ($Global:GF.BlockLight.ToString() * $empty)  -Color DarkGreen -NoNewline
    Write-UI "]" -Color Cyan -NoNewline
    Write-UI $valuePart -Color $color -NoNewline

    if ($sparkline) {
        Write-UI "  " -NoNewline
        Write-UI $sparkline -Color $color -NoNewline
    }

    # Extra info con padding para tapar contenido viejo
    $extraPadded = if ($Extra) { "  $Extra" } else { '' }
    Write-UI ($extraPadded.PadRight(30)) -Color DarkGray
}

function Invoke-DashboardMode {
    param(
        [int]$RefreshMs = 200   # 5 FPS = fluido y no asfixia la CPU
    )

    # Limpiar pantalla y ocultar cursor al entrar
    Clear-Host
    [Console]::CursorVisible = $false

    $bufferSize = 50
    $cpuHistory  = New-Object 'System.Collections.Generic.List[int]'
    $gpuHistory  = New-Object 'System.Collections.Generic.List[int]'
    $ramHistory  = New-Object 'System.Collections.Generic.List[int]'
    $netHistory  = New-Object 'System.Collections.Generic.List[int]'

    $startTime = Get-Date
    $peakCPU = 0; $peakGPU = 0; $peakRAM = 0; $peakTemp = 0
    $sampleCount = 0
    $frameCount = 0

    # Cache de valores (se actualizan menos seguido que el render)
    $cpu = 0; $gpu = @{ Usage=0; Temp=0 }; $ram = @{ Percent=0; UsedGB=0; TotalGB=0 }
    $cpuTemp = 0; $netMbps = 0; $disks = @()

    # Primera muestra rapida (antes del loop, asi no arranca vacio)
    $ram = Get-QuickRAM
    $gpu = Get-QuickGPU
    $disks = Get-QuickDisks
    $cpuTemp = Get-QuickCPUTemp

    try {
        while ($true) {
            $frameCount++
            $loopStart = Get-Date

            # Sampleo escalonado: CPU cada 1s (Get-Counter ya tiene SampleInterval=1),
            # resto cada 2s, discos cada 5s
            if ($frameCount % 5 -eq 1) {
                # CPU: rapido con Get-Counter
                $cpu = Get-QuickCPU
                $cpuHistory.Add($cpu) | Out-Null
                while ($cpuHistory.Count -gt $bufferSize) { $cpuHistory.RemoveAt(0) }
                $peakCPU = [math]::Max($peakCPU, $cpu)
                $sampleCount++
            }
            if ($frameCount % 10 -eq 2) {
                $ram = Get-QuickRAM
                $ramHistory.Add($ram.Percent) | Out-Null
                while ($ramHistory.Count -gt $bufferSize) { $ramHistory.RemoveAt(0) }
                $peakRAM = [math]::Max($peakRAM, $ram.Percent)
            }
            if ($frameCount % 10 -eq 3) {
                $gpu = Get-QuickGPU
                $gpuHistory.Add($gpu.Usage) | Out-Null
                while ($gpuHistory.Count -gt $bufferSize) { $gpuHistory.RemoveAt(0) }
                $peakGPU = [math]::Max($peakGPU, $gpu.Usage)
                $peakTemp = [math]::Max($peakTemp, $gpu.Temp)
            }
            if ($frameCount % 10 -eq 4) {
                $netMbps = Get-QuickNetRate
                $netHistory.Add($netMbps) | Out-Null
                while ($netHistory.Count -gt $bufferSize) { $netHistory.RemoveAt(0) }
            }
            if ($frameCount % 25 -eq 0) {
                $disks = Get-QuickDisks
                $cpuTemp = Get-QuickCPUTemp
            }

            # --- RENDER ---
            [Console]::SetCursorPosition(0, 0)

            # Header
            $elapsed = (Get-Date) - $startTime
            $elapsedStr = '{0:D2}:{1:D2}:{2:D2}' -f $elapsed.Hours, $elapsed.Minutes, $elapsed.Seconds
            Write-UI ('=' * 78) -Color Cyan
            $headerLine = "  LIVE DASHBOARD  |  samples: $sampleCount  |  elapsed: $elapsedStr  |  Q para salir   "
            Write-UI $headerLine.PadRight(78) -Color Green
            Write-UI ('=' * 78) -Color Cyan
            Write-UI (' ' * 78) -NoNewline  # linea en blanco

            # Lineas principales
            $cpuExtra = if ($cpuTemp -gt 0) { "$cpuTemp C" } else { '' }
            Show-DashboardLine -Label 'CPU' -Current $cpu -History $cpuHistory.ToArray() -Extra $cpuExtra

            $gpuExtra = if ($gpu.Temp -gt 0) { "$($gpu.Temp) C" } else { '' }
            Show-DashboardLine -Label 'GPU' -Current $gpu.Usage -History $gpuHistory.ToArray() -Extra $gpuExtra

            Show-DashboardLine -Label 'RAM' -Current $ram.Percent -History $ramHistory.ToArray() `
                -Extra ("{0}/{1}GB" -f $ram.UsedGB, $ram.TotalGB)

            # NET con escala adaptativa (max = pico visto o 100)
            $netMax = if ($netHistory.Count -gt 0) { [math]::Max(100, ($netHistory | Measure-Object -Maximum).Maximum) } else { 100 }
            Show-DashboardLine -Label 'NET' -Current $netMbps -History $netHistory.ToArray() `
                -Unit 'Mb' -Max $netMax -Extra ("pico $([int]$netMax) Mbps")

            # Separador
            Write-UI ('-' * 78) -Color DarkCyan

            # DISCOS
            Write-UI "  STORAGE" -Color Cyan
            foreach ($d in $disks) {
                $barWidth = 25
                $filled = [int](($d.Percent / 100) * $barWidth)
                $empty = $barWidth - $filled
                $color = Get-BarColor -Percent $d.Percent

                Write-UI ("  " + $d.Drive.PadRight(3) + " [") -Color Yellow -NoNewline
                Write-UI ($Global:GF.BlockFull.ToString() * $filled) -Color $color -NoNewline
                Write-UI ($Global:GF.BlockLight.ToString() * $empty) -Color DarkGreen -NoNewline
                Write-UI "] " -Color Cyan -NoNewline
                Write-UI ("{0,3}% " -f $d.Percent) -Color $color -NoNewline
                Write-UI (("{0}/{1} GB" -f $d.UsedGB, $d.TotalGB).PadRight(25)) -Color DarkGray
            }

            # Padding para tapar lineas viejas si el numero de discos bajo
            for ($i = $disks.Count; $i -lt 6; $i++) {
                Write-UI (' ' * 78)
            }

            # TOP PROCESOS (cada 10 frames)
            if ($frameCount % 10 -eq 5 -or -not $script:topProcs) {
                try {
                    $script:topProcs = Get-Process -ErrorAction SilentlyContinue |
                                       Where-Object { $_.CPU -gt 0 } |
                                       Sort-Object CPU -Descending |
                                       Select-Object -First 5
                } catch { $script:topProcs = @() }
            }

            Write-UI ('-' * 78) -Color DarkCyan
            Write-UI "  TOP PROCESOS (por tiempo CPU acumulado)" -Color Cyan
            foreach ($p in $script:topProcs) {
                $ramMB = [math]::Round($p.WorkingSet64 / 1MB, 0)
                $cpuSec = [math]::Round($p.CPU, 1)
                $line = ("    {0,-25}  CPU {1,8}s   RAM {2,5} MB" -f $p.ProcessName, $cpuSec, $ramMB)
                Write-UI $line.PadRight(78) -Color Green
            }
            # Padding
            for ($i = $script:topProcs.Count; $i -lt 5; $i++) {
                Write-UI (' ' * 78)
            }

            Write-UI ('=' * 78) -Color Cyan

            # Detectar tecla Q sin bloquear
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if ($key.Key -eq 'Q' -or $key.Key -eq 'Escape') { break }
            }

            # Ajustar sleep para mantener frame rate
            $loopMs = ((Get-Date) - $loopStart).TotalMilliseconds
            $sleepMs = [int]($RefreshMs - $loopMs)
            if ($sleepMs -gt 10) { Start-Sleep -Milliseconds $sleepMs }
        }
    } finally {
        [Console]::CursorVisible = $true
        Clear-Host
    }

    Write-UI "  Dashboard cerrado." -Color Green
    Write-UI ("  Muestras: $sampleCount  |  Peaks: CPU " + $peakCPU + "%  GPU " + $peakGPU + "%  RAM " + $peakRAM + "%") -Color Green
    Write-Log -Level INFO -Message "Dashboard cerrado. Samples=$sampleCount"
}

Export-ModuleMember -Function Invoke-DashboardMode, ConvertTo-Sparkline, Get-BarColor
