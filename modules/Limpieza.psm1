# ============================================================================
#  modules/Limpieza.psm1
#  Limpieza interactiva: elegir qué limpiar en lugar de todo de golpe
# ============================================================================

function Invoke-Limpieza {
    do {
        Show-Section "LIMPIEZA DEL SISTEMA"

        # Calcular tamaños actuales
        $targets = Get-CleanupTargets
        $totalMB = 0

        Write-UI "  Espacio recuperable por categoria:" -Color Cyan
        Write-Host ""
        for ($i = 0; $i -lt $targets.Count; $i++) {
            $t = $targets[$i]
            $sizeMB = $t.SizeMB
            $totalMB += $sizeMB
            $sizeStr = if ($sizeMB -gt 0) { "{0,8:N1} MB" -f $sizeMB } else { "  (vacio)" }
            $color = if ($sizeMB -gt 100) { 'Yellow' } elseif ($sizeMB -gt 0) { 'Green' } else { 'DarkGray' }
            Write-UI ("    [{0}] {1,-26} {2}" -f ($i + 1), $t.Name, $sizeStr) -Color $color
        }
        Write-Host ""
        Write-UI ("  Total recuperable: {0:N1} MB" -f $totalMB) -Color Yellow
        Write-Host ""
        Write-UI "    [A] Limpiar TODO                    [R] Vaciar papelera reciclaje" -Color Yellow
        Write-UI "    [W] WinSxS cleanup (componentes antiguos de Windows)" -Color Yellow
        Write-UI "    [D] Limpieza de disco (cleanmgr.exe integrado)" -Color Yellow
        Write-UI "    [B] Volver" -Color Yellow
        Write-Host ""
        Write-UI "  > " -Color Cyan -NoNewline
        $sub = (Read-Host).Trim().ToUpper()

        if ($sub -eq 'B') { return }

        switch ($sub) {
            'A' { Invoke-CleanAll -Targets $targets }
            'R' { Invoke-EmptyRecycleBin }
            'W' { Invoke-WinSxSCleanup }
            'D' { Start-Process -FilePath 'cleanmgr.exe' -ArgumentList '/sagerun:1' -Verb RunAs -ErrorAction SilentlyContinue }
            default {
                $idx = 0
                if ([int]::TryParse($sub, [ref]$idx) -and $idx -ge 1 -and $idx -le $targets.Count) {
                    $t = $targets[$idx - 1]
                    Invoke-CleanTarget -Target $t
                }
            }
        }

        Pause-Submenu
    } while ($true)
}

function Get-CleanupTargets {
    $list = @(
        @{ Name='Temp de usuario';     Path="$env:TEMP" },
        @{ Name='Temp de Windows';     Path="$env:SystemRoot\Temp" },
        @{ Name='Prefetch';            Path="$env:SystemRoot\Prefetch" },
        @{ Name='SoftwareDist Downl.'; Path="$env:SystemRoot\SoftwareDistribution\Download" },
        @{ Name='Crash dumps';         Path="$env:LOCALAPPDATA\CrashDumps" },
        @{ Name='Thumbnail cache';     Path="$env:LOCALAPPDATA\Microsoft\Windows\Explorer"; Filter='thumbcache_*.db' },
        @{ Name='Recent files';        Path="$env:APPDATA\Microsoft\Windows\Recent" },
        @{ Name='Cache Chrome';        Path="$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache" },
        @{ Name='Cache Edge';          Path="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache" },
        @{ Name='DirectX Shader Cache';Path="$env:LOCALAPPDATA\D3DSCache" },
        @{ Name='NVIDIA DX Cache';     Path="$env:LOCALAPPDATA\NVIDIA\DXCache" },
        @{ Name='Delivery Optimization';Path="$env:SystemRoot\SoftwareDistribution\DeliveryOptimization\Cache" },
        @{ Name='Error Reporting';     Path="$env:ProgramData\Microsoft\Windows\WER" }
    )

    foreach ($t in $list) {
        $t.SizeMB = Get-FolderSizeMB -Path $t.Path -Filter $t.Filter
    }
    return $list
}

function Get-FolderSizeMB {
    param([string]$Path, [string]$Filter)
    if (-not (Test-Path $Path)) { return 0 }
    try {
        $size = if ($Filter) {
            (Get-ChildItem $Path -Filter $Filter -Recurse -Force -ErrorAction SilentlyContinue |
             Measure-Object Length -Sum).Sum
        } else {
            (Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue |
             Measure-Object Length -Sum).Sum
        }
        if (-not $size) { return 0 }
        return [math]::Round($size / 1MB, 1)
    } catch { return 0 }
}

function Invoke-CleanTarget {
    param($Target)

    Write-Host ""
    Write-UI ("  Limpiando: " + $Target.Name) -Color Cyan
    Write-UI ("  Ruta: " + $Target.Path) -Color DarkGray

    if (-not (Test-Path $Target.Path)) {
        Write-UI "  [!] La ruta no existe" -Color Yellow
        return
    }

    $before = Get-FolderSizeMB -Path $Target.Path -Filter $Target.Filter
    Write-UI ("  Antes: {0} MB" -f $before) -Color Green

    if ($Global:GF.DryRun) {
        Write-UI "  [PRUEBA] No se borraron archivos. Activa modo LIVE (tecla D) para limpieza real." -Color DarkYellow
        return
    }

    Invoke-LoggedAction -Description "Limpiar $($Target.Name)" -Action {
        if ($Target.Filter) {
            Get-ChildItem $Target.Path -Filter $Target.Filter -Force -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
        } else {
            Get-ChildItem $Target.Path -Recurse -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $after = Get-FolderSizeMB -Path $Target.Path -Filter $Target.Filter
    $freed = $before - $after
    Write-UI ("  Despues: {0} MB (liberado: {1} MB)" -f $after, $freed) -Color Green

    if (Test-SoundEnabled) { Play-SuccessChime }
}

function Invoke-CleanAll {
    param($Targets)
    Write-Host ""
    Write-UI "Limpieza total..." -Color Cyan

    if ($Global:GF.DryRun) {
        Write-UI "  [PRUEBA] No se borrara nada. Activa modo LIVE (tecla D en menu principal)." -Color DarkYellow
        $total = ($Targets | Measure-Object SizeMB -Sum).Sum
        Write-UI ("  Se liberarian aproximadamente: {0:N1} MB" -f $total) -Color Yellow
        return
    }

    $totalFreed = 0
    foreach ($t in $Targets) {
        if (-not (Test-Path $t.Path)) { continue }
        $before = Get-FolderSizeMB -Path $t.Path -Filter $t.Filter
        try {
            if ($t.Filter) {
                Get-ChildItem $t.Path -Filter $t.Filter -Force -ErrorAction SilentlyContinue |
                    Remove-Item -Force -ErrorAction SilentlyContinue
            } else {
                Get-ChildItem $t.Path -Recurse -Force -ErrorAction SilentlyContinue |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
            $after = Get-FolderSizeMB -Path $t.Path -Filter $t.Filter
            $freed = $before - $after
            $totalFreed += $freed
            Write-UI ("    [OK] {0,-28} {1,8:N1} MB liberados" -f $t.Name, $freed) -Color Green
        } catch {
            Write-UI ("    [X] {0} fallo: {1}" -f $t.Name, $_.Exception.Message) -Color Red
        }
    }

    Write-Host ""
    Write-UI ("  TOTAL LIBERADO: {0:N1} MB" -f $totalFreed) -Color Yellow
    Write-Log -Level INFO -Message "Limpieza total: $totalFreed MB liberados"
    if (Test-SoundEnabled) { Play-SuccessChime }
}

function Invoke-EmptyRecycleBin {
    Write-Host ""
    Write-UI "Vaciando papelera de reciclaje..." -Color Cyan
    if ($Global:GF.DryRun) {
        Write-UI "  [PRUEBA] No se vaciara la papelera." -Color DarkYellow
        return
    }
    try {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        Write-UI "  Papelera vaciada" -Color Green
        if (Test-SoundEnabled) { Play-SuccessChime }
    } catch {
        Write-UI ("  [X] " + $_.Exception.Message) -Color Red
    }
}

function Invoke-WinSxSCleanup {
    Write-Host ""
    Write-UI "WinSxS cleanup (puede tardar 10-30 minutos)..." -Color Cyan
    Write-UI "  Esto elimina versiones antiguas de componentes de Windows." -Color DarkGray
    Write-UI "  No se puede deshacer." -Color Yellow
    Write-Host ""

    if ($Global:GF.DryRun) {
        Write-UI "  [PRUEBA] No se ejecutara. Comando que correria:" -Color DarkYellow
        Write-UI "      DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase" -Color DarkGray
        return
    }

    if (-not $Global:GF.GuiAction) {
        Write-UI "  [?] Confirmar ejecucion? (s/N): " -Color Yellow -NoNewline
        $r = Read-Host
        if ($r.Trim().ToLower() -ne 's') { return }
    }

    Write-UI "  Ejecutando (no cierres la ventana)..." -Color Cyan
    & DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase
}

Export-ModuleMember -Function Invoke-Limpieza
