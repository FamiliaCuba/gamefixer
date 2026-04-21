# ============================================================================
#  modules/GameTweaks.psm1
#  Tweaks especificos por juego detectado
# ============================================================================

function Invoke-GameTweaksMenu {
    if (-not $Global:GF.DetectedGames -or $Global:GF.DetectedGames.Count -eq 0) {
        Show-Section "TWEAKS POR JUEGO"
        Write-UI "  Ejecuta primero [G] Detector de juegos." -Color Yellow
        return
    }

    # Catalogo
    $catalog = @(
        @{ Match='counter-strike 2';       Name='CS2';         Func='Apply-CS2Tweaks' }
        @{ Match='counter-strike: global'; Name='CS:GO';       Func='Apply-CS2Tweaks' }
        @{ Match='valorant';               Name='VALORANT';    Func='Apply-ValorantTweaks' }
        @{ Match='league of legends';      Name='LoL';         Func='Apply-LolTweaks' }
        @{ Match='fortnite';               Name='Fortnite';    Func='Apply-FortniteTweaks' }
        @{ Match='grand theft auto v';     Name='GTA V';       Func='Apply-GTAVTweaks' }
        @{ Match='red dead redemption';    Name='RDR2';        Func='Apply-RDR2Tweaks' }
        @{ Match='minecraft';              Name='Minecraft';   Func='Apply-MinecraftTweaks' }
        @{ Match='apex legends';           Name='Apex';        Func='Apply-ApexTweaks' }
        @{ Match='rainbow six siege';      Name='R6 Siege';    Func='Apply-R6Tweaks' }
    )

    $available = @()
    foreach ($g in $Global:GF.DetectedGames) {
        foreach ($c in $catalog) {
            if ($g.Name.ToLower().Contains($c.Match)) {
                $available += [pscustomobject]@{ Game=$g; Catalog=$c }
            }
        }
    }

    if ($available.Count -eq 0) {
        Show-Section "TWEAKS POR JUEGO"
        Write-UI "  No se encontraron juegos con tweaks disponibles." -Color Yellow
        Write-UI "  Soportados: CS2, Valorant, LoL, Fortnite, GTA V, RDR2, Minecraft, Apex, R6." -Color DarkGray
        return
    }

    do {
        Clear-Host
        Show-Section "TWEAKS POR JUEGO"

        Write-UI "Juegos detectados con tweaks disponibles:" -Color Cyan
        for ($i = 0; $i -lt $available.Count; $i++) {
            $item = $available[$i]
            Write-UI ("  [{0}] {1,-18} ({2})" -f ($i + 1), $item.Catalog.Name, $item.Game.Launcher) -Color Yellow
        }
        Write-UI ("  [A] Aplicar TODOS los tweaks disponibles") -Color Yellow
        Write-UI ("  [B] Volver al menu principal") -Color Yellow
        Write-Host ""
        Write-UI "  > " -Color Cyan -NoNewline
        $sub = (Read-Host).Trim().ToUpper()

        if ($sub -eq 'A') {
            foreach ($item in $available) { & $item.Catalog.Func -Game $item.Game }
            Pause-Submenu
        } elseif ($sub -eq 'B') {
            return
        } else {
            $idx = 0
            if ([int]::TryParse($sub, [ref]$idx) -and $idx -ge 1 -and $idx -le $available.Count) {
                $item = $available[$idx - 1]
                & $item.Catalog.Func -Game $item.Game
                Pause-Submenu
            }
        }
    } while ($true)
}

function Apply-CS2Tweaks {
    param($Game)
    Write-Host ""
    Write-UI "Aplicando tweaks de CS2..." -Color Cyan
    Invoke-LoggedAction -Description "CS2: fps_max 0 via launch options (manual)" -AlwaysRun -Action {
        Write-UI "       Recomendacion: en Steam, CS2 > Propiedades > Opciones de lanzamiento agrega:" -Color Green
        Write-UI "         -high -threads 8 -novid -nojoy +fps_max 0" -Color Yellow
    }
    Invoke-LoggedAction -Description "CS2: prioridad alta en exe si esta abierto" -Action {
        $p = Get-Process -Name 'cs2' -ErrorAction SilentlyContinue
        if ($p) { $p.PriorityClass = 'High' }
    }
}

function Apply-ValorantTweaks {
    param($Game)
    Write-Host ""
    Write-UI "Aplicando tweaks de VALORANT..." -Color Cyan
    Invoke-LoggedAction -Description "Valorant: desactivar fullscreen optimization en exe" -Action {
        $exe = Get-ChildItem -Path $Game.InstallDir -Filter 'VALORANT-Win64-Shipping.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($exe) {
            $key = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
            if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
            Set-ItemProperty -Path $key -Name $exe.FullName -Value '~ DISABLEDXMAXIMIZEDWINDOWEDMODE HIGHDPIAWARE' -Force
            Write-UI "       FSO desactivado en: $($exe.FullName)" -Color Green
        } else {
            Write-UI "       Exe no encontrado; se omite" -Color Yellow
        }
    }
    Invoke-LoggedAction -Description "Valorant: cerrar Vanguard no elimina problema - tip informativo" -AlwaysRun -Action {
        Write-UI "       Tip: si tienes stuttering, verifica vgc y vgk en [7] Soluciones Comunes." -Color Green
    }
}

function Apply-LolTweaks {
    param($Game)
    Write-Host ""
    Write-UI "Aplicando tweaks de League of Legends..." -Color Cyan
    Invoke-LoggedAction -Description "LoL: limpieza de logs antiguos" -Action {
        $logsDir = Join-Path $Game.InstallDir 'Logs'
        if (Test-Path $logsDir) {
            Get-ChildItem $logsDir -Recurse -Include '*.log','*.txt' -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
}

function Apply-FortniteTweaks {
    param($Game)
    Write-Host ""
    Write-UI "Aplicando tweaks de Fortnite..." -Color Cyan
    Invoke-LoggedAction -Description "Fortnite: limpiar shader cache (DX11/DX12)" -Action {
        $caches = @(
            "$env:LOCALAPPDATA\FortniteGame\Saved\Logs",
            "$env:LOCALAPPDATA\FortniteGame\Saved\Config\WindowsClient",
            "$env:LOCALAPPDATA\FortniteGame\Saved\webcache"
        )
        foreach ($c in $caches) {
            if (Test-Path $c) {
                Get-ChildItem $c -Recurse -Force -ErrorAction SilentlyContinue |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Apply-GTAVTweaks {
    param($Game)
    Write-Host ""
    Write-UI "Aplicando tweaks de GTA V..." -Color Cyan
    Invoke-LoggedAction -Description "GTA V: crear/editar commandline.txt con flags de rendimiento" -Action {
        $cmdFile = Join-Path $Game.InstallDir 'commandline.txt'
        $content = "-noSocialClub -borderless -availablevidmem 4096"
        if (-not $Global:GF.DryRun) {
            Set-Content -Path $cmdFile -Value $content -Encoding ASCII -Force
            Write-UI "       commandline.txt escrito en $cmdFile" -Color Green
        }
    }
}

function Apply-RDR2Tweaks {
    param($Game)
    Write-Host ""
    Write-UI "Aplicando tweaks de Red Dead Redemption 2..." -Color Cyan
    Invoke-LoggedAction -Description "RDR2: limpiar cache de shaders" -Action {
        $cache = "$env:USERPROFILE\Documents\Rockstar Games\Red Dead Redemption 2\Settings\shader_cache"
        if (Test-Path $cache) {
            Get-ChildItem $cache -Recurse -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Apply-MinecraftTweaks {
    param($Game)
    Write-Host ""
    Write-UI "Aplicando tweaks de Minecraft..." -Color Cyan
    Invoke-LoggedAction -Description "Minecraft: recomendar args JVM optimizados" -AlwaysRun -Action {
        Write-UI "       JVM args recomendados (pega en Launcher > Installations > Edit > JVM args):" -Color Green
        Write-UI "         -Xmx8G -Xms4G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200" -Color Yellow
        Write-UI "         -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch" -Color Yellow
    }
}

function Apply-ApexTweaks {
    param($Game)
    Write-Host ""
    Write-UI "Aplicando tweaks de Apex Legends..." -Color Cyan
    Invoke-LoggedAction -Description "Apex: launch options recomendadas" -AlwaysRun -Action {
        Write-UI "       En Origin/EA App, Apex > Propiedades > Advanced launch options:" -Color Green
        Write-UI "         +fps_max 0 -high -novid" -Color Yellow
    }
}

function Apply-R6Tweaks {
    param($Game)
    Write-Host ""
    Write-UI "Aplicando tweaks de Rainbow Six Siege..." -Color Cyan
    Invoke-LoggedAction -Description "R6: tip de configuracion de Vulkan vs DX11" -AlwaysRun -Action {
        Write-UI "       Tip: Vulkan suele dar mejor frametime que DX11 en R6." -Color Green
        Write-UI "       Cambia el API desde el launcher (Uplay > R6 > Propiedades)." -Color Yellow
    }
}

Export-ModuleMember -Function Invoke-GameTweaksMenu
