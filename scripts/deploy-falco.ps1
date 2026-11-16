[CmdletBinding()]
param([switch]$AdoptExisting)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'lib/security-stack.ps1')
$arguments = @('install-falco')
if ($AdoptExisting) { $arguments += '--adopt-existing' }
Invoke-PlayHubSecurity -ProjectRoot $projectRoot -Arguments $arguments
