# ============================================================================
#  modules/Limpieza.psm1
#  Limpieza de archivos temporales, cache, logs
# ============================================================================

function Invoke-Limpieza {
    Show-Section "LIMPIEZA DEL SISTEMA"

    $targets = @(
        @{ Name='Temp de usuario';   Path="$env:TEMP" },
        @{ Name='Temp de Windows';   Path="$env:SystemRoot\Temp" },
        @{ Name='Prefetch';          Path="$env:SystemRoot\Prefetch" },
        @{ Name='SoftwareDist Down'; Path="$env:SystemRoot\SoftwareDistribution\Download" },
        @{ Name='Logs de Windows';   Path="$env:SystemRoot\Logs" },
        @{ Name='Crash dumps';       Path="$env:LOCALAPPDATA\CrashDumps" },
        @{ Name='Thumbnail cache';   Path="$env:LOCALAPPDATA\Microsoft\Windows\Explorer" ; Filter='thumbcache_*.db' },
        @{ Name='Recent files';      Path="$env:APPDATA\Microsoft\Windows\Recent" }
    )

    $totalBefore = 0
    Write-UI "Analizando espacio ocupado..." -Color Cyan
    foreach ($t in $targets) {
        if (Test-Path $t.Path) {
            $size = if ($t.Filter) {
                (Get-ChildItem $t.Path -Filter $t.Filter -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
            } else {
                (Get-ChildItem $t.Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
            }
            if (-not $size) { $size = 0 }
            $mb = [math]::Round($size / 1MB, 1)
            $totalBefore += $size
            Write-UI ("  {0,-22} : {1,8} MB" -f $t.Name, $mb) -Color Green
        } else {
            Write-UI ("  {0,-22} : (no existe)" -f $t.Name) -Color DarkGray
        }
    }
    $totalMB = [math]::Round($totalBefore / 1MB, 1)
    Write-Host ""
    Write-UI ("  TOTAL identificado: $totalMB MB") -Color Yellow
    Write-Host ""

    Write-UI "Ejecutando limpieza..." -Color Cyan
    $freed = 0
    foreach ($t in $targets) {
        if (Test-Path $t.Path) {
            Invoke-LoggedAction -Description "Limpiar $($t.Name)" -Action {
                $before = if ($t.Filter) {
                    (Get-ChildItem $t.Path -Filter $t.Filter -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
                } else {
                    (Get-ChildItem $t.Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
                }
                if ($t.Filter) {
                    Get-ChildItem $t.Path -Filter $t.Filter -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
                } else {
                    Get-ChildItem $t.Path -Recurse -Force -ErrorAction SilentlyContinue |
                        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                }
                $script:freed += $before
            }
        }
    }

    # Papelera
    Invoke-LoggedAction -Description "Vaciar Papelera de reciclaje" -Action {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    }

    # Browser caches
    Write-Host ""
    Write-UI "Limpiando cachés de navegadores..." -Color Cyan
    $browsers = @(
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
        "$env:APPDATA\Mozilla\Firefox\Profiles"
    )
    foreach ($b in $browsers) {
        if (Test-Path $b) {
            Invoke-LoggedAction -Description "Cache de $(Split-Path $b -Leaf)" -Action {
                Get-ChildItem $b -Recurse -Force -ErrorAction SilentlyContinue |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Write-Host ""
    Write-UI ("=" * 72) -Color DarkGreen
    Write-UI "  Limpieza completada." -Color Green
}

Export-ModuleMember -Function Invoke-Limpieza
