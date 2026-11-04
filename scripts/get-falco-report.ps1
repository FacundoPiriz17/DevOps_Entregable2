# Script para generar reportes de Falco.

$ProjectRoot = Split-Path -Parent $PSScriptRoot

$ReportDir = Join-Path $ProjectRoot "reports\falco"
New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null

$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

$EventsFile = Join-Path $ReportDir "falco-events-$Timestamp.log"
$ReportFile = Join-Path $ReportDir "falco-report-$Timestamp.txt"

Write-Host "Obteniendo eventos de Falco..."

$Logs = @(
    & kubectl logs -n falco `
        -l app.kubernetes.io/name=falco `
        -c falco `
        --prefix=true 2>&1
)

if ($LASTEXITCODE -ne 0) {
    Write-Error "No se pudieron conseguir los logs de Falco. Asegúrese de que el pod de Falco está corriendo."
    exit 1
}

$Logs | Set-Content -Path $EventsFile -Encoding UTF8

$AlertPattern = '^(?:\[pod/[^\]]+\]\s+)?\d{2}:\d{2}:\d{2}\.\d+:\s+(?:Emergency|Alert|Critical|Error|Warning|Notice|Informational|Debug)\b'

$Alerts = @(
    $Logs | Where-Object { "$_" -match $AlertPattern }
)

$PodShellEvents = @(
    $Alerts | Where-Object {
        "$_" -match 'A shell was spawned in a container with an attached terminal'
    }
)

$Report = @(
    "=============================================="
    "           PLAYHUB - REPORTE DE FALCO"
    "=============================================="
    ""
    "Reporte generado : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    "Kubernetes namespace: falco"
    "Falco pod selector: app.kubernetes.io/name=falco"
    ""
    "--------------- RESUMEN ---------------------"
    "Total de alertas de Falco: $($Alerts.Count)"
    "Total de shells interactivas en Pods: $($PodShellEvents.Count)"
    ""
    "--------------- ALERTAS ----------------------"
)

if ($Alerts.Count -gt 0) {
    $Report += $Alerts
} else {
    $Report += "No se encontraron alertas de Falco."
}

$Report += ""
$Report += "---------- SHELLS INTERACTIVAS EN PODS ----------"

if ($PodShellEvents.Count -gt 0) {
    $Report += $PodShellEvents
} else {
    $Report += "No se encontraron shells interactivas en Pods."
}

$Report += ""
$Report += "--------------- FIN DEL REPORTE ---------------"
$Report | Set-Content -Path $ReportFile -Encoding UTF8

Write-Host ""
Write-Host "Obtención de alertas de Falco terminada."
Write-Host "Eventos: $EventsFile"
Write-Host "Reporte: $ReportFile"
