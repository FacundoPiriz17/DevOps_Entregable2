[CmdletBinding()]
# Ultima version estable verificada el 2026-11-02.
param([string]$Version = '1.19.2')

$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Version debe ser X.Y.Z.' }
$projectRoot = Split-Path -Parent $PSScriptRoot
$cache = Join-Path $projectRoot '.tmp/security-tools'
New-Item -ItemType Directory -Force $cache | Out-Null
$manifest = Join-Path $cache "kyverno-install-v$Version.yaml"
$url = "https://github.com/kyverno/kyverno/releases/download/v$Version/install.yaml"
Write-Host "Contexto destino: $(& kubectl config current-context)"
if ($LASTEXITCODE -ne 0) { throw 'No se pudo consultar el contexto de kubectl.' }
$existing = & kubectl -n kyverno get deployment kyverno-admission-controller --ignore-not-found -o json
if ($LASTEXITCODE -ne 0) { throw 'No se pudo consultar la instalacion de Kyverno.' }
if ($existing) {
    $installedImage = ($existing | ConvertFrom-Json).spec.template.spec.containers[0].image
    if ($installedImage -notmatch ":v$([regex]::Escape($Version))$") {
        throw "Kyverno ya esta instalado con $installedImage. La actualizacion con YAML requiere reinstalacion; seguir kyverno.md antes de ejecutar este instalador."
    }
}
Invoke-WebRequest -UseBasicParsing $url -OutFile $manifest
# Server-side apply evita el limite de annotations de los CRD grandes.
& kubectl apply --server-side -f $manifest
if ($LASTEXITCODE -ne 0) { throw 'Fallo la instalacion de Kyverno.' }
foreach ($controller in @('admission', 'background', 'cleanup', 'reports')) {
    & kubectl -n kyverno rollout status "deployment/kyverno-$controller-controller" --timeout=300s
    if ($LASTEXITCODE -ne 0) { throw "Kyverno $controller no esta disponible." }
}
& kubectl apply -f (Join-Path $projectRoot 'k8s/kyverno')
if ($LASTEXITCODE -ne 0) { throw 'Fallo la aplicacion de las politicas.' }
foreach ($policy in @('disallow-latest', 'require-resources', 'disallow-root')) {
    & kubectl wait --for=condition=Ready "clusterpolicy/$policy" --timeout=120s
    if ($LASTEXITCODE -ne 0) { throw "La politica $policy no esta lista." }
}
