# CHANGELOG

## v2.02 (FamiliaCuba Edition)

### ✨ Nuevas características

- **Auto-Fix [A]**: pipeline completo automático en un solo click (restore point → benchmark antes → diagnóstico → limpieza → optimización → benchmark después → reporte HTML)
- **Benchmarks [B]**: tests de CPU (single + multi thread), RAM (read/write MB/s), disco (I/O real), red (ping + descarga). Historial JSON + comparativa antes/después
- **Detector de juegos [G]**: detecta automáticamente Steam, Epic Games, Riot, Battle.net, Ubisoft Connect, EA App, GOG Galaxy, Xbox App. Lee manifiestos oficiales y lista juegos instalados con tamaños
- **Tweaks por juego [T]**: optimizaciones específicas para CS2, Valorant, LoL, Fortnite, GTA V, RDR2, Minecraft, Apex Legends, R6 Siege
- **Reportes HTML**: al terminar AutoFix se genera un dashboard HTML profesional con el look cyberpunk del script, comparativas before/after, y resumen de pasos
- **Sistema de plugins [X]**: arquitectura extensible — droppear un `.psm1` en `/plugins` y se carga automáticamente al arrancar
- **Plugin de ejemplo**: reloj ASCII para mostrar cómo crear plugins

### 🎨 UI mejorada

- Botón AUTO-FIX destacado al inicio del menú
- Sección "NUEVO EN v2.02" con las opciones [B] [G] [T] [X]
- Subtítulos explicativos bajo cada opción

### 🔧 Bajo el capó

- 6 módulos nuevos (`AutoFix`, `Benchmark`, `GameDetector`, `GameTweaks`, `HtmlReport`, `PluginLoader`)
- Nuevas carpetas `/reports`, `/benchmarks`, `/plugins`
- Score global de gaming normalizado 0-100 basado en hardware

## v2.1

- Release inicial con arquitectura modular
- 14 módulos de funcionalidad
- Sistema de logging
- Auto-elevación a admin
- DRY-RUN por defecto
- Telemetría en vivo
- Integración con nvidia-smi
- Backups automáticos del registro
- Auto-update desde GitHub
