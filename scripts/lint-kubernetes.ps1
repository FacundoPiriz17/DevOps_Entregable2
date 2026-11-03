[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$report = Join-Path $projectRoot 'reports/kubelinter.txt'
New-Item -ItemType Directory -Force (Split-Path -Parent $report) | Out-Null
# Ultima version estable verificada el 2026-11-02; se fija para repetir el analisis.
$image = 'stackrox/kube-linter:v0.8.3'
$arguments = @('run', '--rm', '--mount', "type=bind,source=$projectRoot,target=/work,readonly",
    '--workdir', '/work', $image, 'lint', 'k8s', 'scripts/flyway-repair.yaml')
# Se conservan todos los checks predeterminados y los hallazgos sin filtros.
# Continue permite capturar stderr tambien en Windows PowerShell 5.1.
$ErrorActionPreference = 'Continue'
$output = & docker @arguments 2>&1
$code = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
@(
    'Analisis estatico de manifiestos Kubernetes'
    "Fecha UTC: $([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
    "Herramienta: $image"
    'Comando: kube-linter lint k8s scripts/flyway-repair.yaml'
    'Alcance: manifiestos de despliegue, monitoreo y politicas; tests/kyverno contiene fixtures intencionalmente invalidos y se analiza por separado con Kyverno.'
    'Configuracion: checks predeterminados, sin exclusiones ni supresiones.'
    ''
    ($output | ForEach-Object { "$_" })
    ''
    "Exit code: $code"
) | Set-Content -LiteralPath $report -Encoding UTF8
Write-Host "Informe guardado en $report"
Write-Output $output
exit $code
