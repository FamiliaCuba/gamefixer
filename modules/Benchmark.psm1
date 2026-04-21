# ============================================================================
#  modules/Benchmark.psm1
#  Benchmarks de CPU, RAM, disco (multi-drive), red (adaptativo)
#  v2.04: disk testa todos los drives + red usa 100MB o medicion por tiempo
# ============================================================================

function Invoke-BenchmarkMenu {
    do {
        Show-Section "BENCHMARKS"

        Write-UI "  [1] Benchmark COMPLETO (CPU + RAM + Todos los discos + Red)" -Color Yellow
        Write-UI "  [2] CPU solo (calculos matematicos)" -Color Yellow
        Write-UI "  [3] RAM solo (velocidad de memoria)" -Color Yellow
        Write-UI "  [4] Disco TODOS (escanea cada drive)" -Color Yellow
        Write-UI "  [5] Disco especifico (elegir letra)" -Color Yellow
        Write-UI "  [6] Red (ping + velocidad adaptativa)" -Color Yellow
        Write-UI "  [7] Ver historico" -Color Yellow
        Write-UI "  [8] Comparar ultimo vs anterior" -Color Yellow
        Write-UI "  [B] Volver al menu principal" -Color Yellow
        Write-Host ""
        Write-UI "  > " -Color Cyan -NoNewline
        $sub = (Read-Host).Trim().ToUpper()

        switch ($sub) {
            '1' { Invoke-FullBenchmark }
            '2' { $r = Invoke-CPUBenchmark;  Show-BenchResult -Result $r; Save-BenchResult -Type 'CPU'  -Result $r }
            '3' { $r = Invoke-RAMBenchmark;  Show-BenchResult -Result $r; Save-BenchResult -Type 'RAM'  -Result $r }
            '4' { $r = Invoke-DiskBenchmark; Save-BenchResult -Type 'Disk' -Result $r }
            '5' { Invoke-DiskBenchmarkPrompt }
            '6' { $r = Invoke-NetworkBenchmark; Show-BenchResult -Result $r; Save-BenchResult -Type 'Network' -Result $r }
            '7' { Show-BenchHistory }
            '8' { Compare-LastBench }
            'B' { return }
            default { Write-UI "  [!] Opcion invalida" -Color Red; Start-Sleep -Seconds 1 }
        }

        if ($sub -match '^[1-8]$') {
            Write-Host ""
            Write-UI "  Presiona ENTER para continuar en el menu de Benchmarks..." -Color DarkGreen -NoNewline
            [void](Read-Host)
        }
    } while ($true)
}

# ============================================================================
#  CPU
# ============================================================================
function Invoke-CPUBenchmark {
    Write-Host ""
    Write-UI "[CPU] Benchmark en ejecucion..." -Color Cyan

    # Single-thread
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $iter = 3000000
    $sum = 0.0
    for ($i = 1; $i -le $iter; $i++) {
        $sum += [math]::Sqrt($i) * [math]::Sin($i)
    }
    $sw.Stop()
    $singleMs = $sw.ElapsedMilliseconds

    # Multi-thread con jobs
    $cores = [Environment]::ProcessorCount
    $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
    $jobs = @()
    for ($c = 0; $c -lt $cores; $c++) {
        $jobs += Start-Job -ScriptBlock {
            $s = 0.0
            for ($i = 1; $i -le 500000; $i++) { $s += [math]::Sqrt($i) }
            return $s
        }
    }
    $jobs | Wait-Job | Out-Null
    $jobs | Remove-Job -Force
    $sw2.Stop()
    $multiMs = $sw2.ElapsedMilliseconds

    $singleScore = [int]($iter / ($singleMs / 1000))
    $multiScore  = [int](($cores * 500000) / ($multiMs / 1000))

    Write-Log -Level INFO -Message "Bench CPU: single=$singleScore, multi=$multiScore ($cores cores)"

    return [pscustomobject]@{
        Type        = 'CPU'
        Timestamp   = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        SingleScore = $singleScore
        MultiScore  = $multiScore
        SingleMs    = $singleMs
        MultiMs     = $multiMs
        Cores       = $cores
        Summary     = "$singleScore single / $multiScore multi ops/s"
    }
}

# ============================================================================
#  RAM
# ============================================================================
function Invoke-RAMBenchmark {
    Write-Host ""
    Write-UI "[RAM] Benchmark en ejecucion..." -Color Cyan

    $sizeMB = 256
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $bytes = [byte[]]::new($sizeMB * 1MB)
    for ($i = 0; $i -lt $bytes.Length; $i += 4096) {
        $bytes[$i] = 0xAB
    }
    $sw.Stop()
    $writeMs = $sw.ElapsedMilliseconds

    $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
    $sum = 0
    for ($i = 0; $i -lt $bytes.Length; $i += 4096) {
        $sum = $sum -bxor $bytes[$i]
    }
    $sw2.Stop()
    $readMs = $sw2.ElapsedMilliseconds

    $bytes = $null
    [System.GC]::Collect()

    $writeMBs = if ($writeMs -gt 0) { [math]::Round($sizeMB * 1000 / $writeMs, 0) } else { 0 }
    $readMBs  = if ($readMs -gt 0)  { [math]::Round($sizeMB * 1000 / $readMs, 0)  } else { 0 }

    Write-Log -Level INFO -Message "Bench RAM: write=${writeMBs}MB/s, read=${readMBs}MB/s"

    return [pscustomobject]@{
        Type      = 'RAM'
        Timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        WriteMBs  = $writeMBs
        ReadMBs   = $readMBs
        SizeMB    = $sizeMB
        Summary   = "Write ${writeMBs}MB/s | Read ${readMBs}MB/s"
    }
}

# ============================================================================
#  DISK - Multi-drive con letra especifica o TODOS
# ============================================================================
function Invoke-DiskBenchmark {
    param([string]$Drive = $null)

    Write-Host ""

    # Si se pide todos
    if (-not $Drive) {
        $drives = @()
        try {
            $drives = @(Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
                        Where-Object { $_.FreeSpace -gt 500MB } |
                        Select-Object -ExpandProperty DeviceID)
        } catch { $drives = @('C:') }

        if ($drives.Count -eq 0) { $drives = @('C:') }

        Write-UI ("[DISK] Benchmarking " + $drives.Count + " disco(s): " + ($drives -join ', ')) -Color Cyan

        $perDisk = @()
        foreach ($d in $drives) {
            $r = Invoke-DiskBenchmarkSingle -Drive $d
            if ($r) {
                $perDisk += $r
                $typeTag = if ($r.IsSSD) { 'SSD' } else { 'HDD' }
                Write-UI ("       [$d $typeTag] Write $($r.WriteMBs) MB/s | Read $($r.ReadMBs) MB/s") -Color Green
            }
        }

        # Agregado para compatibilidad con reports/historial
        $avgRead  = if ($perDisk.Count -gt 0) { [int]($perDisk | Measure-Object ReadMBs  -Average).Average } else { 0 }
        $avgWrite = if ($perDisk.Count -gt 0) { [int]($perDisk | Measure-Object WriteMBs -Average).Average } else { 0 }
        $maxRead  = if ($perDisk.Count -gt 0) { [int]($perDisk | Measure-Object ReadMBs  -Maximum).Maximum } else { 0 }
        $maxWrite = if ($perDisk.Count -gt 0) { [int]($perDisk | Measure-Object WriteMBs -Maximum).Maximum } else { 0 }

        $agg = [pscustomobject]@{
            Type      = 'Disk'
            Timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            WriteMBs  = $avgWrite
            ReadMBs   = $avgRead
            MaxWriteMBs = $maxWrite
            MaxReadMBs  = $maxRead
            DriveCount  = $perDisk.Count
            PerDisk     = $perDisk
            Summary     = ("$($perDisk.Count) discos: avg Read $avgRead MB/s / Write $avgWrite MB/s")
        }
        Write-Log -Level INFO -Message "Bench Disk multi: $($perDisk.Count) disks, avg read ${avgRead}MB/s"
        return $agg
    }

    return Invoke-DiskBenchmarkSingle -Drive $Drive
}

function Invoke-DiskBenchmarkSingle {
    param([string]$Drive)

    $letter = $Drive.TrimEnd('\').TrimEnd(':')
    $rootPath = $letter + ':\'
    $testDir = Join-Path $rootPath 'gfbench-tmp'

    try {
        if (-not (Test-Path $testDir)) { New-Item -ItemType Directory -Path $testDir -Force | Out-Null }
    } catch {
        Write-UI ("       [!] No se pudo acceder a " + $Drive) -Color Yellow
        return $null
    }

    $testFile = Join-Path $testDir ("bench-" + (Get-Random) + ".bin")
    $sizeMB = 256
    $buffer = [byte[]]::new(1MB)
    (New-Object Random).NextBytes($buffer)

    # Write test (secuencial, sin bufferizar a memoria)
    $writeMs = 0
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $fs = [System.IO.File]::Create($testFile, 4MB, [System.IO.FileOptions]::WriteThrough)
        for ($i = 0; $i -lt $sizeMB; $i++) {
            $fs.Write($buffer, 0, $buffer.Length)
        }
        $fs.Flush($true)
        $fs.Close()
        $sw.Stop()
        $writeMs = $sw.ElapsedMilliseconds
    } catch {
        Write-UI ("       [!] Error escribiendo en " + $Drive + ": " + $_.Exception.Message) -Color Yellow
        if (Test-Path $testFile) { Remove-Item $testFile -Force -ErrorAction SilentlyContinue }
        return $null
    }

    # Read test (limpiar cache NT es complicado; usamos flag SequentialScan)
    $readMs = 0
    try {
        $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
        $fs2 = New-Object System.IO.FileStream($testFile, 'Open', 'Read', 'Read', 4MB, 'SequentialScan')
        $readBuf = [byte[]]::new(1MB)
        while ($fs2.Read($readBuf, 0, $readBuf.Length) -gt 0) { }
        $fs2.Close()
        $sw2.Stop()
        $readMs = $sw2.ElapsedMilliseconds
    } catch {
        Write-UI ("       [!] Error leyendo en " + $Drive + ": " + $_.Exception.Message) -Color Yellow
    }

    Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    Remove-Item $testDir  -Force -ErrorAction SilentlyContinue

    $writeMBs = if ($writeMs -gt 0) { [int]($sizeMB * 1000 / $writeMs) } else { 0 }
    $readMBs  = if ($readMs  -gt 0) { [int]($sizeMB * 1000 / $readMs)  } else { 0 }

    # Detectar si es SSD (heuristica por MediaType o por velocidad)
    $isSSD = $false
    try {
        $partition = Get-Partition -DriveLetter $letter -ErrorAction SilentlyContinue
        if ($partition) {
            $physicalDisk = Get-PhysicalDisk -ErrorAction SilentlyContinue |
                            Where-Object { $_.DeviceId -eq $partition.DiskNumber }
            if ($physicalDisk) {
                $isSSD = ($physicalDisk.MediaType -eq 'SSD') -or `
                         ($physicalDisk.BusType -eq 'NVMe')
            }
        }
    } catch {}
    # Fallback: velocidad alta sugiere SSD
    if (-not $isSSD -and $readMBs -gt 300) { $isSSD = $true }

    return [pscustomobject]@{
        Type      = 'Disk'
        Drive     = $Drive
        Timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        WriteMBs  = $writeMBs
        ReadMBs   = $readMBs
        SizeMB    = $sizeMB
        IsSSD     = $isSSD
        Summary   = "$Drive Read ${readMBs}MB/s | Write ${writeMBs}MB/s"
    }
}

function Invoke-DiskBenchmarkPrompt {
    Write-Host ""
    $drives = @(Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
                Select-Object -ExpandProperty DeviceID)
    Write-UI ("Discos disponibles: " + ($drives -join ', ')) -Color Cyan
    Write-UI "  Letra del disco (ej C): " -Color Yellow -NoNewline
    $letter = (Read-Host).Trim().ToUpper().TrimEnd(':')
    if ($letter.Length -eq 1) {
        $r = Invoke-DiskBenchmarkSingle -Drive ($letter + ':')
        if ($r) {
            Show-BenchResult -Result $r
            Save-BenchResult -Type 'Disk' -Result $r
        }
    }
}

# ============================================================================
#  NETWORK - adaptativo a conexion real
# ============================================================================
function Invoke-NetworkBenchmark {
    Write-Host ""
    Write-UI "[NET] Benchmark en ejecucion (ping + speed test adaptativo)..." -Color Cyan

    # Ping
    $pings = Test-Connection -ComputerName '1.1.1.1' -Count 5 -ErrorAction SilentlyContinue
    $avgPing = if ($pings) { [int]($pings | Measure-Object ResponseTime -Average).Average } else { -1 }
    $minPing = if ($pings) { [int]($pings | Measure-Object ResponseTime -Minimum).Minimum } else { -1 }
    $maxPing = if ($pings) { [int]($pings | Measure-Object ResponseTime -Maximum).Maximum } else { -1 }
    $jitter = if ($maxPing -ge 0 -and $minPing -ge 0) { $maxPing - $minPing } else { -1 }

    Write-UI ("       Ping: avg ${avgPing}ms | min ${minPing}ms | max ${maxPing}ms | jitter ${jitter}ms") -Color Green

    # Speed test adaptativo: arranca con 10MB, mide, y si fue <2s hace 100MB, si <2s hace 500MB
    # Esto funciona para cualquier velocidad (10 Mbps hasta 2 Gbps)
    $downMbps = 0
    $finalSizeMB = 0
    $finalSec = 0

    $probeSizes = @(10, 100, 500)  # MB
    $targetMinSec = 3  # queremos medir al menos 3s para precision

    foreach ($sz in $probeSizes) {
        $url = "https://speed.cloudflare.com/__down?bytes=$($sz * 1000000)"
        try {
            Write-UI ("       Descargando ${sz} MB...") -Color DarkGreen
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $tmp = [System.IO.Path]::GetTempFileName()
            Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -TimeoutSec 60
            $sw.Stop()
            $realSizeMB = (Get-Item $tmp).Length / 1MB
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue

            $elapsedSec = $sw.Elapsed.TotalSeconds
            $mbps = [math]::Round($realSizeMB * 8 / $elapsedSec, 1)

            Write-UI ("         -> $mbps Mbps en ${elapsedSec:N1}s") -Color DarkGreen

            # Si el test duro menos de 3s y hay probe mas grande, continuar
            $downMbps = $mbps
            $finalSizeMB = [int]$realSizeMB
            $finalSec = [math]::Round($elapsedSec, 1)

            if ($elapsedSec -ge $targetMinSec) {
                # Ya tenemos una medicion decente, parar
                break
            }
            if ($sz -eq $probeSizes[-1]) {
                # Era el ultimo probe, terminar
                break
            }
            # Conexion rapida, seguir con siguiente probe
        } catch {
            Write-UI ("       [!] Fallo probe ${sz}MB: " + $_.Exception.Message) -Color Yellow
            break
        }
    }

    # Calidad de la conexion para gaming
    $gamingQuality = 'Pobre'
    if ($avgPing -gt 0 -and $avgPing -le 30 -and $jitter -le 10 -and $downMbps -ge 25) {
        $gamingQuality = 'Excelente'
    } elseif ($avgPing -gt 0 -and $avgPing -le 60 -and $jitter -le 20 -and $downMbps -ge 10) {
        $gamingQuality = 'Buena'
    } elseif ($avgPing -gt 0 -and $avgPing -le 100 -and $downMbps -ge 5) {
        $gamingQuality = 'Aceptable'
    }

    Write-UI ("       Calidad para gaming: $gamingQuality") -Color Green
    Write-Log -Level INFO -Message "Bench Net: ping=${avgPing}ms jitter=${jitter}ms down=${downMbps}Mbps quality=$gamingQuality"

    return [pscustomobject]@{
        Type          = 'Network'
        Timestamp     = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        PingMs        = $avgPing
        PingMinMs     = $minPing
        PingMaxMs     = $maxPing
        JitterMs      = $jitter
        DownMbps      = $downMbps
        TestSizeMB    = $finalSizeMB
        TestDurationS = $finalSec
        GamingQuality = $gamingQuality
        Summary       = "Ping ${avgPing}ms (jitter ${jitter}ms) | Down ${downMbps}Mbps | $gamingQuality"
    }
}

# ============================================================================
#  FULL BENCHMARK
# ============================================================================
function Invoke-FullBenchmark {
    Write-Host ""
    Write-UI "=== BENCHMARK COMPLETO ===" -Color Cyan
    Write-UI "  Duracion estimada: 60-120s segun velocidad de red e I/O." -Color DarkGray
    Write-Host ""

    $results = [pscustomobject]@{
        Timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        CPU       = Invoke-CPUBenchmark
        RAM       = Invoke-RAMBenchmark
        Disk      = Invoke-DiskBenchmark
        Network   = Invoke-NetworkBenchmark
    }

    Write-Host ""
    Write-UI "=== RESULTADOS ===" -Color Cyan
    Show-BenchResult -Result $results.CPU
    Show-BenchResult -Result $results.RAM
    Write-UI ("  [Disk    ] " + $results.Disk.Summary) -Color Green
    if ($results.Disk.PerDisk) {
        foreach ($d in $results.Disk.PerDisk) {
            $tag = if ($d.IsSSD) { 'SSD' } else { 'HDD' }
            Write-UI ("              - [$($d.Drive) $tag] Read $($d.ReadMBs)MB/s | Write $($d.WriteMBs)MB/s") -Color DarkGreen
        }
    }
    Show-BenchResult -Result $results.Network

    # Score global
    $score = 0
    if ($results.CPU.SingleScore)   { $score += [math]::Min(100, $results.CPU.SingleScore / 30000 * 100) * 0.25 }
    if ($results.CPU.MultiScore)    { $score += [math]::Min(100, $results.CPU.MultiScore / 200000 * 100) * 0.20 }
    if ($results.RAM.ReadMBs)       { $score += [math]::Min(100, $results.RAM.ReadMBs / 8000 * 100) * 0.15 }
    if ($results.Disk.MaxReadMBs)   { $score += [math]::Min(100, $results.Disk.MaxReadMBs / 3000 * 100) * 0.20 }
    if ($results.Network.DownMbps)  { $score += [math]::Min(100, $results.Network.DownMbps / 500 * 100) * 0.20 }
    $score = [int]$score

    $scoreColor = 'Red'
    if ($score -ge 75)      { $scoreColor = 'Green' }
    elseif ($score -ge 50)  { $scoreColor = 'Yellow' }

    Write-Host ""
    Write-UI ("  GAMING SCORE GLOBAL: " + $score + "/100") -Color $scoreColor
    Write-Host ""

    $results | Add-Member -NotePropertyName 'GlobalScore' -NotePropertyValue $score -Force
    Save-BenchResult -Type 'Full' -Result $results
}

function Show-BenchResult {
    param($Result)
    $t = $Result.Type.PadRight(8)
    Write-UI ("  [$t] " + $Result.Summary) -Color Green
}

function Save-BenchResult {
    param([string]$Type, $Result)
    $benchDir = Join-Path $Global:GF.Root 'benchmarks'
    if (-not (Test-Path $benchDir)) { New-Item -ItemType Directory -Path $benchDir -Force | Out-Null }

    $file = Join-Path $benchDir 'history.json'
    $history = @()
    if (Test-Path $file) {
        try { $history = @(Get-Content $file -Raw | ConvertFrom-Json) } catch {}
    }
    $history = @($history) + @($Result)
    if ($history.Count -gt 50) { $history = $history[-50..-1] }
    $history | ConvertTo-Json -Depth 6 | Set-Content -Path $file -Encoding UTF8
    Write-UI "  Guardado en historico: $file" -Color DarkGray
}

function Show-BenchHistory {
    Write-Host ""
    $file = Join-Path $Global:GF.Root 'benchmarks\history.json'
    if (-not (Test-Path $file)) {
        Write-UI "  No hay historico todavia." -Color Yellow
        return
    }
    $history = @(Get-Content $file -Raw | ConvertFrom-Json)
    Write-UI ("Historico (" + $history.Count + " entradas):") -Color Cyan
    foreach ($h in $history | Select-Object -Last 20) {
        $tag = if ($h.Type) { $h.Type } else { 'Full' }
        $summary = if ($h.Summary) { $h.Summary } elseif ($h.GlobalScore) { "Score global: $($h.GlobalScore)/100" } else { '' }
        Write-UI ("  [" + $h.Timestamp + "] [$tag] $summary") -Color Green
    }
}

function Compare-LastBench {
    Write-Host ""
    $file = Join-Path $Global:GF.Root 'benchmarks\history.json'
    if (-not (Test-Path $file)) {
        Write-UI "  Sin historico." -Color Yellow
        return
    }
    $history = @(Get-Content $file -Raw | ConvertFrom-Json | Where-Object { $_.GlobalScore })
    if ($history.Count -lt 2) {
        Write-UI "  Necesitas al menos 2 benchmarks completos." -Color Yellow
        return
    }
    $prev = $history[-2]
    $last = $history[-1]

    Write-UI "=== COMPARATIVA ===" -Color Cyan
    Write-UI ("  Anterior: " + $prev.Timestamp + "  (score " + $prev.GlobalScore + ")") -Color DarkGray
    Write-UI ("  Ultimo  : " + $last.Timestamp + "  (score " + $last.GlobalScore + ")") -Color DarkGray
    Write-Host ""

    $diff = $last.GlobalScore - $prev.GlobalScore
    $color = if ($diff -gt 0) { 'Green' } elseif ($diff -lt 0) { 'Red' } else { 'DarkGray' }
    $sign = if ($diff -gt 0) { '+' } else { '' }
    Write-UI ("  Diferencia global: $sign$diff puntos") -Color $color

    $cats = @(
        @{ Name='CPU Single'; Prev=$prev.CPU.SingleScore;       Last=$last.CPU.SingleScore;       Unit='ops/s' },
        @{ Name='CPU Multi ';  Prev=$prev.CPU.MultiScore;        Last=$last.CPU.MultiScore;        Unit='ops/s' },
        @{ Name='RAM Read  ';  Prev=$prev.RAM.ReadMBs;           Last=$last.RAM.ReadMBs;           Unit='MB/s'  },
        @{ Name='Disk MaxR ';  Prev=$prev.Disk.MaxReadMBs;       Last=$last.Disk.MaxReadMBs;       Unit='MB/s'  },
        @{ Name='Net Down  ';  Prev=$prev.Network.DownMbps;      Last=$last.Network.DownMbps;      Unit='Mbps'  },
        @{ Name='Net Ping  ';  Prev=$prev.Network.PingMs;        Last=$last.Network.PingMs;        Unit='ms'; LowerBetter=$true }
    )
    foreach ($c in $cats) {
        if ($null -eq $c.Prev -or $null -eq $c.Last -or $c.Prev -eq 0) { continue }
        $delta = $c.Last - $c.Prev
        $pct = [math]::Round(($delta / $c.Prev) * 100, 1)
        $isBetter = if ($c.LowerBetter) { $pct -lt 0 } else { $pct -gt 0 }
        $col = if ($pct -eq 0) { 'DarkGray' } elseif ($isBetter) { 'Green' } else { 'Red' }
        $signP = if ($pct -gt 0) { '+' } else { '' }
        Write-UI ("  " + $c.Name + "  " + $c.Prev + " -> " + $c.Last + " " + $c.Unit + "  (" + $signP + $pct + "%)") -Color $col
    }
}

Export-ModuleMember -Function Invoke-BenchmarkMenu, Invoke-FullBenchmark, `
    Invoke-CPUBenchmark, Invoke-RAMBenchmark, Invoke-DiskBenchmark, Invoke-DiskBenchmarkSingle, `
    Invoke-DiskBenchmarkPrompt, Invoke-NetworkBenchmark, `
    Show-BenchResult, Save-BenchResult, Show-BenchHistory, Compare-LastBench
