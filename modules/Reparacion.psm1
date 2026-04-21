# ============================================================================
#  modules/Reparacion.psm1
#  Reparacion de archivos del sistema (SFC, DISM, chkdsk)
# ============================================================================

function Invoke-Reparacion {
    do {
        Clear-Host
        Show-Section "REPARACION DEL SISTEMA"

        Write-UI "  [1] SFC /scannow (reparar archivos sistema)" -Color Yellow
        Write-UI "  [2] DISM /RestoreHealth (reparar imagen Windows)" -Color Yellow
        Write-UI "  [3] CHKDSK C: (disco - solo lectura)" -Color Yellow
        Write-UI "  [4] SFC + DISM combinado (recomendado)" -Color Yellow
        Write-UI "  [5] Reparar tienda de Windows" -Color Yellow
        Write-UI "  [6] Reparar componentes .NET" -Color Yellow
        Write-UI "  [B] Volver al menu principal" -Color Yellow
        Write-Host ""
        Write-UI "  > " -Color Cyan -NoNewline
        $sub = (Read-Host).Trim().ToUpper()

        switch ($sub) {
            '1' { Invoke-SFC;              Pause-Submenu }
            '2' { Invoke-DISM;             Pause-Submenu }
            '3' { Invoke-Chkdsk;           Pause-Submenu }
            '4' { Invoke-SFC; Invoke-DISM; Pause-Submenu }
            '5' { Repair-WindowsStore;     Pause-Submenu }
            '6' { Repair-DotNet;           Pause-Submenu }
            'B' { return }
            default { }
        }
    } while ($true)
}

function Invoke-SFC {
    Write-Host ""
    Write-UI "Ejecutando SFC /scannow (puede tardar varios minutos)..." -Color Cyan
    Invoke-LoggedAction -Description "SFC /scannow" -Action {
        & sfc /scannow
    }
}

function Invoke-DISM {
    Write-Host ""
    Write-UI "Ejecutando DISM /RestoreHealth..." -Color Cyan
    Invoke-LoggedAction -Description "DISM CheckHealth" -Action {
        & DISM /Online /Cleanup-Image /CheckHealth
    }
    Invoke-LoggedAction -Description "DISM ScanHealth" -Action {
        & DISM /Online /Cleanup-Image /ScanHealth
    }
    Invoke-LoggedAction -Description "DISM RestoreHealth" -Action {
        & DISM /Online /Cleanup-Image /RestoreHealth
    }
}

function Invoke-Chkdsk {
    Write-Host ""
    Write-UI "Ejecutando CHKDSK C: en modo lectura..." -Color Cyan
    Invoke-LoggedAction -Description "chkdsk C: (sin /f para no requerir reinicio)" -AlwaysRun -Action {
        & chkdsk C:
    }
    Write-UI "  Para reparar con /f, ejecuta manualmente: chkdsk C: /f (reinicia)" -Color DarkYellow
}

function Repair-WindowsStore {
    Write-Host ""
    Write-UI "Reparando Microsoft Store..." -Color Cyan
    Invoke-LoggedAction -Description "wsreset" -Action {
        & wsreset.exe
    }
    Invoke-LoggedAction -Description "Re-registrar apps de Store" -Action {
        Get-AppxPackage -AllUsers | ForEach-Object {
            Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue
        }
    }
}

function Repair-DotNet {
    Write-Host ""
    Write-UI "Verificando .NET Framework..." -Color Cyan
    Invoke-LoggedAction -Description "Listar versiones .NET instaladas" -AlwaysRun -Action {
        Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse -ErrorAction SilentlyContinue |
            Get-ItemProperty -Name Version, Release -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -match '^(?!S)\p{L}' } |
            Select-Object PSChildName, Version, Release |
            ForEach-Object { Write-UI ("       " + $_.PSChildName + " -> " + $_.Version) -Color Green }
    }
}

Export-ModuleMember -Function Invoke-Reparacion
