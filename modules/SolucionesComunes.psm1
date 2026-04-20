# ============================================================================
#  modules/SolucionesComunes.psm1
#  Soluciones comunes para problemas tipicos de gaming
# ============================================================================

function Invoke-SolucionesComunes {
    Show-Section "SOLUCIONES COMUNES DE GAMING"

    Write-UI "  [1] Stuttering / FPS drops (limpiar DirectX cache + shader)" -Color Yellow
    Write-UI "  [2] Desync de audio (reiniciar servicios de audio)" -Color Yellow
    Write-UI "  [3] Juego no abre / crash al iniciar (reparar VC++ runtimes)" -Color Yellow
    Write-UI "  [4] Input lag (reconfigurar HID + USB selective suspend)" -Color Yellow
    Write-UI "  [5] Xbox Game Bar no funciona" -Color Yellow
    Write-UI "  [6] Problemas con anti-cheat (EAC/BattlEye check)" -Color Yellow
    Write-UI "  [7] Mouse acceleration OFF (precision del raton)" -Color Yellow
    Write-UI "  [8] Hardware Accelerated GPU Scheduling (HAGS) ON" -Color Yellow
    Write-UI "  [B] Volver" -Color Yellow
    Write-Host ""
    Write-UI "  > " -Color Cyan -NoNewline
    $sub = (Read-Host).Trim().ToUpper()

    switch ($sub) {
        '1' { Fix-Stuttering }
        '2' { Fix-Audio }
        '3' { Fix-VCRuntimes }
        '4' { Fix-InputLag }
        '5' { Fix-XboxGameBar }
        '6' { Test-AntiCheat }
        '7' { Disable-MouseAccel }
        '8' { Enable-HAGS }
        default { return }
    }
}

function Fix-Stuttering {
    Write-Host ""
    Write-UI "Fix de stuttering / FPS drops:" -Color Cyan
    Clear-ShaderCache
    Invoke-LoggedAction -Description "Desactivar Fullscreen Optimizations globalmente" -Action {
        $key = 'HKCU:\System\GameConfigStore'
        if (Test-Path $key) {
            Set-ItemProperty -Path $key -Name 'GameDVR_FSEBehaviorMode'         -Value 2 -Type DWord -Force
            Set-ItemProperty -Path $key -Name 'GameDVR_HonorUserFSEBehaviorMode' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $key -Name 'GameDVR_DXGIHonorFSEWindowsCompatible' -Value 1 -Type DWord -Force
        }
    }
}

function Fix-Audio {
    Write-Host ""
    Write-UI "Reiniciando servicios de audio:" -Color Cyan
    $services = @('Audiosrv','AudioEndpointBuilder')
    foreach ($s in $services) {
        Invoke-LoggedAction -Description "Reiniciar servicio $s" -Action {
            Restart-Service -Name $s -Force -ErrorAction SilentlyContinue
        }
    }
    Write-UI "  Audio reiniciado. Si persiste, reinstala driver de audio." -Color Green
}

function Fix-VCRuntimes {
    Write-Host ""
    Write-UI "Runtimes Visual C++ instalados:" -Color Cyan
    Invoke-LoggedAction -Description "Listar Visual C++ Redistributables" -AlwaysRun -Action {
        $installed = Get-CimInstance Win32_Product -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like '*Visual C++*' -or $_.Name -like '*Microsoft Visual*' } |
            Select-Object Name, Version
        if (-not $installed) {
            Write-UI "       No se encontraron runtimes. Descarga el Microsoft Visual C++ Redistributable." -Color Yellow
        } else {
            foreach ($p in $installed) {
                Write-UI ("       " + $p.Name + " [$($p.Version)]") -Color Green
            }
        }
    }
    Write-UI "  Descarga lo mas reciente aqui:" -Color DarkYellow
    Write-UI "    https://aka.ms/vs/17/release/vc_redist.x64.exe" -Color DarkYellow
}

function Fix-InputLag {
    Write-Host ""
    Write-UI "Ajustando configuracion de dispositivos USB:" -Color Cyan
    Invoke-LoggedAction -Description "Desactivar USB Selective Suspend (plan actual)" -Action {
        powercfg /setacvalueindex SCHEME_CURRENT SUB_USB USBSELECTIVESUSPEND 0
        powercfg /setdcvalueindex SCHEME_CURRENT SUB_USB USBSELECTIVESUSPEND 0
        powercfg /setactive SCHEME_CURRENT
    }
}

function Fix-XboxGameBar {
    Write-Host ""
    Write-UI "Reparando Xbox Game Bar:" -Color Cyan
    Invoke-LoggedAction -Description "Re-registrar Xbox Game Bar" -Action {
        Get-AppxPackage Microsoft.XboxGamingOverlay -AllUsers |
            ForEach-Object { Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue }
    }
}

function Test-AntiCheat {
    Write-Host ""
    Write-UI "Verificando anti-cheat:" -Color Cyan
    Invoke-LoggedAction -Description "Estado de servicios anti-cheat" -AlwaysRun -Action {
        $ac = @('EasyAntiCheat','BEService','FACEIT','vgc','vgk')
        foreach ($s in $ac) {
            $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
            if ($svc) {
                Write-UI ("       $s : $($svc.Status) ($($svc.StartType))") -Color Green
            }
        }
    }
    Invoke-LoggedAction -Description "Secure Boot status" -AlwaysRun -Action {
        try {
            $sb = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
            Write-UI ("       Secure Boot: $sb") -Color Green
        } catch {
            Write-UI "       Secure Boot: no se pudo verificar" -Color DarkGray
        }
    }
}

function Disable-MouseAccel {
    Write-Host ""
    Write-UI "Desactivando aceleracion del raton:" -Color Cyan
    Invoke-LoggedAction -Description "MouseSpeed=0, MouseThreshold1=0, MouseThreshold2=0" -Action {
        $key = 'HKCU:\Control Panel\Mouse'
        Set-ItemProperty -Path $key -Name 'MouseSpeed'      -Value '0' -Type String -Force
        Set-ItemProperty -Path $key -Name 'MouseThreshold1' -Value '0' -Type String -Force
        Set-ItemProperty -Path $key -Name 'MouseThreshold2' -Value '0' -Type String -Force
    }
    Write-UI "  Nota: los cambios aplican al re-iniciar sesion." -Color DarkYellow
}

function Enable-HAGS {
    Write-Host ""
    Write-UI "Activando Hardware Accelerated GPU Scheduling (requiere reinicio):" -Color Cyan
    Invoke-LoggedAction -Description "HwSchMode=2 (HAGS on)" -Action {
        $key = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
        Set-ItemProperty -Path $key -Name 'HwSchMode' -Value 2 -Type DWord -Force
    }
    Write-UI "  Reinicia para aplicar. Desactiva con HwSchMode=1 si causa problemas." -Color DarkYellow
}

Export-ModuleMember -Function Invoke-SolucionesComunes
