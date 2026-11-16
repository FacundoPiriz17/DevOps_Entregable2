[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Medium")]
param(
    [switch]$DeleteData,

    [switch]$RemoveImages,

    [switch]$RemoveSecurity,

    [string]$MinikubeProfile = "minikube"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'lib/native.ps1')

function Assert-Command {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "No se encontro '$Name' en PATH."
    }
}

function Invoke-KubectlDelete {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Kind,

        [Parameter(Mandatory = $true)]
        [string[]]$Names
    )

    $result = Invoke-PlayHubNative -Command 'kubectl' -Arguments (@('delete', $Kind) + $Names + @('-n', $namespace, '--ignore-not-found=true', '--wait=true'))
    if ($result.Output) { Write-Host $result.Output }
    if ($result.ErrorOutput) { Write-Host $result.ErrorOutput }
    if ($result.ExitCode -ne 0) {
        throw "No se pudieron eliminar los recursos $Kind de PlayHub."
    }
}

function Stop-TrackedPortForward {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    $pidFile = Join-Path $ProjectRoot "logs\port-forward-$Name.pid"

    if (-not (Test-Path -LiteralPath $pidFile)) {
        return
    }

    $processId = Get-Content -LiteralPath $pidFile -ErrorAction SilentlyContinue

    if (-not [string]::IsNullOrWhiteSpace($processId)) {
        $existing = Get-Process -Id $processId -ErrorAction SilentlyContinue

        if ($null -ne $existing -and $existing.ProcessName -like '*kubectl*') {
            Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
        }
    }

    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
}

Assert-Command -Name "kubectl"

$projectRoot = Split-Path -Parent $PSScriptRoot

$result = Invoke-PlayHubNative -Command 'kubectl' -Arguments @('config', 'current-context')
$context = $result.Output

if ($result.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($context)) {
    throw "No se pudo determinar el contexto actual de Kubernetes."
}

$result = Invoke-PlayHubNative -Command 'kubectl' -Arguments @('config', 'view', '--minify', '-o', 'jsonpath={..namespace}')
$namespace = $result.Output

if ($result.ExitCode -ne 0) {
    throw "No se pudo determinar el namespace actual de Kubernetes."
}

if ([string]::IsNullOrWhiteSpace($namespace)) {
    $namespace = "default"
}

Write-Host "Contexto: $context"
Write-Host "Namespace: $namespace"
Write-Host "Solo se eliminaran recursos con nombres propios de PlayHub."

if ($DeleteData) {
    Write-Warning "-DeleteData eliminara los PVC y los datos de PostgreSQL, Prometheus y Grafana."
}
else {
    Write-Host "Los PVC de PostgreSQL, Prometheus y Grafana se conservaran. Usa -DeleteData para eliminarlos."
}

$target = "PlayHub en el contexto '$context', namespace '$namespace'"
if ($RemoveSecurity) { $target += '; incluye Kyverno, sus cuatro politicas y Falco instalados por PlayHub' }

if (-not $PSCmdlet.ShouldProcess($target, "Eliminar los recursos desplegados")) {
    return
}

Write-Host "Deteniendo port-forward de backend, frontend, Prometheus y Grafana, si existen..."
Stop-TrackedPortForward -Name "backend" -ProjectRoot $projectRoot
Stop-TrackedPortForward -Name "frontend" -ProjectRoot $projectRoot
Stop-TrackedPortForward -Name "prometheus" -ProjectRoot $projectRoot
Stop-TrackedPortForward -Name "grafana" -ProjectRoot $projectRoot

Invoke-KubectlDelete -Kind "deployment" -Names @(
    "playhub-backend-blue",
    "playhub-backend-green",
    "playhub-frontend-blue",
    "playhub-frontend-green",
    "playhub-postgres",
    "playhub-prometheus",
    "playhub-grafana",
    "playhub-kube-state-metrics",
    "playhub-blackbox-exporter"
)

Invoke-KubectlDelete -Kind "daemonset" -Names @("playhub-node-exporter", "playhub-cadvisor-network")

Invoke-KubectlDelete -Kind "job" -Names @("playhub-migrations")

Invoke-KubectlDelete -Kind "service" -Names @(
    "playhub-backend",
    "playhub-backend-blue",
    "playhub-backend-green",
    "playhub-frontend",
    "playhub-frontend-blue",
    "playhub-frontend-green",
    "playhub-db",
    "playhub-prometheus",
    "playhub-grafana",
    "playhub-blackbox-exporter"
)

Invoke-KubectlDelete -Kind "configmap" -Names @(
    "playhub-config",
    "playhub-migration-sql",
    "playhub-prometheus-config",
    "playhub-grafana-datasources",
    "playhub-grafana-dashboard-provider",
    "playhub-grafana-resource-dashboards",
    "playhub-grafana-alerts",
    "playhub-blackbox-config"
)

Invoke-KubectlDelete -Kind "rolebinding" -Names @("playhub-prometheus-discovery", "playhub-kube-state-metrics")
Invoke-KubectlDelete -Kind "role" -Names @("playhub-prometheus-discovery", "playhub-kube-state-metrics")
Invoke-KubectlDelete -Kind "serviceaccount" -Names @("playhub-prometheus", "playhub-kube-state-metrics", "playhub-cadvisor-network")
Invoke-KubectlDelete -Kind "clusterrolebinding" -Names @("playhub-prometheus-nodes")
Invoke-KubectlDelete -Kind "clusterrole" -Names @("playhub-prometheus-nodes")

Invoke-KubectlDelete -Kind "secret" -Names @("playhub-secrets")

$result = Invoke-PlayHubNative -Command 'kubectl' -Arguments @('get', 'pods', '-n', $namespace, '-o', 'name')
if ($result.ExitCode -ne 0) {
    throw "No se pudieron localizar los Pods temporales de comprobacion de imagenes."
}
$legacyImageCheckPods = @($result.Output -split "`r?`n" | Where-Object { $_ -like 'pod/playhub-image-check-*' })

if ($legacyImageCheckPods.Count -gt 0) {
    $result = Invoke-PlayHubNative -Command 'kubectl' -Arguments (@('delete') + $legacyImageCheckPods + @('-n', $namespace, '--ignore-not-found=true', '--wait=true'))
}
else {
    $result = Invoke-PlayHubNative -Command 'kubectl' -Arguments @('delete', 'pod', '-n', $namespace, '-l', 'app=playhub-image-check', '--ignore-not-found=true', '--wait=true')
}

if ($result.ExitCode -ne 0) {
    throw "No se pudieron eliminar los Pods temporales de comprobacion de imagenes."
}

if ($DeleteData) {
    Invoke-KubectlDelete -Kind "pvc" -Names @("playhub-postgres-data", "playhub-prometheus-data", "playhub-grafana-data")
}

if ($RemoveImages) {
    $images = @(
        "playhub-backend:v1.0",
        "playhub-backend:v2.0",
        "playhub-frontend:v1.0",
        "playhub-frontend:v2.0"
    )

    if (Get-Command minikube -ErrorAction SilentlyContinue) {
        foreach ($image in $images) {
            $result = Invoke-PlayHubNative -Command 'minikube' -Arguments @('-p', $MinikubeProfile, 'image', 'rm', $image)
            if ($result.ExitCode -ne 0) { Write-Warning "No se pudo retirar $image de Minikube (puede no existir)." }
        }
    }
    else {
        Write-Warning "No se encontro minikube; no se limpio su cache de imagenes."
    }

    if (Get-Command docker -ErrorAction SilentlyContinue) {
        foreach ($image in $images) {
            $result = Invoke-PlayHubNative -Command 'docker' -Arguments @('image', 'rm', $image)
            if ($result.ExitCode -ne 0) { Write-Warning "No se pudo retirar $image de Docker (puede no existir)." }
        }
    }
    else {
        Write-Warning "No se encontro docker; no se eliminaron las imagenes locales."
    }
}

if ($RemoveSecurity) {
    . (Join-Path $PSScriptRoot 'lib/security-stack.ps1')
    Remove-PlayHubSecurity -ProjectRoot $projectRoot
}
else {
    Write-Host 'Kyverno y Falco se conservan. -RemoveSecurity retira solo instalaciones registradas por PlayHub.'
}

Write-Host "Limpieza de PlayHub terminada."

if (-not $DeleteData) {
    Write-Host "Se conservaron los PVC de PostgreSQL, Prometheus y Grafana."
}
