# ============================================================================
#  modules/GPU.psm1
#  Gestion de GPU: driver NVIDIA, shader cache, monitoreo
# ============================================================================

function Invoke-GPUMenu {
    do {
        Clear-Host
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
        Write-UI "  [B] Volver al menu principal" -Color Yellow
        Write-Host ""
        Write-UI "  > " -Color Cyan -NoNewline
        $sub = (Read-Host).Trim().ToUpper()

        switch ($sub) {
            '1' { Show-GPUInfo;            Pause-Submenu }
            '2' { Clear-ShaderCache;       Pause-Submenu }
            '3' { Watch-GPU;               Pause-Submenu }
            '4' { Set-GPUMaxPerformance;   Pause-Submenu }
            '5' { Test-GPUDriverVersion;   Pause-Submenu }
            'B' { return }
            default { }
        }
    } while ($true)
}

function Show-GPUInfo {
    Write-Host ""
    $gpus = @()
    try {
        $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
    } catch {
        Write-UI ("No se pudo leer la GPU: " + $_.Exception.Message) -Color Red
        return
    }

    $real = @($gpus | Where-Object {
        $_.Name -and $_.Name -notmatch 'Basic|Remote|Virtual|IddCx|Indirect|Parsec|Oray'
    })
    if ($real.Count -eq 0) { $real = @($gpus | Where-Object { $_.Name }) }

    if ($real.Count -eq 0) {
        Write-UI "No se encontro ninguna tarjeta grafica." -Color Yellow
        return
    }

    foreach ($gpu in $real) {
        Write-UI ("GPU: " + $gpu.Name) -Color Green
        $vram = 0
        try { $vram = Get-GPUVRam -GpuName $gpu.Name -Fallback $gpu.AdapterRAM } catch { $vram = 0 }
        if ($vram -gt 0) {
            Write-UI ("Memoria: " + $vram + " GB") -Color Green
        }
        if ($gpu.DriverVersion) {
            Write-UI ("Driver: " + $gpu.DriverVersion) -Color Green
        }
        if ($gpu.CurrentHorizontalResolution -and $gpu.CurrentVerticalResolution) {
            Write-UI ("Pantalla: " + $gpu.CurrentHorizontalResolution + "x" + $gpu.CurrentVerticalResolution) -Color Green
        }
    }

    $live = $null
    try { $live = Get-NvidiaGPUStats } catch { $live = $null }
    if ($live -and $live.Available) {
        Write-UI ("Uso ahora: " + $live.Usage + "% a " + $live.Temp + " C") -Color Green
    }
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

function Get-DriverPage {
    $prefer = $null
    try {
        $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
    } catch { return $null }
    foreach ($g in $gpus) {
        if (-not $g.Name) { continue }
        if ($g.Name -match 'Basic|Remote|Virtual|IddCx|Indirect') { continue }
        if ($g.Name -match 'NVIDIA') { return 'https://www.nvidia.com/Download/index.aspx' }
        if ($g.Name -match 'AMD|Radeon') { $prefer = 'https://www.amd.com/en/support/download/drivers.html' }
        elseif (-not $prefer -and $g.Name -match 'Intel') { $prefer = 'https://www.intel.com/content/www/us/en/download-center/home.html' }
    }
    return $prefer
}

function Test-GPUDriverVersion {
    Write-Host ""
    Write-UI "Verificando driver NVIDIA..." -Color Cyan

    # Detectar driver instalado
    $installed = $null
    try {
        $installed = (& nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>$null | Select-Object -First 1).Trim()
    } catch {}

    if (-not $installed) {
        Write-UI "  nvidia-smi no disponible o no hay GPU NVIDIA." -Color Yellow
        $page = Get-DriverPage
        if ($page) { Write-UI ("DRIVERURL|" + $page) -Color Cyan }
        return
    }

    Write-UI ("  Driver instalado : $installed") -Color Green

    # Detectar modelo y generacion para consultar la API de NVIDIA correcta
    $gpuName = $null
    try {
        $gpuName = (& nvidia-smi --query-gpu=name --format=csv,noheader 2>$null | Select-Object -First 1).Trim()
        Write-UI ("  GPU detectada    : $gpuName") -Color Green
    } catch {}

    # Consultar ultima version disponible via NVIDIA API publica
    # La API real de NVIDIA requiere psid, pfid, osid complicados. Alternativa: scrape del
    # JSON que usa la pagina de drivers.
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $latestVersion = $null
    $checkUrl = $null

    # Intentar metodo 1: API gfeclientcontent (la que usa GeForce Experience)
    try {
        Write-UI "  Consultando NVIDIA..." -Color DarkGreen
        # Determinar si es Studio o Game Ready (asumimos Game Ready por defecto)
        # Para RTX serie 40/50: psid=127, Windows 11 x64: osid=135
        $apiUrl = 'https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php?func=DriverManualLookup&psid=127&pfid=930&osid=135&lid=1&whql=1&lang=en-us&ctk=0'
        $resp = Invoke-WebRequest -Uri $apiUrl -UseBasicParsing -TimeoutSec 15 `
            -UserAgent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' -ErrorAction Stop
        $json = $resp.Content | ConvertFrom-Json
        if ($json.IDS -and $json.IDS[0].downloadInfo) {
            $latestVersion = $json.IDS[0].downloadInfo.Version
            $checkUrl = $json.IDS[0].downloadInfo.DownloadURL
        }
    } catch {
        Write-UI "    [!] API NVIDIA no respondio, intentando fallback..." -Color DarkYellow
    }

    if (-not $latestVersion) {
        # Fallback: pagina publica de drivers
        try {
            $pageResp = Invoke-WebRequest -Uri 'https://www.nvidia.com/en-us/drivers/' -UseBasicParsing -TimeoutSec 15 `
                -UserAgent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' -ErrorAction Stop
            if ($pageResp.Content -match '(\d{3}\.\d{2})\s*<') {
                $latestVersion = $matches[1]
            }
        } catch {}
    }

    if ($latestVersion) {
        Write-UI ("  Ultimo oficial   : $latestVersion") -Color Green

        # Comparar
        try {
            $installedV = [version]$installed
            $latestV = [version]$latestVersion
            if ($installedV -ge $latestV) {
                Write-UI "  Estado           : ACTUALIZADO" -Color Green
            } else {
                Write-UI "  Estado           : HAY ACTUALIZACION DISPONIBLE" -Color Yellow
                if ($checkUrl) {
                    Write-UI ("  Descarga directa : https://www.nvidia.com$checkUrl") -Color Cyan
                }
                Write-UI "  Pagina drivers   : https://www.nvidia.com/Download/index.aspx" -Color Cyan
            }
        } catch {
            Write-UI "  [!] No se pudo comparar versiones" -Color Yellow
        }
    } else {
        Write-UI "  [!] No se pudo consultar ultima version. Verifica manualmente en:" -Color Yellow
        Write-UI "      https://www.nvidia.com/Download/index.aspx" -Color Cyan
    }
    $page = Get-DriverPage
    if (-not $page) { $page = 'https://www.nvidia.com/Download/index.aspx' }
    Write-UI ("DRIVERURL|" + $page) -Color Cyan
}

Export-ModuleMember -Function Invoke-GPUMenu, Show-GPUInfo, Clear-ShaderCache, Watch-GPU, Set-GPUMaxPerformance, Test-GPUDriverVersion
