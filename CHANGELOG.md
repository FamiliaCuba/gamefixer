# CHANGELOG

## v3.0.1 - "Nueva cara" (actual)

- Ventana renovada: iconos en las tarjetas, barra de progreso, informe de soporte con código copiable y detección de juegos.
- La ficha de un juego abre su ajuste si existe. Inicio guarda las últimas acciones. Medir compara con la vez anterior. Reparar lista el inicio de Windows. El driver abre la página del fabricante.
- La app, el pie de la ventana y el actualizador anuncian la versión 3.0.1.

## v2.06 - "Live & Persistent"

### ✨ Nuevas features

- **Dashboard Live [M]**: monitor en tiempo real tipo htop con sparklines Unicode para CPU, GPU, RAM, Temp y Red. Top 5 procesos por uso de CPU. Refresco cada segundo.
- **Config persistente [S]**: `config.json` guarda preferencias entre sesiones (tema, animación de boot, auto-update, DNS, idioma, etc).
- **Perfiles exportables [E]**: archivos `.gfprofile` que snapshottean tu config + tweaks de registro + plan de energía + DNS. Compartilos con amigos.
- **Efectos visuales**: modo `matrix` de arranque con matrix rain, boot messages tipo BIOS, glitch text, progress bars animadas.

### 🧪 Tests

- +2 archivos de test nuevos (`Config.Tests.ps1`, `Dashboard.Tests.ps1`)
- 50+ tests totales

### 🎨 Menú

- Nuevas teclas: [M] Dashboard, [S] Settings, [E] Export/Import
- [C] renombrada a [I] Info para liberar espacio
- Reorganización visual de la segunda fila de opciones

## v2.05 - "CI/CD Edition"

- Suite de tests Pester 5 con 40+ tests (Unit + Integration)
- GitHub Actions workflow con Pester + PSScriptAnalyzer
- README rediseñado con badges (CI, License, Release)
- LICENSE MIT

## v2.04 - "Bug fixes"

- Disk benchmark testea TODOS los drives, no solo C:
- Speed test adaptativo (10-500MB según velocidad)
- Submenús con loop interno
- GPU VRAM ya no satura en 4GB

## v2.03 - "Multi-drive"

- Panel HARDWARE muestra barra por cada disco
- Xbox Game Pass detectado (Appx + ModifiableWindowsApps)
- Detección reforzada EA App y Ubisoft

## v2.02 - "Gaming Edition"

- AutoFix, Benchmarks, GameDetector, GameTweaks, HtmlReport, Plugins

## v2.1 - "Initial release"

- Arquitectura modular (14 módulos)
- Auto-update desde GitHub
- DRY-RUN por defecto
