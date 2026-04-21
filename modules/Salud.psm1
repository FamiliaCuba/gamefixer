# ============================================================================
#  modules/Salud.psm1
#  Chequeo de salud del hardware y sistema
# ============================================================================

function Invoke-Salud {
    Show-Section "SALUD DEL SISTEMA"

    # 1. SMART de discos
    Write-UI "[1/4] Estado SMART de discos fisicos" -Color Cyan
    Invoke-LoggedAction -Description "Get-PhysicalDisk HealthStatus" -AlwaysRun -Action {
        Get-PhysicalDisk -ErrorAction SilentlyContinue | ForEach-Object {
            $color = switch ($_.HealthStatus) {
                'Healthy' { 'Green' }
                'Warning' { 'Yellow' }
                default   { 'Red' }
            }
            $sizeGB = [math]::Round($_.Size / 1GB, 0)
            Write-UI ("       $($_.FriendlyName) [$sizeGB GB] - $($_.HealthStatus) - $($_.OperationalStatus)") -Color $color
        }
    }

    # 2. Memoria virtual/paginado
    Write-Host ""
    Write-UI "[2/4] Memoria virtual" -Color Cyan
    Invoke-LoggedAction -Description "Get-CimInstance Win32_PageFileUsage" -AlwaysRun -Action {
        Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue | ForEach-Object {
            Write-UI ("       Archivo: $($_.Name)") -Color Green
            Write-UI ("       Tamano actual: $($_.CurrentUsage) MB de $($_.AllocatedBaseSize) MB") -Color Green
        }
    }

    # 3. Eventos criticos ultima semana
    Write-Host ""
    Write-UI "[3/4] Errores criticos (ultimos 7 dias)" -Color Cyan
    Invoke-LoggedAction -Description "Get-WinEvent criticos" -AlwaysRun -Action {
        $events = Get-WinEvent -FilterHashtable @{
            LogName   = 'System'
            Level     = 1, 2
            StartTime = (Get-Date).AddDays(-7)
        } -MaxEvents 20 -ErrorAction SilentlyContinue

        if (-not $events) {
            Write-UI "       Sin errores criticos recientes." -Color Green
        } else {
            $grouped = $events | Group-Object ProviderName |
                       Sort-Object Count -Descending | Select-Object -First 10
            foreach ($g in $grouped) {
                Write-UI ("       [{0,3}] {1}" -f $g.Count, $g.Name) -Color Yellow
            }
        }
    }

    # 4. Actualizaciones pendientes
    Write-Host ""
    Write-UI "[4/4] Actualizaciones de Windows" -Color Cyan
    Invoke-LoggedAction -Description "Verificar ultimas actualizaciones" -AlwaysRun -Action {
        $updates = Get-HotFix -ErrorAction SilentlyContinue | Sort-Object InstalledOn -Descending | Select-Object -First 5
        foreach ($u in $updates) {
            Write-UI ("       $($u.HotFixID) - $($u.Description) - $($u.InstalledOn)") -Color Green
        }
    }

    Write-Host ""
    Write-UI "  Recomendacion: ejecuta 'mdsched.exe' para test de RAM si sospechas problemas." -Color DarkYellow
}

Export-ModuleMember -Function Invoke-Salud
