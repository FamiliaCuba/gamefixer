# ============================================================================
#  plugins/ejemplo.psm1
#  Plugin de ejemplo: muestra un reloj digital ASCII durante 10 segundos
#
#  Copia este archivo y renombralo (ej: miplugin.psm1) para crear el tuyo.
# ============================================================================

$Global:PluginInfo = @{
    Name        = 'Reloj ASCII'
    Version     = '1.0'
    Author      = 'FamiliaCuba'
    Description = 'Muestra un reloj digital ASCII en pantalla'
    EntryPoint  = 'Invoke-AsciiClock'
}

$Script:DigitMap = @{
    '0' = @('###','# #','# #','# #','###')
    '1' = @('  #','  #','  #','  #','  #')
    '2' = @('###','  #','###','#  ','###')
    '3' = @('###','  #','###','  #','###')
    '4' = @('# #','# #','###','  #','  #')
    '5' = @('###','#  ','###','  #','###')
    '6' = @('###','#  ','###','# #','###')
    '7' = @('###','  #','  #','  #','  #')
    '8' = @('###','# #','###','# #','###')
    '9' = @('###','# #','###','  #','###')
    ':' = @('   ',' # ','   ',' # ','   ')
}

function Invoke-AsciiClock {
    Clear-Host
    Write-UI "Reloj ASCII - Ctrl+C para salir (o espera 10s)" -Color Cyan
    Write-Host ""

    $endTime = (Get-Date).AddSeconds(10)
    while ((Get-Date) -lt $endTime) {
        [Console]::SetCursorPosition(0, 3)
        $time = Get-Date -Format 'HH:mm:ss'
        $rows = @('','','','','')
        foreach ($char in $time.ToCharArray()) {
            $pattern = $Script:DigitMap[[string]$char]
            if ($pattern) {
                for ($i = 0; $i -lt 5; $i++) { $rows[$i] += $pattern[$i] + ' ' }
            }
        }
        foreach ($r in $rows) {
            Write-UI ("   " + $r) -Color Green
        }
        Start-Sleep -Milliseconds 500
    }
    Write-Host ""
    Write-UI "Clock cerrado." -Color DarkGray
}

Export-ModuleMember -Function Invoke-AsciiClock
