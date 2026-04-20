# ============================================================================
#  modules/Logger.psm1
#  Sistema de logging a archivo con niveles y timestamps
# ============================================================================

function Initialize-Logger {
    if (-not (Test-Path $Global:GF.LogsDir)) {
        New-Item -ItemType Directory -Path $Global:GF.LogsDir -Force | Out-Null
    }
    $header = @"
================================================================================
  GAMEFIXER $($Global:GF.Version) - Session Log
  Started   : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
  Hostname  : $($Global:GF.Hostname)
  User      : $($Global:GF.User)
  Admin     : $($Global:GF.IsAdmin)
  DryRun    : $($Global:GF.DryRun)
  Profile   : $($Global:GF.Profile)
================================================================================
"@
    $header | Out-File -FilePath $Global:GF.LogFile -Encoding UTF8
}

function Write-Log {
    param(
        [ValidateSet('DEBUG','INFO','WARN','ERROR','ACTION')]
        [string]$Level = 'INFO',
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    $ts = Get-Date -Format 'HH:mm:ss.fff'
    $line = "[{0}] [{1,-6}] {2}" -f $ts, $Level, $Message
    try {
        Add-Content -Path $Global:GF.LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
}

function Invoke-LoggedAction {
    <#
    .SYNOPSIS
    Wrapper que loguea una accion y su resultado, respetando DryRun.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Description,
        [Parameter(Mandatory=$true)]
        [scriptblock]$Action,
        [switch]$AlwaysRun   # Si esta activo, ignora DryRun (para acciones de lectura)
    )

    Write-Log -Level ACTION -Message "INICIO: $Description"
    Write-UI ("    -> " + $Description) -Color Green

    if ($Global:GF.DryRun -and -not $AlwaysRun) {
        Write-UI "       [DRY-RUN] accion simulada" -Color DarkYellow
        Write-Log -Level INFO -Message "DRY-RUN: $Description (no ejecutado)"
        return $null
    }

    try {
        $result = & $Action
        Write-Log -Level INFO -Message "OK: $Description"
        return $result
    } catch {
        Write-UI ("       [X] " + $_.Exception.Message) -Color Red
        Write-Log -Level ERROR -Message "FAIL: $Description -> $($_.Exception.Message)"
        return $null
    }
}

Export-ModuleMember -Function Initialize-Logger, Write-Log, Invoke-LoggedAction
