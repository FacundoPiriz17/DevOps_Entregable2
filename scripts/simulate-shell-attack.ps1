[CmdletBinding()]
param([string]$Namespace = 'default', [string]$LabelSelector = 'app=playhub-backend', [ValidateRange(0,60)][int]$Seconds = 0)
$ErrorActionPreference = 'Stop'
& python (Join-Path $PSScriptRoot 'falco-evidence.py') attack --namespace $Namespace --selector $LabelSelector --seconds $Seconds
if ($LASTEXITCODE -ne 0) { throw 'Fallo la prueba de shell. Debe ejecutarse desde una terminal con TTY.' }
