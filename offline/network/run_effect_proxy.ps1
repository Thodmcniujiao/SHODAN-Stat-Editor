# Optional, explicitly launched helper. Does not install a CA or alter proxies.
param([ValidateRange(1024,65535)][int]$Port = 8847)
$ErrorActionPreference = 'Stop'
$appFolder = Split-Path -Parent $PSScriptRoot
$portableRoot = if ((Split-Path -Leaf $appFolder) -eq 'app') { Split-Path -Parent $appFolder } else { $appFolder }
$plan = Join-Path $portableRoot 'Data/galactic_effect_overrides.json'
$assignments = Join-Path $portableRoot 'Data/planet_effects.json'
$certFolder = Join-Path $portableRoot 'Data/WarProxy'
if (-not (Test-Path -LiteralPath $plan -PathType Leaf) -and -not (Test-Path -LiteralPath $assignments -PathType Leaf)) { throw 'Save a planet assignment or effect definition in the editor first.' }
$runner = Join-Path $PSScriptRoot 'mitmdump.exe'
if (-not (Test-Path -LiteralPath $runner -PathType Leaf)) {
    $command = Get-Command mitmdump -ErrorAction SilentlyContinue
    if (-not $command) { throw 'Bundled proxy runtime is missing. Use the complete build.' }
    $runner = $command.Source
}
& $runner --listen-host 127.0.0.1 --listen-port $Port --mode regular --allow-hosts '^api\.live\.prod\.thehelldiversgame\.com(:443)?$' --set "confdir=$certFolder" --set "shodan_effect_definitions=$plan" --set "shodan_planet_effects=$assignments" --set flow_detail=0 -s (Join-Path $PSScriptRoot 'galactic_effect_proxy.py')
exit $LASTEXITCODE
