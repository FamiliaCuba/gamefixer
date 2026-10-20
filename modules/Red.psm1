# ============================================================================
#  modules/Red.psm1
#  Diagnostico y optimizacion de red
# ============================================================================

function Invoke-RedMenu {
    do {
        Clear-Host
        Show-Section "MODULO RED"

        Write-UI "  [1] Test de latencia (ping a DNS populares)" -Color Yellow
        Write-UI "  [2] Reiniciar adaptador y vaciar DNS" -Color Yellow
        Write-UI "  [3] Cambiar DNS a Cloudflare (1.1.1.1)" -Color Yellow
        Write-UI "  [4] Cambiar DNS a Google (8.8.8.8)" -Color Yellow
        Write-UI "  [5] Restaurar DNS automatico (DHCP)" -Color Yellow
        Write-UI "  [6] Test de velocidad (100MB + upload)" -Color Yellow
        Write-UI "  [7] Ver conexiones activas (netstat)" -Color Yellow
        Write-UI "  [B] Volver al menu principal" -Color Yellow
        Write-Host ""
        Write-UI "  > " -Color Cyan -NoNewline
        $sub = (Read-Host).Trim().ToUpper()

        switch ($sub) {
            '1' { Test-Latency;      Pause-Submenu }
            '2' { Reset-Network;     Pause-Submenu }
            '3' { Set-DNSCloudflare; Pause-Submenu }
            '4' { Set-DNSGoogle;     Pause-Submenu }
            '5' { Reset-DNS;         Pause-Submenu }
            '6' { Test-Speed;        Pause-Submenu }
            '7' { Show-Connections;  Pause-Submenu }
            'B' { return }
            default { }
        }
    } while ($true)
}

function Test-Latency {
    Write-Host ""
    Write-UI "Test de latencia:" -Color Cyan
    $targets = @(
        @{ Name='Cloudflare'; IP='1.1.1.1' }
        @{ Name='Google    '; IP='8.8.8.8' }
        @{ Name='Quad9     '; IP='9.9.9.9' }
        @{ Name='OpenDNS   '; IP='208.67.222.222' }
    )
    foreach ($t in $targets) {
        $p = Test-Connection -ComputerName $t.IP -Count 4 -ErrorAction SilentlyContinue
        if ($p) {
            $avg = [math]::Round(($p | Measure-Object ResponseTime -Average).Average, 0)
            $color = if ($avg -lt 20) { 'Green' } elseif ($avg -lt 60) { 'Yellow' } else { 'Red' }
            Write-UI ("  $($t.Name) ($($t.IP)) : $avg ms") -Color $color
            Write-Log -Level INFO -Message "Latencia $($t.Name): $avg ms"
        } else {
            Write-UI ("  $($t.Name) ($($t.IP)) : timeout") -Color Red
        }
    }
}

function Get-InternetAdapters {
    $skip = 'Hyper-V|vEthernet|VirtualBox|VMware|Wintun|WireGuard|Bluetooth|Loopback|WSL|Npcap|TAP-|TAP '
    $up = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
        $_.Status -eq 'Up' -and $_.HardwareInterface -and -not $_.Virtual -and
        $_.Name -notmatch $skip -and $_.InterfaceDescription -notmatch $skip
    })
    $routed = @()
    try {
        $idx = @(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction Stop |
            Where-Object { $_.NextHop -and $_.NextHop -ne '0.0.0.0' } |
            Select-Object -ExpandProperty InterfaceIndex -Unique)
        if ($idx.Count -gt 0) {
            $routed = @($up | Where-Object { $idx -contains $_.InterfaceIndex })
        }
    } catch {}
    if ($routed.Count -gt 0) { return $routed }
    return $up
}

function Reset-Network {
    Write-Host ""
    Write-UI "Reinicio del adaptador:" -Color Cyan
    Write-UI "  Vacia la cache DNS y reinicia solo el adaptador que sale a internet." -Color DarkGray
    Write-UI "  No usa ipconfig /release, winsock reset ni ip reset." -Color DarkGray

    Invoke-LoggedAction -Description "Vaciar cache DNS" -Action {
        ipconfig /flushdns | Out-Null
        Clear-DnsClientCache -ErrorAction SilentlyContinue
    }

    $adapters = @(Get-InternetAdapters)
    if ($adapters.Count -eq 0) {
        Write-UI "  No hay un adaptador fisico con internet." -Color Yellow
        return
    }

    foreach ($a in $adapters) {
        $adapterName = [string]$a.Name
        $restart = { Restart-NetAdapter -Name $adapterName -Confirm:$false -ErrorAction Stop }.GetNewClosure()
        Invoke-LoggedAction -Description ("Reiniciar adaptador " + $adapterName) -Action $restart
    }

    if ($Global:GF.DryRun) {
        Write-UI "  [PRUEBA] El adaptador no se reinicio." -Color DarkYellow
        return
    }

    Start-Sleep -Seconds 4
    foreach ($a in $adapters) {
        $name = [string]$a.Name
        $fresh = Get-NetAdapter -Name $name -ErrorAction SilentlyContinue
        $ip = @(Get-NetIPAddress -InterfaceAlias $name -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -ne '127.0.0.1' })
        if (-not $fresh -or $fresh.Status -ne 'Up' -or $ip.Count -eq 0) {
            Write-UI ("  " + $name + " no recupero direccion. Volviendo a activarlo...") -Color Yellow
            Enable-NetAdapter -Name $name -Confirm:$false -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3
            & ipconfig /renew $name | Out-Null
            Start-Sleep -Seconds 2
            $ip = @(Get-NetIPAddress -InterfaceAlias $name -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Where-Object { $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -ne '127.0.0.1' })
        }
        if ($ip.Count -gt 0) {
            Write-UI ("  " + $name + " en linea: " + $ip[0].IPAddress) -Color Green
        } else {
            Write-UI ("  " + $name + " sigue sin IPv4. Revisa el Wi-Fi o el cable.") -Color Red
        }
    }
}

function Set-DNSToServers {
    param([string[]]$Servers, [string]$Name)
    Invoke-LoggedAction -Description "Configurar DNS a $Name ($($Servers -join ', '))" -Action {
        $adapters = @(Get-InternetAdapters)
        if ($adapters.Count -eq 0) { throw 'No hay un adaptador fisico con internet.' }
        foreach ($a in $adapters) {
            Set-DnsClientServerAddress -InterfaceIndex $a.InterfaceIndex -ServerAddresses $Servers
            Write-UI ("       Configurado en: $($a.Name)") -Color Green
        }
    }
    Invoke-LoggedAction -Description "Flush DNS despues de cambio" -Action {
        ipconfig /flushdns | Out-Null
    }
}

function Set-DNSCloudflare {
    Write-Host ""
    Set-DNSToServers -Servers @('1.1.1.1','1.0.0.1') -Name 'Cloudflare'
}

function Set-DNSGoogle {
    Write-Host ""
    Set-DNSToServers -Servers @('8.8.8.8','8.8.4.4') -Name 'Google'
}

function Reset-DNS {
    Write-Host ""
    Invoke-LoggedAction -Description "Restaurar DNS a DHCP (automatico)" -Action {
        $adapters = @(Get-InternetAdapters)
        if ($adapters.Count -eq 0) { throw 'No hay un adaptador fisico con internet.' }
        foreach ($a in $adapters) {
            Set-DnsClientServerAddress -InterfaceIndex $a.InterfaceIndex -ResetServerAddresses
        }
    }
}

function Test-Speed {
    Write-Host ""
    Write-UI "Test de velocidad (download + jitter, optimizado para fibra)..." -Color Cyan
    Write-UI "  El test se adapta a tu conexion: mas rapida = mas datos." -Color DarkGray
    Write-Host ""

    # Ping + jitter
    $pings = Test-Connection -ComputerName '1.1.1.1' -Count 5 -ErrorAction SilentlyContinue
    $avg = 999
    $jitter = 0
    if ($pings) {
        $avg = [int]($pings | Measure-Object ResponseTime -Average).Average
        $times = $pings | Select-Object -ExpandProperty ResponseTime
        $mean = ($times | Measure-Object -Average).Average
        $sqDiff = $times | ForEach-Object { [math]::Pow($_ - $mean, 2) }
        $variance = ($sqDiff | Measure-Object -Average).Average
        $jitter = [math]::Round([math]::Sqrt($variance), 1)
        Write-UI ("  Ping Cloudflare : {0} ms  (jitter {1} ms)" -f $avg, $jitter) -Color Green
    }

    # Setup .NET para high throughput
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    [Net.ServicePointManager]::DefaultConnectionLimit = 100
    [Net.ServicePointManager]::Expect100Continue = $false
    $userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 GameFixer/2.07'

    # Fuentes en orden de preferencia.
    # Para fibra >= 1 Gbps, Cloudflare soporta __down?bytes= hasta varios GB.
    $sources = @(
        @{ Name='Cloudflare 1GB';   Url='https://speed.cloudflare.com/__down?bytes=1073741824'; ExpectedMB=1024 }
        @{ Name='Cloudflare 500MB'; Url='https://speed.cloudflare.com/__down?bytes=524288000';  ExpectedMB=500  }
        @{ Name='Hetzner 1GB';      Url='https://ash-speed.hetzner.com/1GB.bin';                ExpectedMB=1024 }
        @{ Name='OVH 1GB';          Url='http://proof.ovh.net/files/1Gb.dat';                   ExpectedMB=125  }  # 1Gb=1Gbit = 125MB
        @{ Name='Cloudflare 100MB'; Url='https://speed.cloudflare.com/__down?bytes=104857600';  ExpectedMB=100  }
    )

    $bestMbps = 0
    $sourceUsed = $null
    $bytesDownloaded = 0
    $elapsedTotal = 0

    foreach ($src in $sources) {
        try {
            Write-UI ("  Probando $($src.Name)...") -Color DarkGreen

            # Usamos HttpWebRequest + stream para medir en tiempo real
            $req = [System.Net.HttpWebRequest]::Create($src.Url)
            $req.UserAgent = $userAgent
            $req.Timeout = 30000
            $req.ReadWriteTimeout = 30000
            $req.AllowAutoRedirect = $true

            $response = $req.GetResponse()
            $stream = $response.GetResponseStream()

            # Buffer grande para minimizar overhead (1 MB chunks)
            $buffer = New-Object byte[] (1MB)
            $totalBytes = 0
            $samples = @()  # ventana deslizante (timestamp, bytesAtTime)

            $startTime = [System.Diagnostics.Stopwatch]::StartNew()
            $lastReport = 0

            # Leer hasta tener una medicion estable (5-10 segundos) o hasta terminar
            $maxDurationMs = 10000   # max 10s por fuente
            $minDurationMs = 3000    # min 3s para medir bien

            while ($true) {
                $read = $stream.Read($buffer, 0, $buffer.Length)
                if ($read -le 0) { break }
                $totalBytes += $read

                # Sample cada 100ms
                $nowMs = $startTime.ElapsedMilliseconds
                if (($nowMs - $lastReport) -ge 100) {
                    $samples += @{ Ms = $nowMs; Bytes = $totalBytes }
                    $lastReport = $nowMs

                    # Mostrar progreso cada 500ms
                    if ($samples.Count % 5 -eq 0) {
                        $currentMbps = if ($nowMs -gt 0) {
                            [math]::Round(($totalBytes * 8) / 1MB / ($nowMs / 1000), 1)
                        } else { 0 }
                        $mbDone = [math]::Round($totalBytes / 1MB, 1)
                        Write-Host -NoNewline ("`r    Descargado {0,7:N1} MB en {1,5:N1}s -> {2,6:N1} Mbps " -f $mbDone, ($nowMs/1000), $currentMbps) -ForegroundColor Green
                    }
                }

                # Si ya pasamos el max, cortar
                if ($nowMs -ge $maxDurationMs) { break }
            }

            $stream.Close()
            $response.Close()
            $startTime.Stop()
            Write-Host ""

            $elapsedSec = $startTime.Elapsed.TotalSeconds
            if ($elapsedSec -le 0) { $elapsedSec = 0.001 }

            # Calcular velocidad usando ventana deslizante: ultimos 3 segundos.
            # Esto descarta el slow-start de TCP y la latencia inicial.
            $finalMbps = 0
            if ($samples.Count -ge 10 -and $elapsedSec -ge 2) {
                # Buscar una muestra de ~3 segundos antes del fin
                $endSample = $samples[-1]
                $targetMs = $endSample.Ms - 3000
                $startSample = $samples | Where-Object { $_.Ms -ge $targetMs } | Select-Object -First 1
                if (-not $startSample) { $startSample = $samples[0] }

                $deltaMs = $endSample.Ms - $startSample.Ms
                $deltaBytes = $endSample.Bytes - $startSample.Bytes
                if ($deltaMs -gt 0) {
                    $finalMbps = [math]::Round(($deltaBytes * 8) / 1MB / ($deltaMs / 1000), 1)
                }
            } else {
                # Fallback: promedio simple
                $finalMbps = [math]::Round(($totalBytes * 8) / 1MB / $elapsedSec, 1)
            }

            $mbTotal = [math]::Round($totalBytes / 1MB, 1)
            Write-UI ("    Resultado: {0:N1} MB en {1:N1}s -> {2:N1} Mbps (ventana deslizante)" -f $mbTotal, $elapsedSec, $finalMbps) -Color Green

            if ($finalMbps -gt $bestMbps) {
                $bestMbps = $finalMbps
                $sourceUsed = $src.Name
                $bytesDownloaded = $totalBytes
                $elapsedTotal = $elapsedSec
            }

            # Si ya alcanzamos velocidad alta o el test duro suficiente, cortar
            if ($elapsedSec -ge 5 -and $finalMbps -gt 100) {
                break  # medicion ya confiable
            }

        } catch {
            $err = $_.Exception.Message
            if ($err.Length -gt 80) { $err = $err.Substring(0, 80) + '...' }
            Write-UI ("`r    [!] $($src.Name) fallo: $err                                    ") -Color DarkYellow
            continue
        }
    }

    if ($bestMbps -eq 0) {
        Write-UI "  [X] No se pudo medir velocidad desde ninguna fuente." -Color Red
        return
    }

    # Conversion a unidades faciles de entender
    $mbps = $bestMbps
    $mbpsReal = [math]::Round($mbps / 8, 1)   # MegaBytes/s (velocidad real de descarga)
    $gbps = [math]::Round($mbps / 1000, 2)

    Write-Host ""
    Write-UI "  === RESULTADO FINAL ===" -Color Cyan
    if ($gbps -ge 1) {
        Write-UI ("  Velocidad: {0} Mbps ({1} Gbps / {2} MB/s)" -f $mbps, $gbps, $mbpsReal) -Color Green
    } else {
        Write-UI ("  Velocidad: {0} Mbps ({1} MB/s de descarga real)" -f $mbps, $mbpsReal) -Color Green
    }
    Write-UI ("  Fuente usada: $sourceUsed") -Color DarkGray
    Write-UI ("  Datos transferidos: {0:N1} MB en {1:N1}s" -f ($bytesDownloaded/1MB), $elapsedTotal) -Color DarkGray

    # Gaming rating actualizado
    Write-Host ""
    $tier = 'UNKNOWN'; $col = 'DarkGray'
    if ($avg -lt 20 -and $mbps -ge 300)        { $tier = 'EXCELENTE - fibra para competitivo'; $col = 'Green' }
    elseif ($avg -lt 30 -and $mbps -ge 100)    { $tier = 'MUY BUENO - juegos online sin problema'; $col = 'Green' }
    elseif ($avg -lt 50 -and $mbps -ge 50)     { $tier = 'BUENO - casual y coop'; $col = 'Green' }
    elseif ($avg -lt 80 -and $mbps -ge 25)     { $tier = 'ACEPTABLE - puede haber lag en FPS rapidos'; $col = 'Yellow' }
    else                                        { $tier = 'MEJORABLE - revisa tu red (cable > wifi)'; $col = 'Red' }
    Write-UI ("  Rating gaming: $tier") -Color $col

    Write-Log -Level INFO -Message "Speed test: $mbps Mbps from $sourceUsed (${bytesDownloaded}B in ${elapsedTotal}s)"
}


function Show-Connections {
    Write-Host ""
    Write-UI "Conexiones TCP establecidas:" -Color Cyan
    try {
        Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
            Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, OwningProcess -First 20 |
            Format-Table -AutoSize | Out-String | ForEach-Object { Write-UI $_ -Color Green }
    } catch {
        Write-UI ("  [!] " + $_.Exception.Message) -Color Red
    }
}

Export-ModuleMember -Function Invoke-RedMenu
