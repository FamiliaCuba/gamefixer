# ============================================================================
#  modules/GPU.psm1
#  Gestion de GPU: driver NVIDIA, shader cache, monitoreo
# ============================================================================

function Invoke-GPUMenu {
    Show-Section "MODULO GPU (NVIDIA)"

    $g = Get-NvidiaGPUStats
    if ($g.Available) {
        Write-UI ("  Estado actual: uso {0}% @ {1}°C" -f $g.Usage, $g.Temp) -Color Green
    } else {
        Write-UI "  nvidia-smi no disponible. Driver NVIDIA no detectado." -Color Yellow
    }

    Write-Host ""
    Write-UI "  [1] Mostrar info detallada del driver" -Color Yellow
    Write-UI "  [2] Limpiar shader cache (DirectX + NVIDIA)" -Color Yellow
    Write-UI "  [3] Monitoreo en vivo (10 segundos)" -Color Yellow
    Write-UI "  [4] Forzar modo maximo rendimiento" -Color Yellow
    Write-UI "  [5] Verificar version driver vs ultima disponible (info)" -Color Yellow
    Write-UI "  [B] Volver" -Color Yellow
    Write-Host ""
    Write-UI "  > " -Color Cyan -NoNewline
    $sub = (Read-Host).Trim().ToUpper()

    switch ($sub) {
        '1' { Show-GPUInfo }
        '2' { Clear-ShaderCache }
        '3' { Watch-GPU }
        '4' { Set-GPUMaxPerformance }
        '5' { Test-GPUDriverVersion }
        default { return }
    }
}

function Show-GPUInfo {
    Write-Host ""
    Write-UI "Informacion detallada:" -Color Cyan
    try {
        $out = & nvidia-smi --query-gpu=name,driver_version,memory.total,memory.free,memory.used,power.draw,power.limit,fan.speed --format=csv 2>$null
        $out -split "`n" | ForEach-Object { Write-UI ("  " + $_) -Color Green }
    } catch {
        Write-UI "  [!] nvidia-smi no disponible" -Color Red
    }

    Write-Host ""
    Write-UI "Procesos usando GPU:" -Color Cyan
    try {
        $procs = & nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv 2>$null
        $procs -split "`n" | ForEach-Object { Write-UI ("  " + $_) -Color Green }
    } catch {}
}

function Clear-ShaderCache {
    Write-Host ""
    Write-UI "Limpiando shader caches..." -Color Cyan

    $caches = @(
        "$env:LOCALAPPDATA\NVIDIA\DXCache",
        "$env:LOCALAPPDATA\NVIDIA\GLCache",
        "$env:LOCALAPPDATA\AMD\DxCache",
        "$env:LOCALAPPDATA\D3DSCache",
        "$env:LOCALAPPDATA\NVIDIA Corporation\NV_Cache"
    )

    $totalFreed = 0
    foreach ($c in $caches) {
        if (Test-Path $c) {
            Invoke-LoggedAction -Description "Limpiar $c" -Action {
                $size = (Get-ChildItem $c -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
                Get-ChildItem $c -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                $script:totalFreed += $size
                $mb = [math]::Round($size / 1MB, 1)
                Write-UI ("       Liberado: $mb MB") -Color Green
            }
        } else {
            Write-UI ("    -> (no existe) $c") -Color DarkGray
        }
    }
}

function Watch-GPU {
    Write-Host ""
    Write-UI "Monitoreando GPU 10 segundos (Ctrl+C para abortar)..." -Color Cyan
    Write-Host ""
    for ($i = 1; $i -le 10; $i++) {
        $g = Get-NvidiaGPUStats
        if ($g.Available) {
            $bar = '#' * [int]($g.Usage / 5)
            Write-UI ("  [{0:D2}] GPU {1,3}% [{2,-20}] {3}°C" -f $i, $g.Usage, $bar, $g.Temp) -Color Green
        } else {
            Write-UI ("  [$i] nvidia-smi no disponible") -Color Yellow
            break
        }
        Start-Sleep -Seconds 1
    }
}

function Set-GPUMaxPerformance {
    Write-Host ""
    Write-UI "Configurando NVIDIA en modo maximo rendimiento..." -Color Cyan
    Invoke-LoggedAction -Description "nvidia-smi -pm 1 (persistence mode)" -Action {
        & nvidia-smi -pm 1 2>$null | Out-Null
    }
    Invoke-LoggedAction -Description "Set power limit al maximo soportado" -Action {
        $info = & nvidia-smi --query-gpu=power.max_limit --format=csv,noheader,nounits 2>$null
        if ($info) {
            $max = [int]($info -replace '[^\d]', '')
            & nvidia-smi -pl $max 2>$null | Out-Null
            Write-UI ("       Power limit: $max W") -Color Green
        }
    }
    Write-UI "  Nota: algunos ajustes requieren NVIDIA Control Panel." -Color DarkYellow
}

function Test-GPUDriverVersion {
    Write-Host ""
    Write-UI "Version de driver instalado:" -Color Cyan
    try {
        $v = & nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>$null
        Write-UI ("  $v") -Color Green
        Write-UI "  Visita https://www.nvidia.com/Download/index.aspx para comparar." -Color DarkGray
    } catch {
        Write-UI "  [!] nvidia-smi no disponible" -Color Red
    }
}

Export-ModuleMember -Function Invoke-GPUMenu, Show-GPUInfo, Clear-ShaderCache, Watch-GPU, Set-GPUMaxPerformance, Test-GPUDriverVersion
