[CmdletBinding()]
param([ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version = '1.19.2', [switch]$AdoptExisting)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'lib/security-stack.ps1')
$arguments = @('install-kyverno', '--version', $Version)
if ($AdoptExisting) { $arguments += '--adopt-existing' }
Invoke-PlayHubSecurity -ProjectRoot $projectRoot -Arguments $arguments
