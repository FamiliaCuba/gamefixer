@echo off
REM ============================================================================
REM  GAMEFIXER - Launcher
REM  Fuerza UTF-8 en la consola y abre PowerShell con el script
REM ============================================================================
chcp 65001 > nul
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0GameFixer.ps1" %*
