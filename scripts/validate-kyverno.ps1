[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$report = Join-Path $projectRoot 'reports/kyverno-validation-post-mitigacion.txt'
$lines = New-Object 'System.Collections.Generic.List[string]'
$namespace = 'kyverno-validation'
$fixture = Join-Path $projectRoot 'tests/kyverno/valid-pod.yaml'
$invalidFixture = Join-Path $projectRoot 'tests/kyverno/invalid-pod.yaml'
$createdPod = $false
$passed = 0

function Invoke-KubeCapture {
    param([string[]]$Arguments, [string]$InputJson, [switch]$SummarizeJson)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if ($InputJson) { $output = $InputJson | & kubectl @Arguments 2>&1 }
        else { $output = & kubectl @Arguments 2>&1 }
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previous }
    $text = ($output | ForEach-Object { "$_" }) -join "`n"
    $text = [regex]::Replace($text, '(?m)[ \t]+\r?$', '')
    $lines.Add("kubectl $($Arguments -join ' ')")
    if ($SummarizeJson -and $code -eq 0) {
        $lines.Add('JSON leido para extraer el Pod template; se omite su contenido para mantener la evidencia legible.')
    } else { $lines.Add($text) }
    $lines.Add("Exit code: $code")
    return @{ Text = $text; Code = $code }
}

function Assert-Allowed {
    param([string]$Name, [hashtable]$Result)
    if ($Result.Code -ne 0) { throw "$Name debia ser aceptado: $($Result.Text)" }
    $lines.Add("PASS: $Name aceptado.")
    $script:passed++
}

function Assert-Denied {
    param([string]$Name, [hashtable]$Result, [string[]]$Policies)
    if ($Result.Code -eq 0) { throw "$Name fue aceptado inesperadamente." }
    if ($Result.Text -notmatch 'admission webhook.*denied the request') {
        throw "$Name fallo por una causa distinta del rechazo de admision: $($Result.Text)"
    }
    foreach ($policy in $Policies) {
        if ($Result.Text -notmatch "(?m)^\s*$([regex]::Escape($policy)):") {
            throw "$Name no fue rechazado por $policy : $($Result.Text)"
        }
    }
    $lines.Add("PASS: $Name rechazado por $($Policies -join ', ').")
    $script:passed++
}

function Test-Pod {
    param([string]$Name, [scriptblock]$Mutate, [string[]]$Policies)
    $pod = $script:baseline | ConvertFrom-Json
    $pod.metadata.name = "kyverno-$Name"
    & $Mutate $pod
    $json = $pod | ConvertTo-Json -Depth 30
    $result = Invoke-KubeCapture @('create', '--dry-run=server', '-f', '-') $json
    if ($Policies.Count) { Assert-Denied $Name $result $Policies }
    else { Assert-Allowed $Name $result }
}

New-Item -ItemType Directory -Force (Split-Path -Parent $report) | Out-Null
$lines.Add('Validacion de admision Kyverno')
$lines.Add("Fecha UTC: $([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))")
$exitCode = 0
try {
    $context = Invoke-KubeCapture @('config', 'current-context')
    if ($context.Code -ne 0) { throw $context.Text }
    $versions = Invoke-KubeCapture @('get', 'deployments', '-n', 'kyverno', '-o', 'custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image')
    if ($versions.Code -ne 0) { throw $versions.Text }
    foreach ($policy in @('disallow-latest', 'require-resources', 'disallow-root')) {
        $ready = Invoke-KubeCapture @('wait', '--for=condition=Ready', "clusterpolicy/$policy", '--timeout=120s')
        if ($ready.Code -ne 0) { throw $ready.Text }
    }
    $ns = Invoke-KubeCapture @('get', 'namespace', $namespace, '--ignore-not-found', '-o', 'name')
    if ($ns.Code -ne 0) { throw $ns.Text }
    if (-not $ns.Text.Trim()) {
        $ns = Invoke-KubeCapture @('create', 'namespace', $namespace)
        if ($ns.Code -ne 0) { throw $ns.Text }
    }
    $base = Invoke-KubeCapture @('create', '--dry-run=client', '-f', $fixture, '-o', 'json')
    if ($base.Code -ne 0) { throw $base.Text }
    $script:baseline = $base.Text

    Test-Pod 'valid-dry-run' {} @()
    Test-Pod 'latest' { param($p) $p.spec.containers[0].image = 'busybox:latest' } @('disallow-latest')
    Test-Pod 'implicit-latest' { param($p) $p.spec.containers[0].image = 'busybox' } @('disallow-latest')
    Test-Pod 'registry-port-no-tag' { param($p) $p.spec.containers[0].image = 'registry.example:5000/demo' } @('disallow-latest')
    Test-Pod 'digest' { param($p) $p.spec.containers[0].image = 'busybox@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' } @()
    Test-Pod 'container-nonroot' { param($p)
        $p.spec.PSObject.Properties.Remove('securityContext')
        $p.spec.containers[0].securityContext | Add-Member runAsNonRoot $true
        $p.spec.containers[0].securityContext | Add-Member runAsUser 1000
    } @()
    Test-Pod 'no-resources' { param($p) $p.spec.containers[0].PSObject.Properties.Remove('resources') } @('require-resources')
    Test-Pod 'no-memory-limit' { param($p) $p.spec.containers[0].resources.limits.PSObject.Properties.Remove('memory') } @('require-resources')
    Test-Pod 'no-cpu-limit' { param($p) $p.spec.containers[0].resources.limits.PSObject.Properties.Remove('cpu') } @('require-resources')
    Test-Pod 'zero-resources' { param($p)
        foreach ($section in @('requests', 'limits')) {
            $p.spec.containers[0].resources.$section.cpu = '0'
            $p.spec.containers[0].resources.$section.memory = '0'
        }
    } @('require-resources')
    Test-Pod 'root-uid' { param($p) $p.spec.securityContext.runAsUser = 0 } @('disallow-root')
    Test-Pod 'root-override' { param($p) $p.spec.containers[0].securityContext | Add-Member runAsNonRoot $false } @('disallow-root')
    Test-Pod 'missing-nonroot' { param($p) $p.spec.PSObject.Properties.Remove('securityContext') } @('disallow-root')
    Test-Pod 'fake-cadvisor-label' { param($p)
        $p.metadata.labels.app = 'playhub-cadvisor-network'
        $p.spec.securityContext.runAsNonRoot = $false
        $p.spec.securityContext.runAsUser = 0
    } @('disallow-root')
    Test-Pod 'fake-cadvisor-owner' { param($p)
        $p.metadata.namespace = 'default'
        $p.metadata.labels.app = 'playhub-cadvisor-network'
        $p.metadata | Add-Member ownerReferences @(@{ apiVersion = 'apps/v1'; kind = 'DaemonSet'; name = 'playhub-cadvisor-network'; uid = '00000000-0000-0000-0000-000000000001'; controller = $true })
        $p.spec.securityContext.runAsUser = 0
    } @('disallow-root')
    Test-Pod 'fake-falco-owner' { param($p)
        $p.metadata.namespace = 'falco'
        $p.metadata | Add-Member ownerReferences @(@{ apiVersion = 'apps/v1'; kind = 'DaemonSet'; name = 'falco'; uid = '00000000-0000-0000-0000-000000000001'; controller = $true })
        $p.spec | Add-Member serviceAccountName 'falco'
        $p.spec.securityContext.runAsUser = 0
    } @('disallow-root')
    Test-Pod 'second-container' { param($p)
        $other = $p.spec.containers[0] | ConvertTo-Json -Depth 20 | ConvertFrom-Json
        $other.name = 'other'
        $other.PSObject.Properties.Remove('resources')
        $p.spec.containers = @($p.spec.containers[0], $other)
    } @('require-resources')
    foreach ($violation in @('latest', 'resources', 'root')) {
        $mutate = {
            param($p)
            $init = $p.spec.containers[0] | ConvertTo-Json -Depth 20 | ConvertFrom-Json
            $init.name = 'init'
            $init.command = @('true')
            switch ($violation) {
                'latest' { $init.image = 'busybox:latest' }
                'resources' { $init.PSObject.Properties.Remove('resources') }
                'root' { $init.securityContext | Add-Member runAsUser 0 }
            }
            $p.spec | Add-Member initContainers @($init)
        }.GetNewClosure()
        $policy = @{ latest = 'disallow-latest'; resources = 'require-resources'; root = 'disallow-root' }[$violation]
        Test-Pod "init-$violation" $mutate @($policy)
    }

    # Probar todos los Pod templates reales, tambien cuando la politica root
    # no usa autogen. Dry-run no requiere imagenes construidas ni crea workloads.
    $lines.Add('Pod templates: se usa ServiceAccount default para probar las politicas sin desplegar el RBAC de PlayHub. No se comprueba el arranque de estos servicios.')
    $manifests = @(Get-ChildItem (Join-Path $projectRoot 'k8s') -Recurse -Filter '*.yaml')
    $manifests += Get-Item (Join-Path $projectRoot 'scripts/flyway-repair.yaml')
    $falcoManifest = Join-Path $projectRoot '.tmp/security-reports/falco-rendered.yaml'
    if (-not (Test-Path $falcoManifest)) { throw 'Renderizar Falco 9.2.2 en .tmp/security-reports/falco-rendered.yaml antes de validar.' }
    $manifests += Get-Item $falcoManifest
    foreach ($manifest in $manifests) {
        if ($manifest.Name -eq 'secret.yaml' -or $manifest.Directory.Name -eq 'kyverno') { continue }
        $parsed = Invoke-KubeCapture -Arguments @('create', '--dry-run=client', '-f', $manifest.FullName, '-o', 'json') -SummarizeJson
        if ($parsed.Code -ne 0) { throw $parsed.Text }
        # kubectl create imprime documentos JSON consecutivos para YAML multi-doc.
        # Solo se separan llaves de nivel superior, nunca contenido de strings.
        $jsonArray = '[' + ($parsed.Text -replace '(?m)^\}\r?\n\{', "},`n{") + ']'
        $objects = @($jsonArray | ConvertFrom-Json)
        $objects = @($objects | ForEach-Object {
            if ($_.kind -eq 'List') { $_.items } else { $_ }
        })
        foreach ($workload in $objects) {
            if (-not $workload.spec.template.spec.containers) { continue }
            $metadata = @{
                name = "admission-$($workload.metadata.name)"
                namespace = $(if ($manifest.FullName -eq $falcoManifest) { 'falco' } else { 'default' })
                labels = $workload.spec.template.metadata.labels
            }
            if ($workload.kind -eq 'DaemonSet') {
                $metadata.ownerReferences = @(@{
                    apiVersion = 'apps/v1'; kind = 'DaemonSet'; name = $workload.metadata.name
                    uid = '00000000-0000-0000-0000-000000000001'; controller = $true
                })
            }
            $pod = @{ apiVersion = 'v1'; kind = 'Pod'; metadata = $metadata; spec = $workload.spec.template.spec }
            if ($metadata.namespace -ne 'falco') { $pod.spec.PSObject.Properties.Remove('serviceAccountName') }
            $pod.spec.PSObject.Properties.Remove('serviceAccount')
            $arguments = @('create', '--dry-run=server', '-f', '-')
            if ($workload.metadata.name -in @('falco', 'playhub-cadvisor-network')) {
                # Impersonacion solo para comprobar la identidad real de admision;
                # el administrador de laboratorio necesita permiso impersonate.
                $arguments += '--as=system:serviceaccount:kube-system:daemon-set-controller'
            }
            $result = Invoke-KubeCapture $arguments ($pod | ConvertTo-Json -Depth 40)
            Assert-Allowed "Pod template $($workload.metadata.name)" $result
        }
    }

    # Ejecutar las funciones reales del despliegue, sin volver a desplegar la app.
    $tokens = $null; $parseErrors = $null
    $deployAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'deploy.ps1'), [ref]$tokens, [ref]$parseErrors)
    foreach ($name in @('Invoke-Kubectl', 'Get-KubectlOutput', 'Test-ClusterImage')) {
        $definition = $deployAst.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }, $true)
        if (-not $definition) { throw "Funcion de despliegue ausente: $name" }
        Invoke-Expression $definition.Extent.Text
    }
    $index = 0
    foreach ($image in @('playhub-frontend:v1.0', 'playhub-backend:v1.0', 'playhub-frontend:v2.0', 'playhub-backend:v2.0')) {
        $index++
        $lines.Add("Test-ClusterImage -Image $image -Index $index (funcion real deploy.ps1, Kyverno activo)")
        Test-ClusterImage -Image $image -Index $index
        $lines.Add("PASS: Pod auxiliar $image ejecutado sin root y limpiado.")
        $passed++
    }

    # Intento real de creacion: debe fallar por las tres politicas, no por sintaxis.
    $invalid = Invoke-KubeCapture @('create', '-f', $invalidFixture)
    Assert-Denied 'invalid-pod.yaml (creacion real)' $invalid @('disallow-latest', 'require-resources', 'disallow-root')
    $absent = Invoke-KubeCapture @('get', 'pod', 'kyverno-invalid', '-n', $namespace, '--ignore-not-found', '-o', 'name')
    if ($absent.Code -ne 0 -or $absent.Text.Trim()) { throw 'El Pod invalido no deberia existir.' }

    # El nombre fijo se crea, nunca se sobreescribe un Pod existente.
    $valid = Invoke-KubeCapture @('create', '-f', $fixture)
    Assert-Allowed 'valid-pod.yaml (creacion real)' $valid
    $createdPod = $true
    $running = Invoke-KubeCapture @('wait', '-n', $namespace, '--for=condition=Ready', 'pod/kyverno-valid', '--timeout=120s')
    Assert-Allowed 'Pod valido Running/Ready' $running
    $uid = Invoke-KubeCapture @('exec', '-n', $namespace, 'kyverno-valid', '--', 'id', '-u')
    if ($uid.Code -ne 0 -or $uid.Text.Trim() -ne '1000') { throw "UID inesperado: $($uid.Text)" }
    $lines.Add('PASS: el proceso del Pod valido ejecuta con UID 1000.')
    $passed++

    # Kubernetes prohibe resources en contenedores efimeros. Se prueban por
    # su subrecurso real, con dryRun=All, para no modificar el Pod valido.
    foreach ($violation in @('latest', 'root', 'valid')) {
        $current = Invoke-KubeCapture @('get', 'pod', 'kyverno-valid', '-n', $namespace, '-o', 'json')
        if ($current.Code -ne 0) { throw $current.Text }
        $pod = $current.Text | ConvertFrom-Json
        $ephemeral = @{
            name = "debug-$violation"; image = 'busybox:1.37.0'; command = @('true')
            securityContext = @{ runAsNonRoot = $true; runAsUser = 1000 }
        }
        if ($violation -eq 'latest') { $ephemeral.image = 'busybox:latest' }
        if ($violation -eq 'root') { $ephemeral.securityContext.runAsUser = 0 }
        $pod.spec | Add-Member ephemeralContainers @($ephemeral)
        $url = "/api/v1/namespaces/$namespace/pods/kyverno-valid/ephemeralcontainers?dryRun=All"
        $result = Invoke-KubeCapture @('replace', '--raw', $url, '-f', '-') ($pod | ConvertTo-Json -Depth 40)
        if ($violation -eq 'valid') { Assert-Allowed 'ephemeral valido sin resources (API Kubernetes)' $result }
        else {
            $policy = @{ latest = 'disallow-latest'; root = 'disallow-root' }[$violation]
            Assert-Denied "ephemeral-$violation" $result @($policy)
        }
    }
    $lines.Add("RESULTADO: $passed comprobaciones correctas.")
} catch {
    $exitCode = 1
    $lines.Add("FAIL: $($_.Exception.Message)")
} finally {
    if ($createdPod) {
        $cleanup = Invoke-KubeCapture @('delete', 'pod', 'kyverno-valid', '-n', $namespace, '--wait=false')
        if ($cleanup.Code -ne 0) { $lines.Add('FAIL: no se pudo limpiar el Pod de prueba.'); $exitCode = 1 }
    }
    $lines | Set-Content -LiteralPath $report -Encoding UTF8
}
$lines | Where-Object { $_ -match '^(PASS|FAIL|RESULTADO)' } | Write-Output
Write-Host "Evidencia guardada en $report"
exit $exitCode
