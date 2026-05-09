# ============================================================================
#  modules/Config.psm1
#  Configuracion persistente (config.json) y exportacion/importacion de perfiles
# ============================================================================

$Script:ConfigSchema = @{
    theme              = 'matrix'       # matrix | cyberpunk | fallout | dracula
    autoUpdate         = $true
    showBanner         = $true
    language           = 'es'
    dryRunDefault      = $true
    lastProfile        = 'FamiliaCuba'
    bootAnimation      = 'typewriter'   # typewriter | matrix | none
    soundEnabled       = $false
    preferredDNS       = 'auto'         # auto | cloudflare | google
    confirmDestructive = $true
    telemetryOptIn     = $false
    supportWebhook     = ''             # URL del Discord webhook (opcional)
}

function Get-ConfigPath {
    return (Join-Path $Global:GF.Root 'config.json')
}

function Initialize-Config {
    $path = Get-ConfigPath
    if (-not (Test-Path $path)) {
        # Crear config con defaults
        $Script:ConfigSchema | ConvertTo-Json | Set-Content -Path $path -Encoding UTF8
        Write-Log -Level INFO -Message "Config creada con defaults: $path"
    }

    # Cargar y mergear con schema (por si el usuario tiene una config vieja sin keys nuevas)
    $loaded = @{}
    try {
        $json = Get-Content $path -Raw | ConvertFrom-Json
        foreach ($prop in $json.PSObject.Properties) {
            $loaded[$prop.Name] = $prop.Value
        }
    } catch {
        Write-Log -Level WARN -Message "Config corrupta, usando defaults"
        $loaded = $Script:ConfigSchema
    }

    $merged = @{}
    foreach ($key in $Script:ConfigSchema.Keys) {
        if ($loaded.ContainsKey($key)) {
            $merged[$key] = $loaded[$key]
        } else {
            $merged[$key] = $Script:ConfigSchema[$key]
        }
    }

    $Global:GF.Config = [pscustomobject]$merged
    return $Global:GF.Config
}

function Save-Config {
    $path = Get-ConfigPath
    try {
        $Global:GF.Config | ConvertTo-Json -Depth 5 | Set-Content -Path $path -Encoding UTF8
        Write-Log -Level INFO -Message "Config guardada: $path"
        return $true
    } catch {
        Write-Log -Level ERROR -Message "No se pudo guardar config: $($_.Exception.Message)"
        return $false
    }
}

function Set-ConfigValue {
    param(
        [string]$Key,
        $Value
    )
    if ($null -eq $Global:GF.Config) { Initialize-Config | Out-Null }
    $Global:GF.Config.$Key = $Value
    Save-Config | Out-Null
}

function Invoke-ConfigMenu {
    do {
        Show-Section "CONFIGURACION"

        if ($null -eq $Global:GF.Config) { Initialize-Config | Out-Null }
        $cfg = $Global:GF.Config

        Write-UI "  Configuracion actual:" -Color Cyan
        Write-Host ""
        Write-UI ("    [1] Tema visual        : " + $cfg.theme)              -Color Green
        Write-UI ("    [2] Auto-update check  : " + $cfg.autoUpdate)         -Color Green
        Write-UI ("    [3] Mostrar banner     : " + $cfg.showBanner)         -Color Green
        Write-UI ("    [4] Idioma             : " + $cfg.language)           -Color Green
        Write-UI ("    [5] Modo prueba por defecto: " + $cfg.dryRunDefault)      -Color Green
        Write-UI ("    [6] Animacion de boot  : " + $cfg.bootAnimation)      -Color Green
        Write-UI ("    [7] Sonidos            : " + $cfg.soundEnabled)       -Color Green
        Write-UI ("    [8] DNS preferido      : " + $cfg.preferredDNS)       -Color Green
        Write-UI ("    [9] Confirmar acciones : " + $cfg.confirmDestructive) -Color Green
        Write-Host ""
        Write-UI "    [R] Reset a defaults" -Color Yellow
        Write-UI "    [V] Ver archivo config.json" -Color Yellow
        Write-UI "    [B] Volver" -Color Yellow
        Write-Host ""
        Write-UI "  > " -Color Cyan -NoNewline
        $sub = (Read-Host).Trim().ToUpper()

        switch ($sub) {
            '1' { Set-ConfigPrompt -Key 'theme' -Options @('matrix','cyberpunk','fallout','dracula') }
            '2' { Toggle-ConfigBool -Key 'autoUpdate' }
            '3' { Toggle-ConfigBool -Key 'showBanner' }
            '4' { Set-ConfigPrompt -Key 'language' -Options @('es','en') }
            '5' { Toggle-ConfigBool -Key 'dryRunDefault' }
            '6' { Set-ConfigPrompt -Key 'bootAnimation' -Options @('typewriter','matrix','none') }
            '7' { Toggle-ConfigBool -Key 'soundEnabled' }
            '8' { Set-ConfigPrompt -Key 'preferredDNS' -Options @('auto','cloudflare','google') }
            '9' { Toggle-ConfigBool -Key 'confirmDestructive' }
            'R' { Reset-Config }
            'V' { Show-ConfigFile }
            'B' { return }
            default { }
        }
    } while ($true)
}

function Toggle-ConfigBool {
    param([string]$Key)
    $cur = $Global:GF.Config.$Key
    Set-ConfigValue -Key $Key -Value (-not $cur)
    Write-UI ("    -> $Key = " + (-not $cur)) -Color Green
    Start-Sleep -Milliseconds 800
}

function Set-ConfigPrompt {
    param([string]$Key, [string[]]$Options)
    Write-Host ""
    Write-UI ("    Valores validos para ${Key}: " + ($Options -join ', ')) -Color Cyan
    Write-UI "    Nuevo valor: " -Color Yellow -NoNewline
    $val = (Read-Host).Trim().ToLower()
    if ($val -in $Options) {
        Set-ConfigValue -Key $Key -Value $val
        Write-UI ("    -> ${Key} = $val") -Color Green

        # Preview de tema: si cambiaron theme, mostrar paleta del nuevo tema
        if ($Key -eq 'theme') {
            Show-ThemePreview
        }
    } else {
        Write-UI "    Valor invalido, sin cambios." -Color Red
    }
    Start-Sleep -Seconds 1
}

function Show-ThemePreview {
    Write-Host ""
    Write-UI "    === PREVIEW DEL TEMA ===" -Color Cyan
    Write-UI "    Texto primario (como stats OK)"        -Color Green
    Write-UI "    Texto secundario (bordes, separadores)" -Color DarkGreen
    Write-UI "    Acento (teclas de menu [1][2])"         -Color Yellow
    Write-UI "    Titulos de seccion"                      -Color Cyan
    Write-UI "    Warning (uso alto)"                      -Color Yellow
    Write-UI "    Danger (uso critico)"                    -Color Red
    Write-UI "    Texto apagado (hints)"                   -Color DarkGray
    Write-Host ""
    Write-UI "    " -NoNewline
    Write-Badge -Text ' BADGE EJEMPLO ' -Bg DarkYellow -Fg Black
    Write-Host ""
    Write-Host ""
}

function Reset-Config {
    Write-Host ""
    Write-UI "  [?] Restaurar configuracion a defaults? (s/N): " -Color Yellow -NoNewline
    $r = Read-Host
    if ($r.Trim().ToLower() -eq 's') {
        $Global:GF.Config = [pscustomobject]$Script:ConfigSchema
        Save-Config | Out-Null
        Write-UI "  Configuracion restaurada." -Color Green
        Start-Sleep -Seconds 1
    }
}

function Show-ConfigFile {
    $path = Get-ConfigPath
    Write-Host ""
    Write-UI ("  Archivo: " + $path) -Color Cyan
    if (Test-Path $path) {
        Get-Content $path | ForEach-Object { Write-UI ("    " + $_) -Color Green }
    } else {
        Write-UI "    (no existe)" -Color DarkGray
    }
    Write-Host ""
    Write-UI "    Presiona ENTER..." -Color DarkGreen -NoNewline
    [void](Read-Host)
}

# ============================================================================
#  Exportar / Importar perfiles (.gfprofile)
# ============================================================================

function Export-GameFixerProfile {
    param([string]$Name)

    if (-not $Name) {
        Write-UI "  Nombre del perfil a exportar: " -Color Yellow -NoNewline
        $Name = (Read-Host).Trim()
    }
    if (-not $Name) { return }

    $profilesDir = Join-Path $Global:GF.Root 'profiles'
    if (-not (Test-Path $profilesDir)) { New-Item -ItemType Directory -Path $profilesDir -Force | Out-Null }

    $safeName = $Name -replace '[^\w\-]', '_'
    $file = Join-Path $profilesDir "$safeName.gfprofile"

    # Recolectar DNS configurado (fuera del hashtable porque try/catch no puede ir inline)
    $dnsConfig = @()
    try {
        $dnsConfig = @(Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                       Where-Object { $_.ServerAddresses.Count -gt 0 } |
                       Select-Object -First 1 -ExpandProperty ServerAddresses)
    } catch {}

    # Recolectar estado actual para exportar
    $profile = [ordered]@{
        FormatVersion = '1.0'
        ProfileName   = $Name
        ExportedAt    = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        ExportedBy    = $Global:GF.User + '@' + $Global:GF.Hostname
        GameFixerVer  = $Global:GF.Version

        Config        = $Global:GF.Config

        # Tweaks actuales del registro (snapshot)
        RegistryState = @{
            GameMode           = Get-RegValueSafe 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled'
            GameDVR            = Get-RegValueSafe 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled'
            SystemResponsive   = Get-RegValueSafe 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'SystemResponsiveness'
            HwGPUScheduling    = Get-RegValueSafe 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode'
            MouseAccel         = Get-RegValueSafe 'HKCU:\Control Panel\Mouse' 'MouseSpeed'
        }

        # Plan de energia activo
        PowerPlan = (powercfg /getactivescheme 2>$null | Out-String).Trim()

        # DNS configurado
        DNSConfig = $dnsConfig

        Notes = ''
    }

    try {
        $profile | ConvertTo-Json -Depth 6 | Set-Content -Path $file -Encoding UTF8
        Write-UI "  Perfil exportado: $file" -Color Green
        Write-Log -Level INFO -Message "Perfil exportado: $file"
    } catch {
        Write-UI ("  [X] Error al exportar: " + $_.Exception.Message) -Color Red
    }
}

function Import-GameFixerProfile {
    Write-Host ""
    $profilesDir = Join-Path $Global:GF.Root 'profiles'
    if (-not (Test-Path $profilesDir)) {
        Write-UI "  No hay perfiles guardados en $profilesDir" -Color Yellow
        Write-UI "  Tambien podes arrastrar un .gfprofile a esa carpeta y reintentar." -Color DarkGray
        Start-Sleep -Seconds 2
        return
    }

    $files = @(Get-ChildItem $profilesDir -Filter '*.gfprofile' -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) {
        Write-UI "  No hay archivos .gfprofile en $profilesDir" -Color Yellow
        Start-Sleep -Seconds 2
        return
    }

    Write-UI "  Perfiles disponibles:" -Color Cyan
    for ($i = 0; $i -lt $files.Count; $i++) {
        Write-UI ("    [{0}] {1}" -f ($i + 1), $files[$i].Name) -Color Yellow
    }
    Write-UI "  Numero a importar (o B para cancelar): " -Color Cyan -NoNewline
    $sel = (Read-Host).Trim()
    if ($sel -eq 'B' -or $sel -eq 'b') { return }
    $idx = 0
    if (-not [int]::TryParse($sel, [ref]$idx) -or $idx -lt 1 -or $idx -gt $files.Count) {
        Write-UI "  Seleccion invalida." -Color Red
        Start-Sleep -Seconds 1
        return
    }

    $file = $files[$idx - 1]
    try {
        $profile = Get-Content $file.FullName -Raw | ConvertFrom-Json
    } catch {
        Write-UI ("  [X] Archivo corrupto: " + $_.Exception.Message) -Color Red
        return
    }

    Write-Host ""
    Write-UI "  Perfil: $($profile.ProfileName)" -Color Green
    Write-UI "  Exportado: $($profile.ExportedAt) por $($profile.ExportedBy)" -Color DarkGray
    Write-UI "  Version GameFixer de origen: $($profile.GameFixerVer)" -Color DarkGray
    Write-Host ""
    Write-UI "  Aplicar este perfil al sistema? (s/N): " -Color Yellow -NoNewline
    $r = Read-Host
    if ($r.Trim().ToLower() -ne 's') { return }

    # Aplicar config
    if ($profile.Config) {
        $Global:GF.Config = $profile.Config
        Save-Config | Out-Null
        Write-UI "    [OK] Config cargada" -Color Green
    }

    # Aplicar registro (con respect a DryRun)
    if ($profile.RegistryState -and -not $Global:GF.DryRun) {
        if ($null -ne $profile.RegistryState.GameMode) {
            $k = 'HKCU:\Software\Microsoft\GameBar'
            if (-not (Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
            Set-ItemProperty -Path $k -Name 'AutoGameModeEnabled' -Value $profile.RegistryState.GameMode -Type DWord -Force
            Write-UI "    [OK] GameMode aplicado" -Color Green
        }
        if ($null -ne $profile.RegistryState.SystemResponsive) {
            $k = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
            Set-ItemProperty -Path $k -Name 'SystemResponsiveness' -Value $profile.RegistryState.SystemResponsive -Type DWord -Force
            Write-UI "    [OK] SystemResponsiveness aplicado" -Color Green
        }
    } elseif ($Global:GF.DryRun) {
        Write-UI "    [PRUEBA] Cambios de registro simulados, no aplicados" -Color DarkYellow
    }

    Write-UI "  Perfil importado correctamente." -Color Green
    Write-Log -Level INFO -Message "Perfil importado: $($profile.ProfileName)"
    Start-Sleep -Seconds 2
}

function Get-RegValueSafe {
    param([string]$Path, [string]$Name)
    try {
        $p = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        if ($p) { return $p.$Name }
    } catch {}
    return $null
}

function Invoke-ProfileIOMenu {
    do {
        Show-Section "IMPORTAR / EXPORTAR PERFILES"

        Write-UI "  Los perfiles .gfprofile son snapshots completos de tu configuracion:" -Color Cyan
        Write-UI "    - Config del usuario (tema, idioma, preferencias)" -Color DarkGray
        Write-UI "    - Estado actual de tweaks del registro" -Color DarkGray
        Write-UI "    - Plan de energia y DNS activos" -Color DarkGray
        Write-UI "  Podes compartirlos con amigos para que apliquen tu setup con un click." -Color DarkGray
        Write-Host ""
        Write-UI "  [1] Exportar mi configuracion actual" -Color Yellow
        Write-UI "  [2] Importar un perfil" -Color Yellow
        Write-UI "  [3] Listar perfiles guardados" -Color Yellow
        Write-UI "  [4] Abrir carpeta de perfiles" -Color Yellow
        Write-UI "  [B] Volver" -Color Yellow
        Write-Host ""
        Write-UI "  > " -Color Cyan -NoNewline
        $sub = (Read-Host).Trim().ToUpper()

        switch ($sub) {
            '1' { Export-GameFixerProfile }
            '2' { Import-GameFixerProfile }
            '3' {
                $profilesDir = Join-Path $Global:GF.Root 'profiles'
                if (Test-Path $profilesDir) {
                    Get-ChildItem $profilesDir -Filter '*.gfprofile' | ForEach-Object {
                        Write-UI ("    " + $_.Name + " - " + $_.LastWriteTime) -Color Green
                    }
                } else {
                    Write-UI "    (sin perfiles)" -Color DarkGray
                }
            }
            '4' {
                $profilesDir = Join-Path $Global:GF.Root 'profiles'
                if (-not (Test-Path $profilesDir)) { New-Item -ItemType Directory -Path $profilesDir -Force | Out-Null }
                Start-Process $profilesDir
            }
            'B' { return }
            default { }
        }

        if ($sub -match '^[1-4]$') {
            Write-Host ""
            Write-UI "  Presiona ENTER..." -Color DarkGreen -NoNewline
            [void](Read-Host)
        }
    } while ($true)
}

Export-ModuleMember -Function Initialize-Config, Save-Config, Set-ConfigValue, `
    Invoke-ConfigMenu, Export-GameFixerProfile, Import-GameFixerProfile, `
    Invoke-ProfileIOMenu, Get-ConfigPath, Get-RegValueSafe
