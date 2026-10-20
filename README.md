# Game Fixer

Versión actual: **3.0.1**

[![CI](https://github.com/FamiliaCuba/gamefixer/actions/workflows/ci.yml/badge.svg)](https://github.com/FamiliaCuba/gamefixer/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/FamiliaCuba/gamefixer)](https://github.com/FamiliaCuba/gamefixer/releases)

Ventana para diagnosticar, reparar y medir un PC gamer. Un solo ejecutable. El modo prueba viene activado y no cambia el equipo hasta que pasas a real.

La descarga está en [Releases](https://github.com/FamiliaCuba/gamefixer/releases).

## Qué hay en la ventana

- **Inicio.** Diagnóstico, salud de Windows, auto-fix y optimización.
- **Reparar.** Limpieza, inicio de Windows y reparación del sistema.
- **Juegos.** Detección y ajustes por juego.
- **Red.** Latencia, DNS y adaptador.
- **Medir.** Pruebas de procesador, memoria, disco y red.
- **Soporte.** Informe del equipo y código para copiar.

Discord: [FamiliaCuba](https://discord.gg/WecrFkBGGx)

## Desde el código

Windows 10 u 11. PowerShell 5.1. Pide administrador.

```powershell
.\GameFixer.ps1
.\GameFixer.ps1 -Live
```

La ventana se empaqueta con `tools\pack-exe.ps1`.

## Licencia

MIT. FamiliaCuba.
