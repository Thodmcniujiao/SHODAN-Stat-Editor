# Steam launch-option wrapper. Only the child receives proxy environment values.
param(
    [int]$Port = 8847,
    [Parameter(Mandatory=$true,Position=0)][string]$GameExecutable,
    [Parameter(ValueFromRemainingArguments=$true)][string[]]$GameArguments
)
$ErrorActionPreference = 'Stop'
$appFolder = Split-Path -Parent $PSScriptRoot
$portableRoot = if ((Split-Path -Leaf $appFolder) -eq 'app') { Split-Path -Parent $appFolder } else { $appFolder }
$enabled = $false
foreach ($file in @('galactic_effect_overrides.json','planet_effects.json')) {
    $planPath = Join-Path $portableRoot ('Data/' + $file)
    if (Test-Path -LiteralPath $planPath -PathType Leaf) {
        try { $plan = Get-Content -LiteralPath $planPath -Raw -Encoding UTF8 | ConvertFrom-Json; if ($plan.version -eq 1 -and $plan.enabled -eq $true) { $enabled = $true } } catch { }
    }
}
# Quote for CreateProcessW, preserving embedded quotes and trailing backslashes.
function Quote-Argument([string]$Value) {
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
    $result = '"'; $slashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') { $slashes++; continue }
        if ($character -eq '"') { $result += ('\' * (2 * $slashes + 1)) + '"' }
        else { $result += ('\' * $slashes) + $character }
        $slashes = 0
    }
    return $result + ('\' * (2 * $slashes)) + '"'
}
$start = New-Object Diagnostics.ProcessStartInfo
$start.FileName = $GameExecutable
$start.Arguments = (@($GameArguments | ForEach-Object { Quote-Argument $_ }) -join ' ')
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
$start.WorkingDirectory = (Get-Location).Path
if ($enabled) {
    if ($Port -lt 1024 -or $Port -gt 65535) { throw 'Invalid effect proxy port.' }
    $client = New-Object Net.Sockets.TcpClient
    try {
        $connect = $client.ConnectAsync('127.0.0.1',$Port)
        if (-not $connect.Wait(1000) -or -not $client.Connected) { throw 'Start run_effect_proxy.ps1 before launching the game.' }
    } finally { $client.Dispose() }
    $address = 'http://127.0.0.1:' + $Port
    foreach ($key in @('HTTP_PROXY','HTTPS_PROXY','http_proxy','https_proxy')) { $start.EnvironmentVariables[$key] = $address }
    $bypass = @('localhost','127.0.0.1','::1','playfabapi.com','.playfabapi.com','playfab.com','.playfab.com','easyanticheat.net','.easyanticheat.net','easyanticheat.com','.easyanticheat.com','epicgames.com','.epicgames.com','epicgames.dev','.epicgames.dev')
    $existingBypass = $start.EnvironmentVariables['NO_PROXY']
    if ($existingBypass) { $bypass = @($existingBypass) + $bypass }
    $start.EnvironmentVariables['NO_PROXY'] = $bypass -join ','
    $start.EnvironmentVariables['no_proxy'] = $bypass -join ','
}
$child = [Diagnostics.Process]::Start($start)
$child.WaitForExit(); $result = $child.ExitCode; $child.Dispose()
exit $result
