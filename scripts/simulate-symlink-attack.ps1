[CmdletBinding()]
param([string]$Namespace = 'default', [string]$LabelSelector = 'app=playhub-backend')
$ErrorActionPreference = 'Stop'
& python (Join-Path $PSScriptRoot 'falco-symlink-evidence.py') attack --namespace $Namespace --selector $LabelSelector
if ($LASTEXITCODE -ne 0) { throw 'Fallo la prueba symlink de Falco.' }
