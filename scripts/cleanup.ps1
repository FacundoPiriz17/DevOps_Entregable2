[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Medium")]
param(
    [switch]$DeleteData,

    [switch]$RemoveImages,

    [string]$MinikubeProfile = "minikube"
)

$ErrorActionPreference = "Stop"

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

    & kubectl delete $Kind @Names -n $namespace --ignore-not-found=true --wait=true

    if ($LASTEXITCODE -ne 0) {
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

        if ($null -ne $existing) {
            Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
        }
    }

    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
}

Assert-Command -Name "kubectl"

$projectRoot = Split-Path -Parent $PSScriptRoot

$context = (& kubectl config current-context)

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($context)) {
    throw "No se pudo determinar el contexto actual de Kubernetes."
}

$namespace = (& kubectl config view --minify -o "jsonpath={..namespace}")

if ($LASTEXITCODE -ne 0) {
    throw "No se pudo determinar el namespace actual de Kubernetes."
}

if ([string]::IsNullOrWhiteSpace($namespace)) {
    $namespace = "default"
}

Write-Host "Contexto: $context"
Write-Host "Namespace: $namespace"
Write-Host "Solo se eliminaran recursos con nombres propios de PlayHub."

if ($DeleteData) {
    Write-Warning "-DeleteData eliminara playhub-postgres-data y todos los datos de PostgreSQL."
}
else {
    Write-Host "El PVC playhub-postgres-data se conservara. Usa -DeleteData para reiniciar tambien la base."
}

$target = "PlayHub en el contexto '$context', namespace '$namespace'"

if (-not $PSCmdlet.ShouldProcess($target, "Eliminar los recursos desplegados")) {
    return
}

Write-Host "Deteniendo port-forward de backend y frontend, si existen..."
Stop-TrackedPortForward -Name "backend" -ProjectRoot $projectRoot
Stop-TrackedPortForward -Name "frontend" -ProjectRoot $projectRoot

Invoke-KubectlDelete -Kind "deployment" -Names @(
    "playhub-backend-blue",
    "playhub-backend-green",
    "playhub-frontend-blue",
    "playhub-frontend-green",
    "playhub-postgres"
)

Invoke-KubectlDelete -Kind "job" -Names @("playhub-migrations")

Invoke-KubectlDelete -Kind "service" -Names @(
    "playhub-backend",
    "playhub-backend-blue",
    "playhub-backend-green",
    "playhub-frontend",
    "playhub-frontend-blue",
    "playhub-frontend-green",
    "playhub-db"
)

Invoke-KubectlDelete -Kind "configmap" -Names @(
    "playhub-config",
    "playhub-migration-sql"
)

Invoke-KubectlDelete -Kind "secret" -Names @("playhub-secrets")

$legacyImageCheckPods = @(
    & kubectl get pods -n $namespace -o name |
        Where-Object { $_ -like "pod/playhub-image-check-*" }
)

if ($LASTEXITCODE -ne 0) {
    throw "No se pudieron localizar los Pods temporales de comprobacion de imagenes."
}

if ($legacyImageCheckPods.Count -gt 0) {
    & kubectl delete @legacyImageCheckPods -n $namespace --ignore-not-found=true --wait=true
}
else {
    & kubectl delete pod -n $namespace -l "app=playhub-image-check" --ignore-not-found=true --wait=true
}

if ($LASTEXITCODE -ne 0) {
    throw "No se pudieron eliminar los Pods temporales de comprobacion de imagenes."
}

if ($DeleteData) {
    Invoke-KubectlDelete -Kind "pvc" -Names @("playhub-postgres-data")
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
            & minikube -p $MinikubeProfile image rm $image 2>$null
        }
    }
    else {
        Write-Warning "No se encontro minikube; no se limpio su cache de imagenes."
    }

    if (Get-Command docker -ErrorAction SilentlyContinue) {
        foreach ($image in $images) {
            & docker image rm $image 2>$null
        }
    }
    else {
        Write-Warning "No se encontro docker; no se eliminaron las imagenes locales."
    }
}

Write-Host "Limpieza de PlayHub terminada."

if (-not $DeleteData) {
    Write-Host "Se conservo persistentvolumeclaim/playhub-postgres-data."
}
