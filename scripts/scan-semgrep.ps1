[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$image = 'semgrep/semgrep:1.182.1'
$results = Join-Path $projectRoot '.tmp/security-reports'
New-Item -ItemType Directory -Force $results | Out-Null
$cache = Join-Path $projectRoot '.tmp/security-scan'
New-Item -ItemType Directory -Force $cache | Out-Null
$files = @(& git -C $projectRoot ls-files --cached --others --exclude-standard backend/src frontend db)
if ($LASTEXITCODE -ne 0) { throw 'No se pudieron enumerar las fuentes.' }
# Extraer el snapshot dentro del contenedor evita recorrer node_modules sobre
# un bind mount de Docker Desktop. Incluye los bytes de los cambios locales.
$files | Set-Content (Join-Path $cache 'files.txt') -Encoding ascii
Push-Location $projectRoot
try { & tar -cf (Join-Path $cache 'source.tar') -T (Join-Path $cache 'files.txt') }
finally { Pop-Location }
if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear el snapshot.' }
$sourceHash = (Get-FileHash (Join-Path $cache 'source.tar') -Algorithm SHA256).Hash
@($files | ForEach-Object { @{ path = $_; sha256 = (Get-FileHash (Join-Path $projectRoot $_) -Algorithm SHA256).Hash } }) | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $results 'semgrep-source-manifest.json')
foreach ($scope in @('code', 'kubernetes')) {
    # Conjuntos oficiales para los lenguajes usados y los datos de demostracion.
    $rules = if ($scope -eq 'code') { @('/rules/java.yaml', '/rules/javascript.yaml', '/rules/secrets.yaml') } else { @('/rules/kubernetes.yaml') }
    $targets = if ($scope -eq 'code') { @('backend/src', 'frontend', 'db') } else { @('k8s', 'scripts/flyway-repair.yaml') }
    if ($scope -eq 'kubernetes') {
        $files = @(& git -C $projectRoot ls-files k8s scripts/flyway-repair.yaml)
        $files | Set-Content (Join-Path $cache 'files.txt') -Encoding ascii
        Push-Location $projectRoot
        try { & tar -cf (Join-Path $cache 'source.tar') -T (Join-Path $cache 'files.txt') }
        finally { Pop-Location }
        if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear el snapshot de Kubernetes.' }
        $sourceHash = (Get-FileHash (Join-Path $cache 'source.tar') -Algorithm SHA256).Hash
    }
    $scanArgs = @('run', '--rm', '--mount', "type=bind,source=$cache,target=/input,readonly", '--mount', "type=bind,source=$results,target=/results", '--mount', "type=bind,source=$projectRoot/security/semgrep/rules,target=/rules,readonly", '--entrypoint', 'sh', $image,
        '-c', 'mkdir -p /src && tar -xf /input/source.tar -C /src && cd /src && exec semgrep "$@"', 'sh',
        'scan', '--oss-only', '--jobs=2', '--timeout=15', '--metrics=off', '--disable-version-check', '--exclude', 'node_modules', '--exclude', '.next', '--exclude', 'target',
        '--json-output', "/results/semgrep-$scope.json")
    foreach ($rule in $rules) { $scanArgs += @('--config', $rule) }
    $scanArgs += $targets
    $output = & docker @scanArgs 2>&1
    $code = $LASTEXITCODE
    $native = @($output | ForEach-Object { "$_".TrimEnd() })
    $name = if ($scope -eq 'code') { 'semgrep_scan-post-mitigacion.txt' } else { 'semgrep-kubernetes-post-mitigacion.txt' }
    if ($scope -eq 'kubernetes') {
        $native = @('Analisis Semgrep de manifiestos Kubernetes', "Fecha UTC: $([DateTime]::UtcNow.ToString('o'))", "Comando: docker $($scanArgs -join ' ')", '') + $native + "Exit code: $code"
    }
    $native | Set-Content (Join-Path $projectRoot "reports/$name")
    @("Fecha UTC: $([DateTime]::UtcNow.ToString('o'))", "Herramienta: $image", "SHA256 del snapshot: $sourceHash", "Comando: docker $($scanArgs -join ' ')", "Exit code: $code") | Set-Content (Join-Path $results "semgrep-$scope-metadata.txt")
    if ($code -ne 0) { throw "Fallo el analisis Semgrep: $scope (ver reporte)." }
}
