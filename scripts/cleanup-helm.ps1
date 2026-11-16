[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Medium")]
param(
    [string]$Namespace = "playhub-helm",

    [string]$ReleaseName = "playhub",

    [switch]$DeleteNamespace,

    [switch]$RemoveImages,

    [string]$MinikubeProfile = "minikube"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot

function Assert-Command {
    param([Parameter(Mandatory = $true)][string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "No se encontro '$Name' en PATH."
    }
}

function Stop-HelmPortForward {
    foreach ($name in @("backend", "frontend")) {
        $pidFile = Join-Path $projectRoot "logs\helm-port-forward-$name.pid"
        if (Test-Path -LiteralPath $pidFile) {
            $processId = Get-Content -LiteralPath $pidFile -ErrorAction SilentlyContinue
            if (-not [string]::IsNullOrWhiteSpace($processId)) {
                $existing = Get-Process -Id $processId -ErrorAction SilentlyContinue
                if ($null -ne $existing) { Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue }
            }
            Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
        }
    }
}

Assert-Command -Name "helm"
Assert-Command -Name "kubectl"

$context = (& kubectl config current-context)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($context)) {
    throw "No se pudo determinar el contexto actual de Kubernetes."
}

Write-Host "Contexto: $context"
Write-Host "Namespace: $Namespace"
Write-Host "Release: $ReleaseName"
Write-Host "Solo se elimina el release de Helm; el despliegue de deploy.ps1 (namespace default) no se toca."
Write-Warning "Se eliminaran tambien el PVC y los datos de PostgreSQL del release."

$target = "release '$ReleaseName' en el namespace '$Namespace' (contexto '$context')"
if (-not $PSCmdlet.ShouldProcess($target, "Desinstalar con Helm")) {
    return
}

Write-Host "Deteniendo los port-forward de Helm, si existen..."
Stop-HelmPortForward

$found = (& helm list -n $Namespace --short --filter "^${ReleaseName}$")
if ($LASTEXITCODE -ne 0) {
    throw "No se pudo consultar la lista de releases en el namespace '$Namespace'."
}

if ([string]::IsNullOrWhiteSpace(($found -join "").Trim())) {
    Write-Host "No hay un release '$ReleaseName' en el namespace '$Namespace'. Nada que desinstalar."
}
else {
    & helm uninstall $ReleaseName -n $Namespace
    if ($LASTEXITCODE -ne 0) {
        throw "Fallo helm uninstall $ReleaseName -n $Namespace"
    }
}

if ($DeleteNamespace) {
    Write-Host "Eliminando el namespace '$Namespace'..."
    & kubectl delete namespace $Namespace --ignore-not-found=true
    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo eliminar el namespace '$Namespace'."
    }
}

if ($RemoveImages) {
    $images = @("playhub-backend:v1.0", "playhub-frontend:v1.0", "playhub-frontend:v1.0-prod")

    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        if (Get-Command minikube -ErrorAction SilentlyContinue) {
            foreach ($image in $images) {
                Write-Host "Eliminando $image de Minikube..."
                & minikube -p $MinikubeProfile image rm $image
            }
        }
        else {
            Write-Warning "No se encontro minikube en PATH: se omiten las imagenes del cluster."
        }

        if (Get-Command docker -ErrorAction SilentlyContinue) {
            foreach ($image in $images) {
                Write-Host "Eliminando $image de Docker..."
                & docker image rm $image
            }
        }
        else {
            Write-Warning "No se encontro docker en PATH: se omiten las imagenes locales."
        }
    }
    finally {
        $ErrorActionPreference = $previous
    }
}

Write-Host ""
Write-Host "Limpieza terminada. Para comprobarlo:"
Write-Host "  helm list -n $Namespace"
Write-Host "  kubectl get all -n $Namespace"
