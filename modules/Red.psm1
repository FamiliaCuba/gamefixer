# ============================================================================
#  modules/Red.psm1
#  Diagnostico y optimizacion de red
# ============================================================================

function Invoke-RedMenu {
    do {
        Clear-Host
        Show-Section "MODULO RED"

        Write-UI "  [1] Test de latencia (ping a DNS populares)" -Color Yellow
        Write-UI "  [2] Flush DNS + reset Winsock + TCP/IP" -Color Yellow
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

function Reset-Network {
    Write-Host ""
    Write-UI "Reset completo de red:" -Color Cyan

    Invoke-LoggedAction -Description "ipconfig /flushdns" -Action {
        ipconfig /flushdns | Out-Null
    }
    Invoke-LoggedAction -Description "ipconfig /registerdns" -Action {
        ipconfig /registerdns | Out-Null
    }
    Invoke-LoggedAction -Description "ipconfig /release + /renew" -Action {
        ipconfig /release | Out-Null
        Start-Sleep -Seconds 2
        ipconfig /renew | Out-Null
    }
    Invoke-LoggedAction -Description "netsh winsock reset" -Action {
        netsh winsock reset | Out-Null
    }
    Invoke-LoggedAction -Description "netsh int ip reset" -Action {
        netsh int ip reset | Out-Null
    }

    Write-UI "  Nota: reinicia el equipo para aplicar winsock/tcp reset." -Color DarkYellow
}

function Set-DNSToServers {
    param([string[]]$Servers, [string]$Name)
    Invoke-LoggedAction -Description "Configurar DNS a $Name ($($Servers -join ', '))" -Action {
        $adapters = Get-NetAdapter | Where-Object Status -eq 'Up'
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
        $adapters = Get-NetAdapter | Where-Object Status -eq 'Up'
        foreach ($a in $adapters) {
            Set-DnsClientServerAddress -InterfaceIndex $a.InterfaceIndex -ResetServerAddresses
        }
    }
}

function Test-Speed {
    Write-Host ""
    Write-UI "Test de velocidad (100 MB desde Cloudflare + upload 10 MB)..." -Color Cyan
    Write-UI "  Esto puede tardar 30-60 segundos segun tu conexion." -Color DarkGray
    Write-Host ""

    # Ping + jitter
    $pings = Test-Connection -ComputerName '1.1.1.1' -Count 5 -ErrorAction SilentlyContinue
    if ($pings) {
        $avg = [int]($pings | Measure-Object ResponseTime -Average).Average
        $times = $pings | Select-Object -ExpandProperty ResponseTime
        $mean = ($times | Measure-Object -Average).Average
        $sqDiff = $times | ForEach-Object { [math]::Pow($_ - $mean, 2) }
        $variance = ($sqDiff | Measure-Object -Average).Average
        $jitter = [math]::Round([math]::Sqrt($variance), 1)
        Write-UI ("  Ping Cloudflare : {0} ms  (jitter {1} ms)" -f $avg, $jitter) -Color Green
    }

    # Download 100 MB
    try {
        $url = 'https://speed.cloudflare.com/__down?bytes=100000000'
        $tmp = [System.IO.Path]::GetTempFileName()
        $client = New-Object System.Net.WebClient
        $client.Headers.Add("User-Agent", "GameFixer/2.03")
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $client.DownloadFile($url, $tmp)
        $sw.Stop()
        $sizeMB = (Get-Item $tmp).Length / 1MB
        $speed = $sizeMB * 8 / ($sw.Elapsed.TotalSeconds)
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        $client.Dispose()
        Write-UI ("  Descarga        : {0:N1} MB en {1:N1}s = {2:N1} Mbps" -f $sizeMB, $sw.Elapsed.TotalSeconds, $speed) -Color Green
        Write-Log -Level INFO -Message "Speed test: down $speed Mbps"

        # Upload
        $uploadBytes = [byte[]]::new(10 * 1MB)
        (New-Object Random).NextBytes($uploadBytes)
        $req = [System.Net.HttpWebRequest]::Create('https://speed.cloudflare.com/__up')
        $req.Method = 'POST'
        $req.ContentType = 'application/octet-stream'
        $req.ContentLength = $uploadBytes.Length
        $req.UserAgent = 'GameFixer/2.03'
        $req.Timeout = 30000

        $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
        $reqStream = $req.GetRequestStream()
        $reqStream.Write($uploadBytes, 0, $uploadBytes.Length)
        $reqStream.Close()
        $resp = $req.GetResponse()
        $sw2.Stop()
        $resp.Close()

        $upMB = $uploadBytes.Length / 1MB
        $upSpeed = $upMB * 8 / $sw2.Elapsed.TotalSeconds
        Write-UI ("  Subida          : {0:N1} MB en {1:N1}s = {2:N1} Mbps" -f $upMB, $sw2.Elapsed.TotalSeconds, $upSpeed) -Color Green

        # Gaming rating
        Write-Host ""
        $tier = 'UNKNOWN'; $col = 'DarkGray'
        if ($avg -lt 20 -and $speed -ge 100)      { $tier = 'EXCELENTE - listo para juegos competitivos';  $col = 'Green' }
        elseif ($avg -lt 40 -and $speed -ge 50)   { $tier = 'BUENO - online casual y coop';                  $col = 'Green' }
        elseif ($avg -lt 80 -and $speed -ge 25)   { $tier = 'ACEPTABLE - notable lag en FPS rapidos';        $col = 'Yellow' }
        else                                       { $tier = 'MALO - revisa tu red (cable > wifi)';           $col = 'Red' }
        Write-UI ("  Rating gaming   : " + $tier) -Color $col
    } catch {
        Write-UI ("  [!] " + $_.Exception.Message) -Color Red
    }
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
