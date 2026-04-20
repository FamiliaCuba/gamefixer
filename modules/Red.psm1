# ============================================================================
#  modules/Red.psm1
#  Diagnostico y optimizacion de red
# ============================================================================

function Invoke-RedMenu {
    Show-Section "MODULO RED"

    Write-UI "  [1] Test de latencia (ping a DNS populares)" -Color Yellow
    Write-UI "  [2] Flush DNS + reset Winsock + TCP/IP" -Color Yellow
    Write-UI "  [3] Cambiar DNS a Cloudflare (1.1.1.1)" -Color Yellow
    Write-UI "  [4] Cambiar DNS a Google (8.8.8.8)" -Color Yellow
    Write-UI "  [5] Restaurar DNS automatico (DHCP)" -Color Yellow
    Write-UI "  [6] Test de velocidad (descarga 10MB)" -Color Yellow
    Write-UI "  [7] Ver conexiones activas (netstat)" -Color Yellow
    Write-UI "  [B] Volver" -Color Yellow
    Write-Host ""
    Write-UI "  > " -Color Cyan -NoNewline
    $sub = (Read-Host).Trim().ToUpper()

    switch ($sub) {
        '1' { Test-Latency }
        '2' { Reset-Network }
        '3' { Set-DNSCloudflare }
        '4' { Set-DNSGoogle }
        '5' { Reset-DNS }
        '6' { Test-Speed }
        '7' { Show-Connections }
        default { return }
    }
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
    Write-UI "Test de descarga (10MB desde Cloudflare)..." -Color Cyan
    try {
        $url = 'https://speed.cloudflare.com/__down?bytes=10000000'
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $tmp = [System.IO.Path]::GetTempFileName()
        Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
        $sw.Stop()
        $sizeMB = (Get-Item $tmp).Length / 1MB
        $speed = $sizeMB * 8 / ($sw.Elapsed.TotalSeconds)
        Remove-Item $tmp -Force
        Write-UI ("  Descargado: {0:N2} MB en {1:N1}s" -f $sizeMB, $sw.Elapsed.TotalSeconds) -Color Green
        Write-UI ("  Velocidad : {0:N1} Mbps" -f $speed) -Color Green
        Write-Log -Level INFO -Message "Speed test: $speed Mbps"
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
