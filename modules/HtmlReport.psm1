# ============================================================================
#  modules/HtmlReport.psm1
#  Generacion de reportes HTML profesionales para presentar resultados
# ============================================================================

function New-HtmlReport {
    param(
        [Parameter(Mandatory=$true)]$Pipeline
    )

    $reportsDir = Join-Path $Global:GF.Root 'reports'
    if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null }
    $reportFile = Join-Path $reportsDir ("report-{0}.html" -f (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))

    # Construir filas de steps
    $stepsHtml = ''
    foreach ($s in $Pipeline.Steps) {
        $badge = if ($s.Status -eq 'OK') { '<span class="badge ok">OK</span>' } else { '<span class="badge fail">FAIL</span>' }
        $extra = ''
        if ($s.FreedMB) { $extra = " &mdash; <em>liberados $($s.FreedMB) MB</em>" }
        if ($s.DiskFreePct) { $extra = " &mdash; <em>disco libre $($s.DiskFreePct)%</em>" }
        $stepsHtml += "<tr><td>$($s.Name)</td><td>$badge$extra</td></tr>`n"
    }

    # Construir comparativa de benchmarks
    $benchHtml = ''
    if ($Pipeline.BenchBefore -and $Pipeline.BenchAfter) {
        $cats = @(
            @{ Label='CPU Single (ops/s)';  Before=$Pipeline.BenchBefore.CPU.SingleScore;  After=$Pipeline.BenchAfter.CPU.SingleScore  },
            @{ Label='CPU Multi  (ops/s)';  Before=$Pipeline.BenchBefore.CPU.MultiScore;   After=$Pipeline.BenchAfter.CPU.MultiScore   },
            @{ Label='RAM Read   (MB/s)';   Before=$Pipeline.BenchBefore.RAM.ReadMBs;      After=$Pipeline.BenchAfter.RAM.ReadMBs      },
            @{ Label='Disk Read  (MB/s)';   Before=$Pipeline.BenchBefore.Disk.ReadMBs;     After=$Pipeline.BenchAfter.Disk.ReadMBs     },
            @{ Label='Net Ping   (ms)';     Before=$Pipeline.BenchBefore.Network.PingMs;   After=$Pipeline.BenchAfter.Network.PingMs; LowerBetter=$true  },
            @{ Label='Net Down   (Mbps)';   Before=$Pipeline.BenchBefore.Network.DownMbps; After=$Pipeline.BenchAfter.Network.DownMbps }
        )
        foreach ($c in $cats) {
            if ($null -eq $c.Before -or $null -eq $c.After) { continue }
            if ($c.Before -eq 0) { continue }
            $delta = $c.After - $c.Before
            $pct = [math]::Round(($delta / $c.Before) * 100, 1)
            $isBetter = if ($c.LowerBetter) { $pct -lt 0 } else { $pct -gt 0 }
            $cls = if ($pct -eq 0) { 'neutral' } elseif ($isBetter) { 'better' } else { 'worse' }
            $sign = if ($pct -gt 0) { '+' } else { '' }
            $benchHtml += "<tr><td>$($c.Label)</td><td>$($c.Before)</td><td>$($c.After)</td><td class='$cls'>$sign$pct%</td></tr>`n"
        }
    }

    # Info del sistema
    $host = $Global:GF.Hostname
    $user = $Global:GF.User
    $mode = if ($Pipeline.DryRun) { 'DRY-RUN' } else { 'LIVE' }
    $modeClass = if ($Pipeline.DryRun) { 'dry' } else { 'live' }
    $okCount = ($Pipeline.Steps | Where-Object Status -eq 'OK').Count
    $totalCount = $Pipeline.Steps.Count

    $html = @"
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>GameFixer Report - $($Pipeline.StartedAt)</title>
<style>
  :root {
    --bg: #0a0e0a;
    --panel: #0f1410;
    --border: #1f6b32;
    --fg: #39ff6a;
    --fg-soft: #7fff9a;
    --fg-dim: #1f6b32;
    --yellow: #ffd23f;
    --red: #ff6b6b;
  }
  * { box-sizing: border-box; }
  body {
    background: var(--bg); color: var(--fg); font-family: 'Cascadia Mono','Consolas',monospace;
    margin: 0; padding: 30px; font-size: 14px; line-height: 1.6;
  }
  .container { max-width: 1100px; margin: 0 auto; }
  h1 { color: var(--fg); font-size: 28px; margin: 0; letter-spacing: 2px; text-shadow: 0 0 8px rgba(57,255,106,0.4); }
  h2 { color: var(--fg-soft); font-size: 18px; border-bottom: 1px dashed var(--border); padding-bottom: 8px; margin-top: 40px; }
  .subtitle { color: var(--fg-dim); font-size: 13px; margin: 4px 0 30px; }
  .meta { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin-bottom: 30px; }
  .metacard {
    border: 1px solid var(--border); border-radius: 4px; padding: 12px 16px;
    background: rgba(57,255,106,0.03);
  }
  .metacard .label { color: var(--fg-dim); font-size: 11px; text-transform: uppercase; letter-spacing: 1px; }
  .metacard .value { color: var(--fg); font-size: 20px; font-weight: bold; margin-top: 4px; }
  .badge {
    display: inline-block; padding: 2px 10px; border-radius: 3px; font-size: 11px;
    font-weight: bold; letter-spacing: 1px;
  }
  .badge.ok   { background: #1a4a24; color: #7fff9a; border: 1px solid #39ff6a; }
  .badge.fail { background: #4a1a1a; color: #ff6b6b; border: 1px solid #ff6b6b; }
  .badge.dry  { background: #3a2e00; color: var(--yellow); border: 1px solid var(--yellow); }
  .badge.live { background: #4a1a1a; color: #fff; border: 1px solid var(--red); }
  table {
    width: 100%; border-collapse: collapse; margin-top: 10px;
    background: var(--panel); border: 1px solid var(--border); border-radius: 4px; overflow: hidden;
  }
  th, td { padding: 10px 14px; text-align: left; border-bottom: 1px solid var(--border); }
  th { background: rgba(57,255,106,0.06); color: var(--fg-soft); font-size: 12px; text-transform: uppercase; letter-spacing: 1px; }
  tr:last-child td { border-bottom: none; }
  .better  { color: #7fff9a; font-weight: bold; }
  .worse   { color: var(--red); font-weight: bold; }
  .neutral { color: var(--fg-dim); }
  footer { margin-top: 50px; color: var(--fg-dim); font-size: 11px; text-align: center; padding-top: 20px; border-top: 1px dashed var(--border); }
  .ascii-banner { color: var(--fg); font-size: 10px; line-height: 1.1; white-space: pre; margin-bottom: 20px; }
</style>
</head>
<body>
<div class="container">
<pre class="ascii-banner"> ██████╗  █████╗ ███╗   ███╗███████╗███████╗██╗██╗  ██╗███████╗██████╗
██╔════╝ ██╔══██╗████╗ ████║██╔════╝██╔════╝██║╚██╗██╔╝██╔════╝██╔══██╗
██║  ███╗███████║██╔████╔██║█████╗  █████╗  ██║ ╚███╔╝ █████╗  ██████╔╝
██║   ██║██╔══██║██║╚██╔╝██║██╔══╝  ██╔══╝  ██║ ██╔██╗ ██╔══╝  ██╔══██╗
╚██████╔╝██║  ██║██║ ╚═╝ ██║███████╗██║     ██║██╔╝ ██╗███████╗██║  ██║
 ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝</pre>

<h1>AUTO-FIX REPORT</h1>
<div class="subtitle">Generado el $($Pipeline.StartedAt) - Duracion $($Pipeline.ElapsedSec)s</div>

<div class="meta">
  <div class="metacard"><div class="label">Host</div><div class="value">$host</div></div>
  <div class="metacard"><div class="label">User</div><div class="value">$user</div></div>
  <div class="metacard"><div class="label">Modo</div><div class="value"><span class="badge $modeClass">$mode</span></div></div>
  <div class="metacard"><div class="label">Pasos OK</div><div class="value">$okCount / $totalCount</div></div>
</div>

<h2>PIPELINE EJECUTADO</h2>
<table>
  <thead><tr><th>Paso</th><th>Estado</th></tr></thead>
  <tbody>
    $stepsHtml
  </tbody>
</table>

<h2>COMPARATIVA DE BENCHMARKS (ANTES vs DESPUES)</h2>
<table>
  <thead><tr><th>Metrica</th><th>Antes</th><th>Despues</th><th>Diferencia</th></tr></thead>
  <tbody>
    $benchHtml
  </tbody>
</table>

<footer>
  GAMEFIXER v$($Global:GF.Version -replace '^v', '') build $($Global:GF.Build) | FamiliaCuba Edition<br>
  Reporte generado por GameFixer AutoFix - https://github.com/FamiliaCuba/gamefixer
</footer>
</div>
</body>
</html>
"@

    Set-Content -Path $reportFile -Value $html -Encoding UTF8
    Write-Log -Level INFO -Message "HTML report generado: $reportFile"
    return $reportFile
}

Export-ModuleMember -Function New-HtmlReport
