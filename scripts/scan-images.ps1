[CmdletBinding()]
param([string]$TrivyVersion = '0.75.0')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$reports = Join-Path $projectRoot 'reports'
$cache = Join-Path $projectRoot '.tmp/security-reports'
New-Item -ItemType Directory -Force $reports, $cache | Out-Null
$tool = "aquasec/trivy:$TrivyVersion"
$metadata = @("Fecha UTC: $([DateTime]::UtcNow.ToString('o'))", "Herramienta: $tool", "Fuente: $(& git -C $projectRoot rev-parse HEAD) + cambios locales")
$tables = @()
foreach ($component in @('frontend', 'backend')) {
    $image = "playhub-${component}:v1.0"
    $identity = & docker image inspect $image --format '{{.Id}}'
    if ($LASTEXITCODE -ne 0) { throw "Imagen ausente: $image" }
    $equivalent = & docker image inspect "playhub-${component}:v2.0" --format '{{.Id}}'
    if ($LASTEXITCODE -ne 0 -or $identity -ne $equivalent) { throw "Blue y Green no representan la misma imagen de $component." }
    $common = @('run', '--rm', '--mount', 'type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock',
        '--mount', "type=bind,source=$reports,target=/reports", '--mount', "type=bind,source=$cache,target=/results",
        '--mount', 'type=volume,source=playhub-trivy-cache,target=/root/.cache/trivy', $tool, 'image', '--timeout', '30m',
        '--no-progress', '--skip-version-check', '--image-src', 'docker', '--scanners', 'vuln,secret')
    $name = "trivyreports_${component}-post-mitigacion.txt"
    foreach ($format in @('json', 'table')) {
        $destination = if ($format -eq 'json') { "/results/trivy-$component.json" } else { "/reports/$name" }
        $scanArgs = $common + @('--format', $format, '--output', $destination, $image)
        $ErrorActionPreference = 'Continue'
        $output = & docker @scanArgs 2>&1
        $code = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        $metadata += @("Imagen: $image; tag equivalente: playhub-${component}:v2.0; ID: $identity", "Comando: docker $($scanArgs -join ' ')", $output, "Exit code: $code")
        if ($code -ne 0) { $metadata | Set-Content (Join-Path $cache 'trivy-metadata.txt'); throw "Fallo Trivy para $image ($format)." }
    }
    $after = & docker image inspect $image --format '{{.Id}}'
    if ($LASTEXITCODE -ne 0 -or $after -ne $identity) { throw 'Cambio de imagen durante el escaneo.' }
    $tables += (Get-Content (Join-Path $reports $name) -Raw).TrimEnd()
}
($tables -join "`n`n") + "`n" | Set-Content (Join-Path $reports 'trivyreport.txt') -NoNewline
$metadata | Set-Content (Join-Path $cache 'trivy-metadata.txt')
Write-Host 'Informes Trivy posteriores en tablas nativas; consolidado: reports/trivyreport.txt'
