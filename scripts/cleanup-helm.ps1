[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [ValidatePattern('^[a-z0-9][a-z0-9-]*$')][string]$Namespace = 'playhub-helm',
    [ValidatePattern('^[a-z0-9][a-z0-9-]*$')][string]$ReleaseName = 'playhub',
    [switch]$DeleteData,
    [switch]$DeleteNamespace,
    [switch]$RemoveImages,
    [switch]$RemoveSecurity,
    [string]$MinikubeProfile = 'minikube'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'lib/security-stack.ps1')
if ($DeleteNamespace -and $Namespace -in @('default', 'kube-system', 'kube-public', 'kube-node-lease', 'kyverno', 'falco')) {
    throw "No se elimina el namespace protegido $Namespace."
}
if ($DeleteNamespace -and -not $DeleteData) {
    throw '-DeleteNamespace requiere -DeleteData porque elimina todos los PVC del namespace.'
}
$context = Invoke-PlayHubNative -Command 'kubectl' -Arguments @('config', 'current-context')
if ($context.ExitCode -ne 0 -or -not $context.Output) { throw 'No se pudo determinar el contexto de Kubernetes.' }
$target = "release $ReleaseName en namespace $Namespace (contexto $($context.Output))"
if ($RemoveSecurity) { $target += '; incluye Kyverno, sus cuatro politicas y Falco registrados por PlayHub' }
if (-not $DeleteData) { Write-Host 'Se conservan los PVC y datos de PostgreSQL, Prometheus y Grafana.' }
if (-not $PSCmdlet.ShouldProcess($target, 'Retirar el despliegue de PlayHub')) { return }

$python = if ($env:PYTHON) { $env:PYTHON }
    elseif ($env:OS -eq 'Windows_NT' -and (Get-Command python -ErrorAction SilentlyContinue)) { 'python' }
    elseif (Get-Command python3 -ErrorAction SilentlyContinue) { 'python3' }
    else { 'python' }
$cleanupArgs = @((Join-Path $PSScriptRoot 'lib/helm-cleanup.py'), '--namespace', $Namespace, '--release-name', $ReleaseName)
if ($DeleteData) { $cleanupArgs += '--delete-data' }
if ($DeleteNamespace) { $cleanupArgs += '--delete-namespace' }
$result = Invoke-PlayHubNative -Command $python -Arguments $cleanupArgs
if ($result.Output) { Write-Host $result.Output }
if ($result.ErrorOutput) { Write-Host $result.ErrorOutput }
if ($result.ExitCode -ne 0) { throw 'No se pudo retirar el release; revisar el diagnostico anterior.' }

foreach ($name in @('backend', 'frontend', 'prometheus', 'grafana')) {
    $pidFile = Join-Path $projectRoot "logs/helm-port-forward-$name.pid"
    if (Test-Path -LiteralPath $pidFile) {
        $processId = Get-Content -LiteralPath $pidFile -ErrorAction SilentlyContinue
        if ($processId -match '^\d+$') {
            $existing = Get-Process -Id $processId -ErrorAction SilentlyContinue
            if ($existing -and $existing.ProcessName -like '*kubectl*') {
                Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
            }
        }
        Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
    }
}
if ($RemoveImages) {
    foreach ($image in @('playhub-backend:v1.0', 'playhub-frontend:v1.0', 'playhub-frontend:v1.0-prod')) {
        if (Get-Command minikube -ErrorAction SilentlyContinue) {
            $result = Invoke-PlayHubNative -Command 'minikube' -Arguments @('-p', $MinikubeProfile, 'image', 'rm', $image)
            if ($result.ExitCode -ne 0) { Write-Warning "No se pudo retirar $image de Minikube (puede no existir)." }
        }
        if (Get-Command docker -ErrorAction SilentlyContinue) {
            $result = Invoke-PlayHubNative -Command 'docker' -Arguments @('image', 'rm', $image)
            if ($result.ExitCode -ne 0) { Write-Warning "No se pudo retirar $image de Docker (puede no existir)." }
        }
    }
}
if ($RemoveSecurity) { Remove-PlayHubSecurity -ProjectRoot $projectRoot }
else { Write-Host 'Kyverno y Falco se conservan; -RemoveSecurity retira las instalaciones de PlayHub.' }
Write-Host 'Limpieza de PlayHub terminada.'
