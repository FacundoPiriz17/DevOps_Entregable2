[CmdletBinding()]
param([switch]$SkipInstall)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$reports = Join-Path $projectRoot 'reports'
$cache = Join-Path $projectRoot '.tmp/security-reports'
New-Item -ItemType Directory -Force $reports, $cache | Out-Null
Push-Location (Join-Path $projectRoot 'frontend')
try {
    if (-not $SkipInstall) {
        & npm.cmd ci
        if ($LASTEXITCODE -ne 0) { throw 'Fallo npm ci.' }
    }
    $metadata = @("Fecha UTC: $([DateTime]::UtcNow.ToString('o'))", "npm: $(& npm.cmd --version)", "Node: $(& node --version)", "Fuente: $(& git rev-parse HEAD) + cambios locales")
    foreach ($scope in @('all', 'production')) {
        $arguments = @('audit')
        $name = 'npm-audit.txt'
        if ($scope -eq 'production') { $arguments += '--omit=dev'; $name = 'npm-audit-produccion-post-mitigacion.txt' }
        $ErrorActionPreference = 'Continue'
        $output = & npm.cmd @arguments 2>&1
        $code = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        $output | ForEach-Object { "$_".TrimEnd() } | Set-Content (Join-Path $reports $name)
        $metadata += @("Comando: npm $($arguments -join ' ')", "Exit code: $code")
        if ($scope -eq 'all') {
            $auditCode = $code
        }
        if ($code -gt 1) { throw "No se pudo completar npm $($arguments -join ' ')." }
    }
    & npm.cmd audit --json | Set-Content (Join-Path $cache 'npm-audit.json')
    if ($LASTEXITCODE -gt 1) { throw 'Fallo npm audit --json.' }
    $metadata | Set-Content (Join-Path $cache 'npm-audit-metadata.txt')
} finally { Pop-Location }
Write-Host "Informes posteriores guardados en $reports; npm-audit.txt contiene el resultado actual."
exit $auditCode
