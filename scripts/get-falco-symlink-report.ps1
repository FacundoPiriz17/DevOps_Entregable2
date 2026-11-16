[CmdletBinding()]
param([ValidateRange(0,60)][int]$WaitSeconds = 30)
$ErrorActionPreference = 'Stop'
& python (Join-Path $PSScriptRoot 'falco-symlink-evidence.py') report --wait-seconds $WaitSeconds
if ($LASTEXITCODE -ne 0) { throw 'Falco no verifico el evento symlink. Ver reports/falco/.' }
