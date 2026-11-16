. (Join-Path $PSScriptRoot 'native.ps1')

function Invoke-PlayHubSecurity {
    param([string]$ProjectRoot, [string[]]$Arguments)
    $python = if ($env:PYTHON) { $env:PYTHON }
        elseif ($env:OS -eq 'Windows_NT' -and (Get-Command python -ErrorAction SilentlyContinue)) { 'python' }
        elseif (Get-Command python3 -ErrorAction SilentlyContinue) { 'python3' }
        else { 'python' }
    $result = Invoke-PlayHubNative -Command $python -Arguments (@(
        (Join-Path $ProjectRoot 'scripts/lib/security-stack.py'), '--project-root', $ProjectRoot
    ) + $Arguments)
    if ($result.Output) { Write-Host $result.Output }
    if ($result.ErrorOutput) { Write-Host $result.ErrorOutput }
    if ($result.ExitCode -ne 0) { throw 'Fallo la gestion de Kyverno/Falco. Revisar el diagnostico anterior.' }
}

function Initialize-PlayHubSecurity {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot, [switch]$AdoptExisting)
    $arguments = @('install')
    if ($AdoptExisting) { $arguments += '--adopt-existing' }
    Invoke-PlayHubSecurity -ProjectRoot $ProjectRoot -Arguments $arguments
}

function Remove-PlayHubSecurity {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot, [switch]$DryRun)
    $arguments = @('remove')
    if ($DryRun) { $arguments += '--dry-run' }
    Invoke-PlayHubSecurity -ProjectRoot $ProjectRoot -Arguments $arguments
}
