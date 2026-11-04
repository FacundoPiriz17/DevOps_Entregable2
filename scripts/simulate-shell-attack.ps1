$ErrorActionPreference = "Stop"

$Namespace = "default"
$LabelSelector = "app=playhub-backend"

Write-Host "PLAYHUB - SIMULACION DE ATAQUE POR SHELL"

$Pod = kubectl get pods -n $Namespace `
    -l $LabelSelector `
    --field-selector=status.phase=Running `
    -o jsonpath='{.items[0].metadata.name}'

if ($LASTEXITCODE -ne 0 -or -not $Pod) {
    throw "No se encontro ningun Pod de PlayHub corriendo."
}

$Container = kubectl get pod $Pod -n $Namespace `
    -o jsonpath='{.spec.containers[0].name}'

if ($LASTEXITCODE -ne 0 -or -not $Container) {
    throw "No se pudo identificar el contenedor."
}

Write-Host "Target Pod: $Pod"
Write-Host "Container: $Container"
Write-Host "Abriendo shell interactiva..."

kubectl exec -it -n $Namespace $Pod `
    -c $Container -- sh -c 'if command -v bash >/dev/null 2>&1; then exec bash -i; else exec sh; fi'

if ($LASTEXITCODE -ne 0) {
    throw "La simulacion fallo."
}

Write-Host "Simulacion completada."
