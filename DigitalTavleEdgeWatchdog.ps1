# Watchdog script for DigitalTavle machines
# Runs in Multi App Kiosk mode with Edge in foreground
# Relaunches Edge if its window disappears or navigates outside the allowed domain
# 2025-10-22 - Tommy Benum, D-IKT / Copilot / Jonas Kosmo / Chatgpt 5 pro

$gracePeriodSeconds = 1
$checkIntervalSeconds = 3
$edgeProcessName = "msedge"
$targetUrl = "https://bodo.dnvimatis.cloud"
$allowedHost = "bodo.dnvimatis.cloud"
$allowedScheme = "https"
$remoteDebuggingPort = 9222
$userDataDir = "C:\ProgramData\DigitalTavle\EdgeKioskProfile"

Add-Type -AssemblyName UIAutomationClient

function Is-EdgeWindowOpen {
    try {
        $procs = Get-Process -Name $edgeProcessName -ErrorAction SilentlyContinue
        if (-not $procs) { return $false }
        foreach ($p in $procs) {
            if ($p.MainWindowHandle -ne 0) { return $true }
        }
        return $false
    } catch {
        return $false
    }
}

function Start-EdgeInstance {
    try {
        if (-not (Test-Path -Path $userDataDir)) {
            New-Item -Path $userDataDir -ItemType Directory -Force | Out-Null
        }

        $arguments = @(
    "--app=$targetUrl"
    "--start-fullscreen"
    "--remote-debugging-port=$remoteDebuggingPort"
    "--no-first-run"
    "--new-window"
)

        Start-Process $edgeProcessName -ArgumentList $arguments -ErrorAction SilentlyContinue
    } catch {
        Start-Sleep -Seconds 2
    }
}

function Get-EdgeUrls {
    try {
        $uri = "http://127.0.0.1:{0}/json/list" -f $remoteDebuggingPort
        $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 2
        if (-not $response.Content) { return @() }
        return ($response.Content | ConvertFrom-Json | Where-Object { $_.type -eq "page" }) | ForEach-Object { $_.url }
    } catch {
        return @()
    }
}

function Is-AllowedUrl {
    param([string]$Url)

    try {
        $uri = [Uri]$Url
        if ($uri.Scheme -ne $allowedScheme) { return $false }
        if (-not $uri.Host.Equals($allowedHost, [System.StringComparison]::OrdinalIgnoreCase)) { return $false }
        return $true
    } catch {
        return $false
    }
}

Start-Sleep -Seconds $gracePeriodSeconds

while ($true) {
    if (-not (Is-EdgeWindowOpen)) {
        Start-EdgeInstance
        Start-Sleep -Seconds 5
        continue
    }

    $urls = Get-EdgeUrls
    if ($urls.Count -gt 0) {
        $unauthorizedUrl = $urls | Where-Object { -not (Is-AllowedUrl $_) } | Select-Object -First 1
    
        if ($unauthorizedUrl) {
            Start-Sleep -Seconds 10
            $urls = Get-EdgeUrls
            $unauthorizedUrl = $urls | Where-Object { -not (Is-AllowedUrl $_)} | Select-Object -First 1
            if(-not $unauthorizedUrl) {continue}
            Stop-Process -Name $edgeProcessName -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 20
            Start-EdgeInstance
            Start-Sleep -Seconds $gracePeriodSeconds
            continue
        }
    }

    Start-Sleep -Seconds $checkIntervalSeconds
}
