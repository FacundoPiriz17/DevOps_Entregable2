
$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ValuesFile = Join-Path $ProjectRoot "security\falco\values.yaml"

$ReleaseName = "falco"
$Namespace = "falco"
$Chart = "falcosecurity/falco"
$ChartVersion = "9.2.2"

Write-Host "========================================"
Write-Host "     PLAYHUB - DEPLOYMENT DE FALCO"
Write-Host "========================================"

foreach ($Command in @("helm", "kubectl")) {
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw "$Command no se encontró en el PATH."
    }
}

if (-not (Test-Path $ValuesFile)) {
    throw "No se encontró el values file de Falco: $ValuesFile"
}

Write-Host "`nVerificando el cluster de Kubernetes..."

kubectl get nodes

if ($LASTEXITCODE -ne 0) {
    throw "No se ha podido conectar con Kubernetes."
}

Write-Host "`nActualizando el repositorio de Helm con Falco..."

helm repo add falcosecurity https://falcosecurity.github.io/charts --force-update

if ($LASTEXITCODE -ne 0) {
    throw "No se ha podido añadir a Falco al repositorio."
}

helm repo update

if ($LASTEXITCODE -ne 0) {
    throw "No se han podido actualizar los repositorios de Helm."
}

Write-Host "`nInstalando/actualizando Falco..."

helm upgrade --install $ReleaseName $Chart `
    --version $ChartVersion `
    --namespace $Namespace `
    --create-namespace `
    --values $ValuesFile `
    --wait `
    --timeout 5m

if ($LASTEXITCODE -ne 0) {
    throw "El deployment ha fallado."
}

Write-Host "`nEsperando Falco DaemonSet..."

kubectl rollout status daemonset/falco -n $Namespace --timeout=180s

if ($LASTEXITCODE -ne 0) {
    throw "Falco DaemonSet no está listo."
}

Write-Host "`nFalco pods:"
kubectl get pods -n $Namespace -o wide

Write-Host "`nFalco DaemonSet:"
kubectl get daemonset -n $Namespace

Write-Host "`nFalco deployment completado exitosamente."