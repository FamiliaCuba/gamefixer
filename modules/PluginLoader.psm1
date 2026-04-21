# ============================================================================
#  modules/PluginLoader.psm1
#  Sistema de plugins: carga dinamica de modulos desde /plugins
#
#  Un plugin es un archivo .psm1 en /plugins que define:
#    $PluginInfo = @{
#        Name        = 'Mi Plugin'
#        Version     = '1.0'
#        Author      = 'Nombre'
#        Description = 'Que hace'
#        MenuKey     = 'X'      # Tecla opcional para agregarlo al menu
#        EntryPoint  = 'Invoke-MiPlugin'  # Funcion principal
#    }
# ============================================================================

function Initialize-PluginLoader {
    $pluginDir = Join-Path $Global:GF.Root 'plugins'
    if (-not (Test-Path $pluginDir)) { New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null }

    $Global:GF.Plugins = @()
    $files = Get-ChildItem $pluginDir -Filter '*.psm1' -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        try {
            Import-Module $f.FullName -Force -DisableNameChecking -Global
            $info = Get-Variable -Name 'PluginInfo' -ValueOnly -Scope Global -ErrorAction SilentlyContinue
            if ($info) {
                $info | Add-Member -NotePropertyName 'File' -NotePropertyValue $f.Name -Force
                $Global:GF.Plugins += $info
                Write-Log -Level INFO -Message "Plugin cargado: $($info.Name) v$($info.Version) por $($info.Author)"
            }
        } catch {
            Write-Log -Level WARN -Message "Fallo cargando plugin $($f.Name): $($_.Exception.Message)"
        }
    }
}

function Invoke-PluginsMenu {
    Show-Section "PLUGINS"

    if (-not $Global:GF.Plugins -or $Global:GF.Plugins.Count -eq 0) {
        Write-UI "  No hay plugins cargados." -Color Yellow
        Write-Host ""
        Write-UI "  Para agregar uno, deja un archivo .psm1 en la carpeta /plugins." -Color DarkGray
        Write-UI "  Un plugin de ejemplo esta en plugins/ejemplo.psm1" -Color DarkGray
        return
    }

    Write-UI ("Plugins cargados: " + $Global:GF.Plugins.Count) -Color Cyan
    for ($i = 0; $i -lt $Global:GF.Plugins.Count; $i++) {
        $p = $Global:GF.Plugins[$i]
        Write-UI ("  [" + ($i + 1) + "] " + $p.Name + " v" + $p.Version + " - " + $p.Description) -Color Yellow
        Write-UI ("      por " + $p.Author + " (" + $p.File + ")") -Color DarkGray
    }
    Write-UI "  [B] Volver" -Color Yellow
    Write-Host ""
    Write-UI "  > " -Color Cyan -NoNewline
    $sub = (Read-Host).Trim().ToUpper()

    if ($sub -eq 'B') { return }
    $idx = 0
    if ([int]::TryParse($sub, [ref]$idx) -and $idx -ge 1 -and $idx -le $Global:GF.Plugins.Count) {
        $p = $Global:GF.Plugins[$idx - 1]
        if ($p.EntryPoint) {
            try {
                & $p.EntryPoint
            } catch {
                Write-UI ("  [X] Error en plugin: " + $_.Exception.Message) -Color Red
            }
        }
    }
}

Export-ModuleMember -Function Initialize-PluginLoader, Invoke-PluginsMenu
