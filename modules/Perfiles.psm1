# ============================================================================
#  modules/Perfiles.psm1
#  Perfiles predefinidos: Gamer / Oficina / Ahorro
# ============================================================================

function Invoke-Perfiles {
    Show-Section "PERFILES DE SISTEMA"

    Write-UI "  Perfil actual: $($Global:GF.Profile)" -Color Cyan
    Write-Host ""
    Write-UI "  [1] GAMER      - maximo rendimiento, low latency" -Color Yellow
    Write-UI "  [2] OFICINA    - balanceado, notificaciones activas" -Color Yellow
    Write-UI "  [3] AHORRO     - minima energia, laptop lejos del enchufe" -Color Yellow
    Write-UI "  [4] STREAMING  - CPU/GPU balanceado para OBS + juego" -Color Yellow
    Write-UI "  [B] Volver" -Color Yellow
    Write-Host ""
    Write-UI "  > " -Color Cyan -NoNewline
    $sub = (Read-Host).Trim().ToUpper()

    switch ($sub) {
        '1' { Apply-ProfileGamer }
        '2' { Apply-ProfileOficina }
        '3' { Apply-ProfileAhorro }
        '4' { Apply-ProfileStreaming }
        default { return }
    }
}

function Apply-ProfileGamer {
    Write-Host ""
    Write-UI "Aplicando perfil GAMER..." -Color Cyan
    Invoke-LoggedAction -Description "Plan de energia: Ultimate Performance" -Action {
        $list = powercfg /list
        $guid = $null
        foreach ($l in $list) { if ($l -match 'Ultimate' -and $l -match '([a-f0-9\-]{36})') { $guid = $matches[1]; break } }
        if (-not $guid) {
            powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null
            $list = powercfg /list
            foreach ($l in $list) { if ($l -match 'Ultimate' -and $l -match '([a-f0-9\-]{36})') { $guid = $matches[1]; break } }
        }
        if ($guid) { powercfg /setactive $guid }
    }
    Invoke-LoggedAction -Description "Game Mode ON, GameDVR OFF" -Action {
        $k1 = 'HKCU:\Software\Microsoft\GameBar'
        if (-not (Test-Path $k1)) { New-Item -Path $k1 -Force | Out-Null }
        Set-ItemProperty -Path $k1 -Name 'AutoGameModeEnabled' -Value 1 -Type DWord -Force
        $k2 = 'HKCU:\System\GameConfigStore'
        if (Test-Path $k2) { Set-ItemProperty -Path $k2 -Name 'GameDVR_Enabled' -Value 0 -Type DWord -Force }
    }
    Invoke-LoggedAction -Description "Visual effects = mejor rendimiento" -Action {
        $k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
        if (-not (Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
        Set-ItemProperty -Path $k -Name 'VisualFXSetting' -Value 2 -Type DWord -Force
    }
    $Global:GF.Profile = 'GAMER'
    Write-UI "  Perfil GAMER aplicado." -Color Green
}

function Apply-ProfileOficina {
    Write-Host ""
    Write-UI "Aplicando perfil OFICINA..." -Color Cyan
    Invoke-LoggedAction -Description "Plan de energia: Balanceado" -Action {
        powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
    }
    Invoke-LoggedAction -Description "Visual effects = apariencia" -Action {
        $k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
        if (-not (Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
        Set-ItemProperty -Path $k -Name 'VisualFXSetting' -Value 1 -Type DWord -Force
    }
    $Global:GF.Profile = 'OFICINA'
    Write-UI "  Perfil OFICINA aplicado." -Color Green
}

function Apply-ProfileAhorro {
    Write-Host ""
    Write-UI "Aplicando perfil AHORRO..." -Color Cyan
    Invoke-LoggedAction -Description "Plan de energia: Economizador" -Action {
        powercfg /setactive a1841308-3541-4fab-bc81-f71556f20b4a
    }
    $Global:GF.Profile = 'AHORRO'
    Write-UI "  Perfil AHORRO aplicado." -Color Green
}

function Apply-ProfileStreaming {
    Write-Host ""
    Write-UI "Aplicando perfil STREAMING..." -Color Cyan
    Invoke-LoggedAction -Description "Plan de energia: Alto rendimiento" -Action {
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
    }
    Invoke-LoggedAction -Description "Reservar cores para encoder (afinidad)" -Action {
        Write-UI "       Recomendacion: en OBS, afinidad CPU 0-3, juego en 4+" -Color DarkYellow
    }
    $Global:GF.Profile = 'STREAMING'
    Write-UI "  Perfil STREAMING aplicado." -Color Green
}

Export-ModuleMember -Function Invoke-Perfiles
