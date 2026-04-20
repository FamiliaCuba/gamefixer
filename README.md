# GAMEFIXER v2.1 — FamiliaCuba Edition

Herramienta profesional de diagnóstico, optimización y reparación de Windows orientada a gaming. Escrita en PowerShell puro, arquitectura modular, con logging, backups y modo DRY-RUN.

## Características

- **Diagnóstico completo** del sistema (hardware, OS, red, eventos críticos)
- **Optimización Gamer** con tweaks reales del registro (MMCSS, GameDVR, TCP Nagle, servicios)
- **Módulo GPU NVIDIA** usando `nvidia-smi` (monitoreo en vivo, limpieza de shader cache, power limit)
- **Diagnóstico de red** (latencia a DNS populares, cambio de DNS a Cloudflare/Google, flush completo)
- **Reparación del sistema** (SFC, DISM, chkdsk, reparación de Windows Store y .NET)
- **Limpieza inteligente** (temp, cache, prefetch, logs, thumbnails, cachés de navegadores)
- **Soluciones comunes de gaming** (stuttering, audio desync, input lag, HAGS, mouse accel)
- **Rollback** con backups automáticos del registro + puntos de restauración
- **Chequeo de salud** (SMART, eventos críticos, actualizaciones)
- **Perfiles** predefinidos: Gamer, Oficina, Ahorro, Streaming

## Extras profesionales

- **Auto-elevación** a administrador al ejecutar
- **DRY-RUN por defecto** — nada se aplica hasta que lo activas con `-Live` o `[D]` en menú
- **Logging** a archivo con timestamps y niveles (DEBUG/INFO/WARN/ERROR/ACTION)
- **Backups automáticos** del registro antes de cada cambio
- **Animación de boot** estilo typewriter
- **Top bar** con hostname, admin status, uptime y reloj en vivo
- **Telemetría** en vivo: CPU + temp, GPU NVIDIA + temp, RAM, disco, red, servicios

## Estructura

```
GameFixer/
├── GameFixer.ps1              # Entry point (main loop)
├── GameFixer.bat              # Launcher con doble-click
├── README.md                  # Este archivo
├── modules/
│   ├── UI.psm1                # Interfaz, colores, banner, paneles
│   ├── Logger.psm1            # Sistema de logging
│   ├── Telemetry.psm1         # Stats del sistema
│   ├── Diagnostico.psm1
│   ├── OptimizacionGamer.psm1
│   ├── GPU.psm1
│   ├── Red.psm1
│   ├── Reparacion.psm1
│   ├── Limpieza.psm1
│   ├── SolucionesComunes.psm1
│   ├── Rollback.psm1
│   ├── Salud.psm1
│   └── Perfiles.psm1
├── logs/                      # Logs de sesión (se crea automáticamente)
└── backups/                   # Backups del registro (se crea automáticamente)
```

## Uso

**Opción 1 — doble click:** ejecuta `GameFixer.bat`.

**Opción 2 — terminal:**

```powershell
# Modo DRY-RUN (default, solo simula)
.\GameFixer.ps1

# Modo real
.\GameFixer.ps1 -Live

# Sin animación de boot
.\GameFixer.ps1 -NoBanner

# Con un perfil específico
.\GameFixer.ps1 -Profile GAMER
```

## Requisitos

- Windows 10 / 11
- PowerShell 5.1+
- Permisos de administrador (se auto-eleva)
- Opcional: `nvidia-smi` en PATH (viene con drivers NVIDIA)

## Seguridad

Antes de aplicar cambios al registro, el script crea un backup en `/backups/regbackup-<timestamp>/`. Puedes revertir cualquier cambio desde el menú **[8] Rollback**.

Adicionalmente, desde `[8] → [3]` puedes crear un punto de restauración del sistema antes de operar.

## Licencia

MIT. Úsalo, modifícalo, gana tu competencia.
