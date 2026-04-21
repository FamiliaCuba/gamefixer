# ============================================================================
#  modules/AutoFix.psm1
#  Pipeline automatico: diagnostico + benchmark before + limpieza +
#  optimizacion + reparacion rapida + benchmark after + reporte
# ============================================================================

function Invoke-AutoFix {
    Show-Section "AUTO-FIX (MODO UNA TECLA)"

    Write-UI "Este modo ejecutara automaticamente:" -Color Yellow
    Write-UI "  1. Punto de restauracion del sistema" -Color Green
    Write-UI "  2. Benchmark inicial (ANTES)" -Color Green
    Write-UI "  3. Diagnostico completo" -Color Green
    Write-UI "  4. Limpieza de temporales y cache" -Color Green
    Write-UI "  5. Optimizacion Gamer (tweaks de registro)" -Color Green
    Write-UI "  6. Limpieza de shader cache GPU" -Color Green
    Write-UI "  7. Flush DNS" -Color Green
    Write-UI "  8. Benchmark final (DESPUES) con comparativa" -Color Green
    Write-UI "  9. Generacion de reporte HTML" -Color Green
    Write-Host ""
    Write-UI "  Duracion estimada: 5-10 minutos." -Color DarkGray
    Write-Host ""

    if ($Global:GF.DryRun) {
        Write-UI "  [!] DRY-RUN activo: el AutoFix NO modificara nada." -Color DarkYellow
        Write-UI "  [?] Ejecutar de todos modos en modo simulacion? (s/N): " -Color Yellow -NoNewline
    } else {
        Write-UI "  [?] Confirmar ejecucion en modo LIVE? (s/N): " -Color Yellow -NoNewline
    }
    $r = Read-Host
    if ($r.Trim().ToLower() -ne 's') {
        Write-UI "  Cancelado." -Color DarkGray
        return
    }

    $startTime = Get-Date
    $pipeline = [ordered]@{
        StartedAt    = $startTime.ToString('yyyy-MM-dd HH:mm:ss')
        DryRun       = $Global:GF.DryRun
        Steps        = @()
        BenchBefore  = $null
        BenchAfter   = $null
        ElapsedSec   = 0
    }

    # Paso 1: Restore point
    Write-Host ""
    Write-UI "[1/9] Punto de restauracion..." -Color Cyan
    try {
        if (-not $Global:GF.DryRun) {
            Enable-ComputerRestore -Drive 'C:\' -ErrorAction SilentlyContinue
            Checkpoint-Computer -Description "GameFixer AutoFix $(Get-Date -Format 'HH:mm')" -RestorePointType 'MODIFY_SETTINGS' -ErrorAction SilentlyContinue
        }
        $pipeline.Steps += @{ Name='Restore point'; Status='OK' }
        Write-UI "      OK" -Color Green
    } catch {
        $pipeline.Steps += @{ Name='Restore point'; Status='FAIL'; Error=$_.Exception.Message }
        Write-UI "      FAIL (continuando)" -Color Yellow
    }

    # Paso 2: Bench before
    Write-Host ""
    Write-UI "[2/9] Benchmark ANTES..." -Color Cyan
    try {
        $pipeline.BenchBefore = @{
            CPU     = Invoke-CPUBenchmark
            RAM     = Invoke-RAMBenchmark
            Disk    = Invoke-DiskBenchmark
            Network = Invoke-NetworkBenchmark
        }
        $pipeline.Steps += @{ Name='Bench before'; Status='OK' }
    } catch {
        $pipeline.Steps += @{ Name='Bench before'; Status='FAIL'; Error=$_.Exception.Message }
    }

    # Paso 3: Diagnostico rapido
    Write-Host ""
    Write-UI "[3/9] Diagnostico rapido..." -Color Cyan
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
        $diskFreePct = [int](($disk.FreeSpace / $disk.Size) * 100)
        Write-UI ("      OS: " + $os.Caption) -Color Green
        Write-UI ("      Disco C: libre: $diskFreePct%") -Color Green
        $pipeline.Steps += @{ Name='Diagnostico'; Status='OK'; DiskFreePct=$diskFreePct }
    } catch {
        $pipeline.Steps += @{ Name='Diagnostico'; Status='FAIL' }
    }

    # Paso 4: Limpieza
    Write-Host ""
    Write-UI "[4/9] Limpieza de temporales..." -Color Cyan
    $freedMB = 0
    try {
        $paths = @("$env:TEMP","$env:SystemRoot\Temp","$env:SystemRoot\SoftwareDistribution\Download")
        foreach ($p in $paths) {
            if (Test-Path $p) {
                $before = (Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
                if (-not $Global:GF.DryRun) {
                    Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue |
                        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                }
                $freedMB += [math]::Round($before / 1MB, 0)
            }
        }
        if (-not $Global:GF.DryRun) {
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        }
        Write-UI ("      Liberados ~" + $freedMB + " MB") -Color Green
        $pipeline.Steps += @{ Name='Limpieza'; Status='OK'; FreedMB=$freedMB }
    } catch {
        $pipeline.Steps += @{ Name='Limpieza'; Status='FAIL' }
    }

    # Paso 5: Optimizacion Gamer
    Write-Host ""
    Write-UI "[5/9] Optimizacion Gamer..." -Color Cyan
    try {
        if (-not $Global:GF.DryRun) {
            # Plan Ultimate/Alto rendimiento
            $list = powercfg /list
            $guid = $null
            foreach ($l in $list) { if ($l -match 'Ultimate' -and $l -match '([a-f0-9\-]{36})') { $guid = $matches[1]; break } }
            if (-not $guid) {
                powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null
                $list = powercfg /list
                foreach ($l in $list) { if ($l -match 'Ultimate' -and $l -match '([a-f0-9\-]{36})') { $guid = $matches[1]; break } }
            }
            if ($guid) { powercfg /setactive $guid }

            # Game Mode
            $k1 = 'HKCU:\Software\Microsoft\GameBar'
            if (-not (Test-Path $k1)) { New-Item -Path $k1 -Force | Out-Null }
            Set-ItemProperty -Path $k1 -Name 'AutoGameModeEnabled' -Value 1 -Type DWord -Force

            # GameDVR off
            $k2 = 'HKCU:\System\GameConfigStore'
            if (Test-Path $k2) {
                Set-ItemProperty -Path $k2 -Name 'GameDVR_Enabled' -Value 0 -Type DWord -Force
            }

            # MMCSS
            $k3 = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
            Set-ItemProperty -Path $k3 -Name 'SystemResponsiveness' -Value 10 -Type DWord -Force
        }
        Write-UI "      OK (power plan + game mode + gamedvr + mmcss)" -Color Green
        $pipeline.Steps += @{ Name='Optimizacion'; Status='OK' }
    } catch {
        $pipeline.Steps += @{ Name='Optimizacion'; Status='FAIL'; Error=$_.Exception.Message }
    }

    # Paso 6: Shader cache GPU
    Write-Host ""
    Write-UI "[6/9] Limpieza shader cache GPU..." -Color Cyan
    try {
        $caches = @("$env:LOCALAPPDATA\NVIDIA\DXCache","$env:LOCALAPPDATA\NVIDIA\GLCache","$env:LOCALAPPDATA\D3DSCache")
        foreach ($c in $caches) {
            if ((Test-Path $c) -and -not $Global:GF.DryRun) {
                Get-ChildItem $c -Recurse -Force -ErrorAction SilentlyContinue |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        Write-UI "      OK" -Color Green
        $pipeline.Steps += @{ Name='Shader cache'; Status='OK' }
    } catch {
        $pipeline.Steps += @{ Name='Shader cache'; Status='FAIL' }
    }

    # Paso 7: Flush DNS
    Write-Host ""
    Write-UI "[7/9] Flush DNS..." -Color Cyan
    try {
        if (-not $Global:GF.DryRun) {
            ipconfig /flushdns | Out-Null
        }
        Write-UI "      OK" -Color Green
        $pipeline.Steps += @{ Name='Flush DNS'; Status='OK' }
    } catch {
        $pipeline.Steps += @{ Name='Flush DNS'; Status='FAIL' }
    }

    # Paso 8: Bench after
    Write-Host ""
    Write-UI "[8/9] Benchmark DESPUES..." -Color Cyan
    try {
        $pipeline.BenchAfter = @{
            CPU     = Invoke-CPUBenchmark
            RAM     = Invoke-RAMBenchmark
            Disk    = Invoke-DiskBenchmark
            Network = Invoke-NetworkBenchmark
        }
        $pipeline.Steps += @{ Name='Bench after'; Status='OK' }
    } catch {
        $pipeline.Steps += @{ Name='Bench after'; Status='FAIL' }
    }

    # Paso 9: Reporte
    Write-Host ""
    Write-UI "[9/9] Generando reporte HTML..." -Color Cyan
    $pipeline.ElapsedSec = [int]((Get-Date) - $startTime).TotalSeconds
    try {
        $reportPath = New-HtmlReport -Pipeline $pipeline
        Write-UI ("      Reporte: " + $reportPath) -Color Green
        $pipeline.Steps += @{ Name='Reporte HTML'; Status='OK'; Path=$reportPath }

        Write-Host ""
        Write-UI "  [?] Abrir reporte en el navegador? (s/N): " -Color Yellow -NoNewline
        $ans = Read-Host
        if ($ans.Trim().ToLower() -eq 's') {
            Start-Process $reportPath
        }
    } catch {
        Write-UI ("      FAIL: " + $_.Exception.Message) -Color Yellow
        $pipeline.Steps += @{ Name='Reporte HTML'; Status='FAIL' }
    }

    Write-Host ""
    Write-UI ("=" * 72) -Color DarkGreen
    Write-UI ("  AutoFix completado en " + $pipeline.ElapsedSec + " segundos.") -Color Green
    Write-Log -Level INFO -Message "AutoFix finalizado en $($pipeline.ElapsedSec)s - $(($pipeline.Steps | Where-Object Status -eq 'OK').Count)/$($pipeline.Steps.Count) pasos OK"
}

Export-ModuleMember -Function Invoke-AutoFix
