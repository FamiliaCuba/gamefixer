# ============================================================================
#  modules/GameDetector.psm1
#  Deteccion de launchers y juegos instalados en TODAS las unidades
#  Soporta: Steam, Epic, Riot, Battle.net, GOG, Ubisoft, EA App,
#           Xbox Game Pass, Microsoft Store
# ============================================================================

function Invoke-GameDetectorMenu {
    Show-Section "DETECTOR DE JUEGOS Y LAUNCHERS"

    Write-UI "Escaneando todos los discos del sistema..." -Color Cyan
    Write-Host ""

    $launchers = Get-InstalledLaunchers
    Write-UI ("Launchers detectados: " + $launchers.Count) -Color Cyan
    foreach ($l in $launchers) {
        Write-UI ("  [OK] " + $l.Name + " - " + $l.Path) -Color Green
    }
    Write-Host ""

    $games = Get-InstalledGames -Launchers $launchers

    # Agrupar por launcher
    $byLauncher = $games | Group-Object Launcher | Sort-Object Name

    Write-UI ("Juegos encontrados: " + $games.Count) -Color Cyan
    if ($games.Count -eq 0) {
        Write-UI "  No se detectaron juegos instalados." -Color DarkGray
    } else {
        foreach ($grp in $byLauncher) {
            Write-Host ""
            Write-UI ("  [" + $grp.Name + "] (" + $grp.Count + " juegos)") -Color Yellow
            $grp.Group | Sort-Object SizeGB -Descending | ForEach-Object {
                $sizeStr = if ($_.SizeGB -and $_.SizeGB -gt 0) { "{0,6:N1} GB" -f $_.SizeGB } else { "     ?" }
                $drive = if ($_.InstallDir -and $_.InstallDir -match '^([A-Z]):') { " [" + $matches[1] + ":]" } else { "" }
                Write-UI ("    " + $_.Name.PadRight(50) + $sizeStr + $drive) -Color Green
            }
        }
    }

    $totalSize = ($games | Where-Object SizeGB | Measure-Object SizeGB -Sum).Sum
    if ($totalSize) {
        Write-Host ""
        Write-UI ("  Espacio total usado por juegos: " + [int]$totalSize + " GB") -Color Yellow
    }

    # Resumen por disco
    $byDisk = $games | Where-Object InstallDir | Group-Object {
        if ($_.InstallDir -match '^([A-Z]):') { $matches[1] + ':' } else { '?' }
    }
    if ($byDisk) {
        Write-Host ""
        Write-UI "Distribucion por disco:" -Color Cyan
        foreach ($d in $byDisk | Sort-Object Name) {
            $sz = [int](($d.Group | Where-Object SizeGB | Measure-Object SizeGB -Sum).Sum)
            Write-UI ("  " + $d.Name + "  " + $d.Count + " juegos, " + $sz + " GB") -Color Green
        }
    }

    # Guardar en global para otros modulos
    $Global:GF.DetectedGames = $games
    $Global:GF.DetectedLaunchers = $launchers
}

function Get-AllDrives {
    # Devuelve todas las letras de unidades locales fijas
    try {
        return Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
               Select-Object -ExpandProperty DeviceID
    } catch {
        return @('C:')
    }
}

function Get-InstalledLaunchers {
    $found = @()

    # --- Steam ---
    $steam = Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -ErrorAction SilentlyContinue
    if (-not $steam) { $steam = Get-ItemProperty 'HKLM:\SOFTWARE\Valve\Steam' -ErrorAction SilentlyContinue }
    if ($steam -and $steam.InstallPath -and (Test-Path $steam.InstallPath)) {
        $found += [pscustomobject]@{ Name='Steam'; Path=$steam.InstallPath; Exe=(Join-Path $steam.InstallPath 'steam.exe') }
    }

    # --- Epic Games ---
    $epicPaths = @(
        "$env:ProgramFiles\Epic Games",
        "${env:ProgramFiles(x86)}\Epic Games"
    )
    foreach ($p in $epicPaths) {
        if (Test-Path "$p\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe") {
            $found += [pscustomobject]@{ Name='Epic Games'; Path=$p; Exe="$p\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe" }
            break
        }
    }

    # --- Riot Client ---
    $riotPaths = @("$env:ProgramFiles\Riot Games","${env:ProgramFiles(x86)}\Riot Games")
    foreach ($p in $riotPaths) {
        if (Test-Path "$p\Riot Client\RiotClientServices.exe") {
            $found += [pscustomobject]@{ Name='Riot Games'; Path=$p; Exe="$p\Riot Client\RiotClientServices.exe" }
            break
        }
    }

    # --- Battle.net ---
    $bnetPaths = @("$env:ProgramFiles\Battle.net","${env:ProgramFiles(x86)}\Battle.net")
    foreach ($p in $bnetPaths) {
        if (Test-Path "$p\Battle.net Launcher.exe") {
            $found += [pscustomobject]@{ Name='Battle.net'; Path=$p; Exe="$p\Battle.net Launcher.exe" }
            break
        }
    }

    # --- Ubisoft Connect ---
    $ubiPaths = @(
        "${env:ProgramFiles(x86)}\Ubisoft\Ubisoft Game Launcher",
        "$env:ProgramFiles\Ubisoft\Ubisoft Game Launcher"
    )
    foreach ($p in $ubiPaths) {
        if (Test-Path "$p\UbisoftConnect.exe") {
            $found += [pscustomobject]@{ Name='Ubisoft Connect'; Path=$p; Exe="$p\UbisoftConnect.exe" }
            break
        }
        if (Test-Path "$p\upc.exe") {
            $found += [pscustomobject]@{ Name='Ubisoft Connect'; Path=$p; Exe="$p\upc.exe" }
            break
        }
    }

    # --- EA App ---
    $eaPaths = @("$env:LOCALAPPDATA\Electronic Arts\EA Desktop","$env:ProgramFiles\Electronic Arts\EA Desktop")
    foreach ($p in $eaPaths) {
        if (Test-Path $p) {
            $found += [pscustomobject]@{ Name='EA App'; Path=$p; Exe=$null }
            break
        }
    }

    # --- GOG Galaxy ---
    $gogPaths = @("$env:ProgramFiles\GOG Galaxy","${env:ProgramFiles(x86)}\GOG Galaxy")
    foreach ($p in $gogPaths) {
        if (Test-Path "$p\GalaxyClient.exe") {
            $found += [pscustomobject]@{ Name='GOG Galaxy'; Path=$p; Exe="$p\GalaxyClient.exe" }
            break
        }
    }

    # --- Xbox App / Game Pass ---
    $xbox = Get-AppxPackage -Name 'Microsoft.GamingApp' -ErrorAction SilentlyContinue
    if ($xbox) {
        $found += [pscustomobject]@{ Name='Xbox App'; Path=$xbox.InstallLocation; Exe=$null }
    }

    return $found
}

function Get-SteamGames {
    param($SteamLauncher)
    $results = @()
    if (-not $SteamLauncher) { return $results }

    $libFile = Join-Path $SteamLauncher.Path 'steamapps\libraryfolders.vdf'
    if (-not (Test-Path $libFile)) { return $results }

    $content = Get-Content $libFile -Raw
    $libPaths = @()
    # Extraer paths de libreria (funciona incluso con librerias en otros discos)
    $regex = '"path"\s*"([^"]+)"'
    $ms = [regex]::Matches($content, $regex)
    foreach ($m in $ms) {
        $p = $m.Groups[1].Value -replace '\\\\', '\'
        if (Test-Path $p) { $libPaths += $p }
    }

    foreach ($lib in $libPaths) {
        $manifests = Get-ChildItem (Join-Path $lib 'steamapps') -Filter 'appmanifest_*.acf' -ErrorAction SilentlyContinue
        foreach ($mf in $manifests) {
            $mfContent = Get-Content $mf.FullName -Raw
            $name = if ($mfContent -match '"name"\s*"([^"]+)"') { $matches[1] } else { 'Unknown' }
            $size = if ($mfContent -match '"SizeOnDisk"\s*"(\d+)"') { [long]$matches[1] } else { 0 }
            $installDir = if ($mfContent -match '"installdir"\s*"([^"]+)"') { $matches[1] } else { '' }
            $fullPath = Join-Path $lib ('steamapps\common\' + $installDir)
            $results += [pscustomobject]@{
                Launcher   = 'Steam'
                Name       = $name
                InstallDir = $fullPath
                SizeGB     = [math]::Round($size / 1GB, 1)
            }
        }
    }
    return $results
}

function Get-EpicGames {
    $results = @()
    $manifestDir = "$env:ProgramData\Epic\EpicGamesLauncher\Data\Manifests"
    if (-not (Test-Path $manifestDir)) { return $results }

    $items = Get-ChildItem $manifestDir -Filter '*.item' -ErrorAction SilentlyContinue
    foreach ($item in $items) {
        try {
            $json = Get-Content $item.FullName -Raw | ConvertFrom-Json
            $results += [pscustomobject]@{
                Launcher   = 'Epic'
                Name       = $json.DisplayName
                InstallDir = $json.InstallLocation
                SizeGB     = if ($json.InstallSize) { [math]::Round($json.InstallSize / 1GB, 1) } else { 0 }
            }
        } catch {}
    }
    return $results
}

function Get-RiotGames {
    param($RiotLauncher)
    $results = @()

    # VALORANT: puede estar en cualquier disco (ej D:\Riot Games\VALORANT)
    $candidates = @()
    foreach ($drive in Get-AllDrives) {
        $candidates += "$drive\Riot Games\VALORANT"
        $candidates += "$drive\Games\Riot Games\VALORANT"
    }
    foreach ($p in $candidates) {
        if (Test-Path $p) {
            $sz = try {
                [math]::Round((Get-ChildItem $p -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1GB, 1)
            } catch { 0 }
            $results += [pscustomobject]@{ Launcher='Riot'; Name='VALORANT'; InstallDir=$p; SizeGB=$sz }
            break
        }
    }

    # League of Legends: scanner similar
    foreach ($drive in Get-AllDrives) {
        $candidates = @(
            "$drive\Riot Games\League of Legends",
            "$drive\Games\Riot Games\League of Legends",
            "${env:ProgramFiles}\Riot Games\League of Legends",
            "${env:ProgramFiles(x86)}\Riot Games\League of Legends"
        )
        foreach ($p in $candidates) {
            if (Test-Path $p) {
                $sz = try {
                    [math]::Round((Get-ChildItem $p -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1GB, 1)
                } catch { 0 }
                $results += [pscustomobject]@{ Launcher='Riot'; Name='League of Legends'; InstallDir=$p; SizeGB=$sz }
                return $results
            }
        }
    }

    return $results
}

function Get-XboxGamePassGames {
    <#
    .SYNOPSIS
    Detecta juegos de Xbox Game Pass / Microsoft Store.
    Usa Get-AppxPackage con filtros + escaneo de carpetas WindowsApps/ModifiableWindowsApps
    en TODOS los discos.
    #>
    $results = @()

    # Publishers de gaming (ayuda a filtrar solo juegos de la lista gigante de Appx)
    $gamingPublishers = @(
        'Microsoft.Xbox',
        'Microsoft.Gaming',
        'Microsoft.Minecraft',
        'Microsoft.HaloMCC',
        'Microsoft.MSFS',             # Flight Simulator
        'Microsoft.Forza',
        'Microsoft.SeaOfThieves',
        'Microsoft.Age',              # Age of Empires
        'Microsoft.State',             # State of Decay
        'Microsoft.Wolfenstein',
        'Microsoft.Fallout',
        'Microsoft.Skyrim',
        'Microsoft.TheElderScrolls',
        'Microsoft.Starfield',
        'BethesdaSoftworks',
        'ActivisionBlizzardEntertainmentSA',
        'Ubisoft',
        'ElectronicArts',
        '2KGamesInc',
        'BandaiNamcoEntertainmentInc',
        'SEGAEurope',
        'SquareEnix',
        'KojimaProductions',
        'ParadoxInteractive',
        'CapcomCo.Ltd'
    )

    # 1. Appx filtrado por publisher conocido de gaming
    try {
        $all = Get-AppxPackage -ErrorAction SilentlyContinue
        foreach ($pkg in $all) {
            $isGame = $false
            foreach ($pub in $gamingPublishers) {
                if ($pkg.Name -like "$pub*" -or $pkg.PublisherId -like "*$pub*") {
                    $isGame = $true
                    break
                }
            }
            # Excluir apps no-juego obvias (Xbox Console Companion, etc)
            $notGame = @('Microsoft.XboxApp','Microsoft.GamingApp','Microsoft.XboxGameOverlay',
                         'Microsoft.XboxGamingOverlay','Microsoft.XboxIdentityProvider',
                         'Microsoft.XboxSpeechToTextOverlay','Microsoft.Xbox.TCUI',
                         'Microsoft.GamingServices')
            if ($pkg.Name -in $notGame) { $isGame = $false }

            if ($isGame -and $pkg.InstallLocation -and (Test-Path $pkg.InstallLocation)) {
                $displayName = $pkg.Name -replace '^Microsoft\.', '' -replace '^\w+\.', ''
                # Intentar obtener el nombre bonito desde el manifiesto
                try {
                    $manifestPath = Join-Path $pkg.InstallLocation 'AppxManifest.xml'
                    if (Test-Path $manifestPath) {
                        [xml]$xml = Get-Content $manifestPath -Raw -ErrorAction SilentlyContinue
                        $prettyName = $xml.Package.Properties.DisplayName
                        if ($prettyName -and $prettyName -notmatch '^ms-resource') {
                            $displayName = $prettyName
                        }
                    }
                } catch {}

                $sz = 0
                try {
                    $sz = [math]::Round((Get-ChildItem $pkg.InstallLocation -Recurse -ErrorAction SilentlyContinue |
                                          Measure-Object Length -Sum).Sum / 1GB, 1)
                } catch {}

                $results += [pscustomobject]@{
                    Launcher   = 'Xbox/GP'
                    Name       = $displayName
                    InstallDir = $pkg.InstallLocation
                    SizeGB     = $sz
                }
            }
        }
    } catch {
        Write-Log -Level WARN -Message "Xbox GP scan via Appx fallo: $($_.Exception.Message)"
    }

    # 2. Escanear ModifiableWindowsApps en todos los discos (Xbox Game Pass los pone aca)
    foreach ($drive in Get-AllDrives) {
        $modPath = "$drive\XboxGames"
        if (Test-Path $modPath) {
            Get-ChildItem $modPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $dir = $_.FullName
                # Evitar duplicar juegos ya encontrados via Appx
                $alreadyFound = $results | Where-Object { $_.InstallDir -like "$dir*" }
                if (-not $alreadyFound) {
                    $sz = try {
                        [math]::Round((Get-ChildItem $dir -Recurse -ErrorAction SilentlyContinue |
                                        Measure-Object Length -Sum).Sum / 1GB, 1)
                    } catch { 0 }
                    $results += [pscustomobject]@{
                        Launcher   = 'Xbox/GP'
                        Name       = $_.Name
                        InstallDir = $dir
                        SizeGB     = $sz
                    }
                }
            }
        }

        # Carpeta Program Files\ModifiableWindowsApps (otra ubicacion tipica de GP)
        $modPath2 = "$drive\Program Files\ModifiableWindowsApps"
        if (Test-Path $modPath2) {
            Get-ChildItem $modPath2 -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $dir = $_.FullName
                $alreadyFound = $results | Where-Object { $_.InstallDir -like "$dir*" }
                if (-not $alreadyFound) {
                    $sz = try {
                        [math]::Round((Get-ChildItem $dir -Recurse -ErrorAction SilentlyContinue |
                                        Measure-Object Length -Sum).Sum / 1GB, 1)
                    } catch { 0 }
                    $results += [pscustomobject]@{
                        Launcher   = 'Xbox/GP'
                        Name       = $_.Name
                        InstallDir = $dir
                        SizeGB     = $sz
                    }
                }
            }
        }
    }

    return $results
}

function Get-EAGames {
    <#
    .SYNOPSIS
    Detecta juegos de EA App leyendo el archivo InstallLocations.
    #>
    $results = @()
    $eaInstallFile = "$env:ProgramData\EA Desktop\530c11479fe252fc5aabc24935b9776d4900eb3ba58fdc271e0d6229413ad40e\IS"
    # Hash variable. Buscar en ProgramData\EA Desktop
    $base = "$env:ProgramData\EA Desktop"
    if (Test-Path $base) {
        $isFile = Get-ChildItem $base -Recurse -Filter 'IS' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($isFile) {
            # El archivo IS tiene formato propietario, parse simple: buscar paths
            try {
                $content = Get-Content $isFile.FullName -Raw -ErrorAction SilentlyContinue
                $matches = [regex]::Matches($content, '([A-Z]:\\[^"\x00]+?EA Games\\[^"\x00]+?)(?="|\x00|$)')
                foreach ($m in $matches) {
                    $p = $m.Value
                    if (Test-Path $p) {
                        $name = Split-Path $p -Leaf
                        $sz = try {
                            [math]::Round((Get-ChildItem $p -Recurse -ErrorAction SilentlyContinue |
                                            Measure-Object Length -Sum).Sum / 1GB, 1)
                        } catch { 0 }
                        $results += [pscustomobject]@{
                            Launcher   = 'EA'
                            Name       = $name
                            InstallDir = $p
                            SizeGB     = $sz
                        }
                    }
                }
            } catch {}
        }
    }

    # Fallback: escanear EA Games en todos los discos
    foreach ($drive in Get-AllDrives) {
        $paths = @("$drive\Program Files\EA Games", "$drive\Program Files (x86)\EA Games", "$drive\EA Games")
        foreach ($p in $paths) {
            if (Test-Path $p) {
                Get-ChildItem $p -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                    $alreadyFound = $results | Where-Object { $_.InstallDir -eq $_.FullName }
                    if (-not $alreadyFound) {
                        $sz = try {
                            [math]::Round((Get-ChildItem $_.FullName -Recurse -ErrorAction SilentlyContinue |
                                            Measure-Object Length -Sum).Sum / 1GB, 1)
                        } catch { 0 }
                        $results += [pscustomobject]@{
                            Launcher   = 'EA'
                            Name       = $_.Name
                            InstallDir = $_.FullName
                            SizeGB     = $sz
                        }
                    }
                }
            }
        }
    }

    return $results
}

function Get-UbisoftGames {
    $results = @()
    # Ubisoft guarda instalaciones en el registro
    $keys = @(
        'HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs',
        'HKLM:\SOFTWARE\Ubisoft\Launcher\Installs'
    )
    foreach ($k in $keys) {
        if (Test-Path $k) {
            Get-ChildItem $k -ErrorAction SilentlyContinue | ForEach-Object {
                $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
                if ($props.InstallDir -and (Test-Path $props.InstallDir)) {
                    $name = Split-Path $props.InstallDir -Leaf
                    $sz = try {
                        [math]::Round((Get-ChildItem $props.InstallDir -Recurse -ErrorAction SilentlyContinue |
                                        Measure-Object Length -Sum).Sum / 1GB, 1)
                    } catch { 0 }
                    $results += [pscustomobject]@{
                        Launcher   = 'Ubisoft'
                        Name       = $name
                        InstallDir = $props.InstallDir
                        SizeGB     = $sz
                    }
                }
            }
        }
    }
    return $results
}

function Get-GOGGames {
    $results = @()
    $keys = @(
        'HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games',
        'HKLM:\SOFTWARE\GOG.com\Games'
    )
    foreach ($k in $keys) {
        if (Test-Path $k) {
            Get-ChildItem $k -ErrorAction SilentlyContinue | ForEach-Object {
                $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
                if ($props.PATH -and (Test-Path $props.PATH)) {
                    $name = if ($props.GAMENAME) { $props.GAMENAME } else { Split-Path $props.PATH -Leaf }
                    $sz = try {
                        [math]::Round((Get-ChildItem $props.PATH -Recurse -ErrorAction SilentlyContinue |
                                        Measure-Object Length -Sum).Sum / 1GB, 1)
                    } catch { 0 }
                    $results += [pscustomobject]@{
                        Launcher   = 'GOG'
                        Name       = $name
                        InstallDir = $props.PATH
                        SizeGB     = $sz
                    }
                }
            }
        }
    }
    return $results
}

function Get-InstalledGames {
    param($Launchers)

    $games = @()

    # Steam
    $steam = $Launchers | Where-Object Name -eq 'Steam'
    if ($steam) { $games += Get-SteamGames -SteamLauncher $steam }

    # Epic
    $epic = $Launchers | Where-Object Name -eq 'Epic Games'
    if ($epic) { $games += Get-EpicGames }

    # Riot
    $riot = $Launchers | Where-Object Name -eq 'Riot Games'
    if ($riot) { $games += Get-RiotGames -RiotLauncher $riot }

    # Xbox Game Pass / MS Store (siempre, aunque no haya 'launcher' formal)
    $games += Get-XboxGamePassGames

    # EA App
    $games += Get-EAGames

    # Ubisoft
    $games += Get-UbisoftGames

    # GOG
    $games += Get-GOGGames

    # Dedup por InstallDir
    $games = $games | Sort-Object InstallDir -Unique

    return $games
}

Export-ModuleMember -Function Invoke-GameDetectorMenu, Get-InstalledLaunchers, Get-InstalledGames, `
    Get-SteamGames, Get-EpicGames, Get-RiotGames, Get-XboxGamePassGames, Get-EAGames, `
    Get-UbisoftGames, Get-GOGGames, Get-AllDrives
