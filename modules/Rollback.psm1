# ============================================================================
#  modules/Rollback.psm1
#  Restauracion de backups del registro y creacion de puntos de restauracion
# ============================================================================

function Invoke-Rollback {
    Show-Section "ROLLBACK / RESTAURACION"

    Write-UI "  [1] Listar backups disponibles" -Color Yellow
    Write-UI "  [2] Restaurar ultimo backup de registro" -Color Yellow
    Write-UI "  [3] Crear punto de restauracion del sistema" -Color Yellow
    Write-UI "  [4] Abrir System Restore (UI clasica)" -Color Yellow
    Write-UI "  [B] Volver" -Color Yellow
    Write-Host ""
    Write-UI "  > " -Color Cyan -NoNewline
    $sub = (Read-Host).Trim().ToUpper()

    switch ($sub) {
        '1' { Show-Backups }
        '2' { Restore-LastBackup }
        '3' { New-SystemRestorePoint }
        '4' { Start-Process 'rstrui.exe' }
        default { return }
    }
}

function Show-Backups {
    Write-Host ""
    Write-UI "Backups en: $($Global:GF.BackupsDir)" -Color Cyan
    $backups = Get-ChildItem $Global:GF.BackupsDir -Directory -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime -Descending
    if (-not $backups) {
        Write-UI "  (sin backups)" -Color DarkGray
        return
    }
    foreach ($b in $backups) {
        $files = Get-ChildItem $b.FullName -Filter '*.reg' -ErrorAction SilentlyContinue
        Write-UI ("  $($b.Name) [$($files.Count) archivos] - $($b.LastWriteTime)") -Color Green
    }
}

function Restore-LastBackup {
    Write-Host ""
    $latest = Get-ChildItem $Global:GF.BackupsDir -Directory -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) {
        Write-UI "  No hay backups para restaurar." -Color Yellow
        return
    }
    Write-UI ("Ultimo backup: $($latest.Name)") -Color Cyan
    $regs = Get-ChildItem $latest.FullName -Filter '*.reg'
    foreach ($r in $regs) {
        Invoke-LoggedAction -Description "Restaurar $($r.Name)" -Action {
            & reg import $r.FullName 2>&1 | Out-Null
        }
    }
    Write-UI "  Restauracion aplicada." -Color Green
}

function New-SystemRestorePoint {
    Write-Host ""
    Write-UI "Creando punto de restauracion del sistema..." -Color Cyan
    Invoke-LoggedAction -Description "Checkpoint-Computer GAMEFIXER" -Action {
        # System Restore requiere estar activo en C:
        Enable-ComputerRestore -Drive 'C:\' -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "GameFixer $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -RestorePointType 'MODIFY_SETTINGS'
    }
}

Export-ModuleMember -Function Invoke-Rollback
