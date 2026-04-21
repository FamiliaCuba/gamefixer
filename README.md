# GAMEFIXER v2.02 — FamiliaCuba Edition

Herramienta profesional de diagnóstico, optimización y reparación de Windows orientada a gaming. Escrita en PowerShell puro, arquitectura modular, con logging, backups y modo DRY-RUN.

## Novedades v2.02

- **AUTO-FIX [A]** — pipeline completo en un solo click: restore point → benchmark antes → diagnóstico → limpieza → optimización → benchmark después → reporte HTML
- **Benchmarks [B]** — tests reales de CPU (single+multi thread), RAM, disco y red. Historial + comparativa antes/después
- **Detector de juegos [G]** — detecta Steam, Epic, Riot, Battle.net, Ubisoft, EA, GOG, Xbox App. Lista todos los juegos instalados con tamaños
- **Tweaks por juego [T]** — optimizaciones específicas para CS2, Valorant, LoL, Fortnite, GTA V, RDR2, Minecraft, Apex, R6
- **Reporte HTML** — al terminar AutoFix se genera un reporte visual profesional tipo dashboard que abre en el navegador
- **Sistema de plugins [X]** — dropeás un `.psm1` en `/plugins` y se carga automáticamente. Un plugin de ejemplo ya viene incluido
- **Auto-update desde GitHub [U]** — check silencioso al arrancar, banner amarillo si hay versión nueva, update con un click

## Características

- **Diagnóstico completo** (hardware, OS, red, eventos críticos)
- **Optimización Gamer** con tweaks reales del registro (MMCSS, GameDVR, TCP Nagle, servicios)
- **GPU NVIDIA** con `nvidia-smi` (monitoreo, shader cache, power limit)
- **Red** (latencia, cambio DNS, flush, speed test)
- **Reparación** (SFC, DISM, chkdsk, Store, .NET)
- **Limpieza inteligente** (temp, cache, prefetch, browsers)
- **Soluciones gaming** (stuttering, audio, input lag, HAGS, mouse)
- **Rollback** con backups automáticos del registro + System Restore
- **Salud** (SMART, eventos críticos, hotfixes)
- **Perfiles** Gamer / Oficina / Ahorro / Streaming

## Extras profesionales

- **Auto-elevación** a administrador
- **DRY-RUN por defecto** — nada se aplica hasta que lo actives
- **Logging** a archivo con timestamps y niveles
- **Backups automáticos** del registro antes de cada cambio
- **Animación de boot** estilo typewriter
- **Top bar** con hostname, admin, uptime y reloj en vivo
- **Telemetría en vivo**: CPU + temp, GPU NVIDIA + temp, RAM, disco, red

## Estructura

```
GameFixer/
├── GameFixer.ps1              # Entry point
├── GameFixer.bat              # Launcher doble-click
├── README.md
├── version.txt                # Sincroniza con releases de GitHub
├── modules/
│   ├── UI.psm1
│   ├── Logger.psm1
│   ├── Telemetry.psm1
│   ├── Updater.psm1           # Auto-update desde GitHub
│   ├── Benchmark.psm1         # NUEVO v2.02
│   ├── HtmlReport.psm1        # NUEVO v2.02
│   ├── GameDetector.psm1      # NUEVO v2.02
│   ├── GameTweaks.psm1        # NUEVO v2.02
│   ├── AutoFix.psm1           # NUEVO v2.02
│   ├── PluginLoader.psm1      # NUEVO v2.02
│   └── (módulos de funcionalidad)
├── plugins/
│   └── ejemplo.psm1           # Plugin de ejemplo (reloj ASCII)
├── logs/
├── backups/
├── benchmarks/                # Historial de benchmarks en JSON
└── reports/                   # Reportes HTML generados por AutoFix
```

## Uso

**Doble-click:** ejecuta `GameFixer.bat`.

**Desde terminal:**

```powershell
.\GameFixer.ps1              # DRY-RUN (simula)
.\GameFixer.ps1 -Live        # Modo real
.\GameFixer.ps1 -NoBanner    # Sin animación de boot
.\GameFixer.ps1 -NoUpdate    # Sin check de updates
```

## Requisitos

- Windows 10 / 11
- PowerShell 5.1+
- Permisos de administrador (se auto-eleva)
- Opcional: `nvidia-smi` en PATH para GPU data

## Crear un plugin

Copia `plugins/ejemplo.psm1`, renómbralo y modifica el bloque `$Global:PluginInfo`:

```powershell
$Global:PluginInfo = @{
    Name        = 'Mi Plugin'
    Version     = '1.0'
    Author      = 'Tu nombre'
    Description = 'Qué hace'
    EntryPoint  = 'Invoke-MiFuncion'
}

function Invoke-MiFuncion {
    Write-UI "Hola mundo" -Color Green
}

Export-ModuleMember -Function Invoke-MiFuncion
```

## Licencia

MIT. Úsalo, modifícalo, gana tu competencia.
