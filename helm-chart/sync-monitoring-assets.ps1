[CmdletBinding()]
param()

# Ejecutar desde la raiz: .\helm-chart\sync-monitoring-assets.ps1
# Compatible con Windows PowerShell 5.1. Helm solo empaqueta archivos dentro
# del chart: versionar las fuentes y sus copias files/ en el mismo cambio.
# Si se elimina una fuente, eliminar tambien su copia empaquetada.
# Validacion: helm lint ./helm-chart; helm template playhub ./helm-chart -n playhub-helm
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$manifestSource = Join-Path $projectRoot 'k8s/monitoring'
$dashboardSource = Join-Path $projectRoot 'monitoring/grafana/dashboards'
$manifestDestination = Join-Path $PSScriptRoot 'files/monitoring'
$dashboardDestination = Join-Path $PSScriptRoot 'files/grafana/dashboards'

New-Item -ItemType Directory -Force -Path $manifestDestination, $dashboardDestination | Out-Null

# Helm genera su ConfigMap de Grafana directamente desde los JSON empaquetados.
Get-ChildItem -LiteralPath $manifestSource -Filter '*.yaml' -File |
    Where-Object { $_.Name -ne 'grafana-config.yaml' } |
    ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $manifestDestination $_.Name) -Force
    }

Get-ChildItem -LiteralPath $dashboardSource -Filter '*.json' -File |
    ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dashboardDestination $_.Name) -Force
    }

Write-Host 'Assets de monitoring sincronizados. Versionar files/monitoring y files/grafana/dashboards junto a sus fuentes.'
