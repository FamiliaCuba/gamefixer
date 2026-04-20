# ============================================================================
#  modules/OptimizacionGamer.psm1
#  Tweaks de optimizacion para gaming
# ============================================================================

function Invoke-OptimizacionGamer {
    Show-Section "OPTIMIZACION GAMER"

    Write-UI "Este modulo aplica las siguientes optimizaciones:" -Color Cyan
    Write-UI "  - Plan de energia: Alto rendimiento (o Ultimate si existe)" -Color Green
    Write-UI "  - Game Mode y GameBar (configurar/desactivar)" -Color Green
    Write-UI "  - Desactivar notificaciones de Focus Assist durante juego" -Color Green
    Write-UI "  - Optimizacion de red (TCP Ack Frequency, Nagle)" -Color Green
    Write-UI "  - Priority de servicios de gaming" -Color Green
    Write-UI "  - Desactivar Xbox Game Monitoring si no se usa" -Color Green
    Write-Host ""

    # Backup de registro antes de tocar nada
    Backup-RegistryKeys

    # --- 1. Plan de energia ---
    Write-UI "[1/6] Plan de energia" -Color Cyan
    Invoke-LoggedAction -Description "Buscar plan Ultimate Performance" -AlwaysRun -Action {
        $ultimate = powercfg /list | Select-String 'Ultimate'
        if (-not $ultimate) {
            Write-UI "       Ultimate Performance no existe, se creara." -Color DarkYellow
        }
    }
    Invoke-LoggedAction -Description "Activar plan Ultimate/Alto rendimiento" -Action {
        $existing = powercfg /list | Select-String 'Ultimate'
        if (-not $existing) {
            powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null
        }
        $list = powercfg /list
        $guid = $null
        foreach ($line in $list) {
            if ($line -match 'Ultimate') {
                if ($line -match '([a-f0-9\-]{36})') { $guid = $matches[1]; break }
            }
        }
        if (-not $guid) {
            foreach ($line in $list) {
                if ($line -match 'Alto rendimiento|High performance') {
                    if ($line -match '([a-f0-9\-]{36})') { $guid = $matches[1]; break }
                }
            }
        }
        if ($guid) {
            powercfg /setactive $guid
            Write-UI "       Plan activado: $guid" -Color Green
        }
    }

    # --- 2. TCP Nagle off + Ack Frequency ---
    Write-UI "[2/6] Tweaks de red TCP (reducir latencia)" -Color Cyan
    Invoke-LoggedAction -Description "Desactivar algoritmo de Nagle (TcpAckFrequency=1, TCPNoDelay=1)" -Action {
        $interfaces = Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
        foreach ($iface in $interfaces) {
            $props = Get-ItemProperty -Path $iface.PSPath -ErrorAction SilentlyContinue
            if ($props.PSObject.Properties.Name -contains 'IPAddress' -or $props.PSObject.Properties.Name -contains 'DhcpIPAddress') {
                Set-ItemProperty -Path $iface.PSPath -Name 'TcpAckFrequency' -Value 1 -Type DWord -Force
                Set-ItemProperty -Path $iface.PSPath -Name 'TCPNoDelay'      -Value 1 -Type DWord -Force
                Set-ItemProperty -Path $iface.PSPath -Name 'TcpDelAckTicks'  -Value 0 -Type DWord -Force
            }
        }
    }

    # --- 3. Game Mode ---
    Write-UI "[3/6] Game Mode" -Color Cyan
    Invoke-LoggedAction -Description "Activar Game Mode" -Action {
        $key = 'HKCU:\Software\Microsoft\GameBar'
        if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
        Set-ItemProperty -Path $key -Name 'AutoGameModeEnabled' -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $key -Name 'AllowAutoGameMode'   -Value 1 -Type DWord -Force
    }

    # --- 4. GameDVR off (overhead) ---
    Write-UI "[4/6] Desactivar GameDVR (background recording)" -Color Cyan
    Invoke-LoggedAction -Description "Desactivar GameDVR AppCaptureEnabled" -Action {
        $key = 'HKCU:\System\GameConfigStore'
        if (Test-Path $key) {
            Set-ItemProperty -Path $key -Name 'GameDVR_Enabled' -Value 0 -Type DWord -Force
        }
        $key2 = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'
        if (-not (Test-Path $key2)) { New-Item -Path $key2 -Force | Out-Null }
        Set-ItemProperty -Path $key2 -Name 'AppCaptureEnabled' -Value 0 -Type DWord -Force
    }

    # --- 5. Prioridad de juegos en MMCSS ---
    Write-UI "[5/6] Prioridad MMCSS para Games" -Color Cyan
    Invoke-LoggedAction -Description "Ajustar MMCSS Games SystemResponsiveness=10, GPU Priority=8" -Action {
        $key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
        Set-ItemProperty -Path $key -Name 'SystemResponsiveness' -Value 10 -Type DWord -Force
        $gameKey = "$key\Tasks\Games"
        if (Test-Path $gameKey) {
            Set-ItemProperty -Path $gameKey -Name 'GPU Priority' -Value 8 -Type DWord -Force
            Set-ItemProperty -Path $gameKey -Name 'Priority'     -Value 6 -Type DWord -Force
            Set-ItemProperty -Path $gameKey -Name 'Scheduling Category' -Value 'High' -Type String -Force
        }
    }

    # --- 6. Servicios innecesarios ---
    Write-UI "[6/6] Servicios no criticos (manual start)" -Color Cyan
    $servicesToDemote = @('SysMain','DiagTrack','WSearch')
    foreach ($svc in $servicesToDemote) {
        Invoke-LoggedAction -Description "Cambiar $svc a Manual" -Action {
            $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($s) {
                Set-Service -Name $svc -StartupType Manual -ErrorAction SilentlyContinue
                if ($s.Status -eq 'Running') { Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue }
            }
        }
    }

    Write-Host ""
    Write-UI ("=" * 72) -Color DarkGreen
    Write-UI "  Optimizacion completada. Reinicia para aplicar todos los cambios." -Color Green
}

function Backup-RegistryKeys {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = Join-Path $Global:GF.BackupsDir "regbackup-$stamp"
    if (-not (Test-Path $backup)) { New-Item -ItemType Directory -Path $backup -Force | Out-Null }

    $keys = @(
        'HKCU\Software\Microsoft\GameBar',
        'HKCU\System\GameConfigStore',
        'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
    )

    foreach ($k in $keys) {
        $safe = $k -replace '\\', '_' -replace ':', ''
        $out = Join-Path $backup "$safe.reg"
        Invoke-LoggedAction -Description "Backup registro: $k" -Action {
            reg export $k $out /y | Out-Null
        }
    }

    Write-Log -Level INFO -Message "Backup de registro en: $backup"
    Write-UI ("      Backup guardado en: $backup") -Color DarkGray
}

Export-ModuleMember -Function Invoke-OptimizacionGamer
