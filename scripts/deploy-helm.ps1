[CmdletBinding()]
param(
    [ValidateSet("dev", "prod")]
    [string]$Environment = "dev",

    [string]$Namespace = "playhub-helm",

    [string]$ReleaseName = "playhub",

    [switch]$SkipBuild,

    [switch]$SkipImageLoad,

    [switch]$NoPortForward,

    [switch]$SkipSecurity,

    [switch]$AdoptSecurity,

    [string]$DbPassword,
    [string]$JwtSecret,
    [string]$AdminPassword
)

$ErrorActionPreference = "Stop"
if ($SkipSecurity -and $AdoptSecurity) { throw '-SkipSecurity y -AdoptSecurity no se pueden combinar.' }

$projectRoot = Split-Path -Parent $PSScriptRoot
$chartPath = Join-Path $projectRoot "helm-chart"
$valuesFile = Join-Path $chartPath "values-$Environment.yaml"
. (Join-Path $PSScriptRoot "lib/native.ps1")
. (Join-Path $PSScriptRoot "lib/security-stack.ps1")

function Assert-Command {
    param([Parameter(Mandatory = $true)][string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "No se encontro '$Name' en PATH."
    }
}

function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )
    $result = Invoke-PlayHubNative -Command $Command -Arguments $Arguments
    if ($result.Output) { Write-Host $result.Output }
    if ($result.ErrorOutput) { Write-Host $result.ErrorOutput }
    if ($result.ExitCode -ne 0) {
        throw "Fallo $Command (codigo $($result.ExitCode))."
    }
}

function Get-ResourceBaseName {
    if ($ReleaseName -like "*playhub*") { return $ReleaseName }
    return "$ReleaseName-playhub"
}

function ConvertTo-YamlSingleQuoted {
    param([Parameter(Mandatory = $true)][string]$Value)
    return "'" + $Value.Replace("'", "''") + "'"
}

function Stop-HelmPortForward {
    foreach ($name in @("backend", "frontend", "prometheus", "grafana")) {
        $pidFile = Join-Path $projectRoot "logs\helm-port-forward-$name.pid"
        if (Test-Path -LiteralPath $pidFile) {
            $processId = Get-Content -LiteralPath $pidFile -ErrorAction SilentlyContinue
            if ($processId -match '^\d+$') {
                $existing = Get-Process -Id $processId -ErrorAction SilentlyContinue
                if ($null -ne $existing -and $existing.ProcessName -like '*kubectl*') {
                    Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
                }
            }
            Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
        }
    }
}

function Clear-Port {
    param([Parameter(Mandatory = $true)][int]$Port)

    $listeners = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    foreach ($listener in $listeners) {
        $owner = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
        if ($null -eq $owner) { continue }
        if ($owner.ProcessName -notlike "*kubectl*") {
            Write-Warning "El puerto $Port esta ocupado por '$($owner.ProcessName)' (PID $($owner.Id)), que no es un port-forward."
            return $false
        }
        Write-Host "Liberando el puerto ${Port}: port-forward previo (PID $($owner.Id))."
        Stop-Process -Id $owner.Id -Force -ErrorAction SilentlyContinue
    }
    if ($listeners) { Start-Sleep -Seconds 1 }
    return $true
}

function Start-HelmPortForward {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Service,
        [Parameter(Mandatory = $true)][int]$Port,
        [switch]$Optional
    )

    $servicePort = Invoke-PlayHubNative -Command "kubectl" -Arguments @(
        "get", "service", $Service, "-n", $Namespace, "--ignore-not-found=true",
        "-o", "jsonpath={.spec.ports[0].port}"
    )
    if ($servicePort.ExitCode -ne 0) {
        Write-Warning "No se pudo consultar el Service '$Service': $($servicePort.ErrorOutput)"
        return $false
    }
    if ($Optional -and [string]::IsNullOrWhiteSpace($servicePort.Output)) {
        Write-Host "Service opcional '$Service' deshabilitado; se omite su port-forward."
        return $true
    }
    $remotePort = 0
    if (-not [int]::TryParse($servicePort.Output.Trim(), [ref]$remotePort)) {
        Write-Warning "El Service '$Service' no tiene un puerto disponible."
        return $false
    }

    if (-not (Clear-Port -Port $Port)) { return $false }

    $logsDir = Join-Path $projectRoot "logs"
    New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
    $pidFile = Join-Path $logsDir "helm-port-forward-$Name.pid"
    $logFile = Join-Path $logsDir "helm-port-forward-$Name.log"
    $mapping = "${Port}:${remotePort}"

    $proc = Start-Process -FilePath "kubectl" `
        -ArgumentList @("port-forward", "-n", $Namespace, "svc/$Service", $mapping) `
        -RedirectStandardOutput $logFile `
        -RedirectStandardError "$logFile.err" `
        -WindowStyle Hidden `
        -PassThru
    Set-Content -LiteralPath $pidFile -Value $proc.Id

    for ($attempt = 0; $attempt -lt 10; $attempt++) {
        Start-Sleep -Milliseconds 500
        $output = ""
        if (Test-Path -LiteralPath $logFile) { $output += Get-Content -LiteralPath $logFile -Raw -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath "$logFile.err") { $output += Get-Content -LiteralPath "$logFile.err" -Raw -ErrorAction SilentlyContinue }
        if ($output -match "Forwarding from") {
            Write-Host "Port-forward activo: svc/$Service -> $mapping (log: $logFile)"
            return $true
        }
    }

    Write-Warning "No se pudo iniciar el port-forward de '$Service'. Revisa $logFile y $logFile.err"
    return $false
}

Assert-Command -Name "helm"
Assert-Command -Name "kubectl"

$contextResult = Invoke-PlayHubNative -Command "kubectl" -Arguments @("config", "current-context")
$currentContext = $contextResult.Output.Trim()
if ($contextResult.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($currentContext)) {
    throw "kubectl no tiene un contexto activo."
}

Write-Host "Contexto Kubernetes: $currentContext"
Write-Host "Namespace del release: $Namespace"
Write-Host "Release: $ReleaseName"
Write-Host "Entorno: $Environment"

if (-not (Test-Path -LiteralPath (Join-Path $chartPath "Chart.yaml"))) {
    throw "No se encontro $chartPath\Chart.yaml. La carpeta helm-chart debe estar en la raiz del proyecto."
}
if (-not (Test-Path -LiteralPath $valuesFile)) {
    throw "No se encontro $valuesFile."
}

if ($Environment -eq "prod") {
    if ([string]::IsNullOrWhiteSpace($DbPassword) -or
        [string]::IsNullOrWhiteSpace($JwtSecret) -or
        [string]::IsNullOrWhiteSpace($AdminPassword)) {
        throw "En prod hay que pasar -DbPassword, -JwtSecret (48+ bytes UTF-8) y -AdminPassword."
    }
    if ([System.Text.Encoding]::UTF8.GetByteCount($JwtSecret) -lt 48) {
        throw '-JwtSecret requiere al menos 48 bytes UTF-8 para HS384.'
    }
}

if ($Environment -eq "prod") {
    $frontendTag = "v1.0-prod"
    $frontendApiUrl = "http://playhub.local"
}
else {
    $frontendTag = "v1.0"
    $frontendApiUrl = "http://localhost:8080"
}
$backendImage = "playhub-backend:v1.0"
$frontendImage = "playhub-frontend:$frontendTag"

$secretsFile = $null

Push-Location $projectRoot
try {
    if (-not $SkipBuild) {
        Assert-Command -Name "docker"
        Write-Host "Construyendo imagenes..."
        Invoke-Native -Command "docker" -Arguments @("build", "--file", "backend/Dockerfile.prod", "--tag", $backendImage, "backend")
        Invoke-Native -Command "docker" -Arguments @("build", "--build-arg", "NEXT_PUBLIC_API_URL=$frontendApiUrl", "--file", "frontend/Dockerfile.prod", "--tag", $frontendImage, "frontend")
    }
    else {
        Write-Warning "Se omitio la construccion de imagenes."
    }

    if (-not $SkipImageLoad) {
        if ($currentContext -eq "minikube") {
            Assert-Command -Name "minikube"
            Assert-Command -Name "docker"
            Write-Host "Cargando imagenes en Minikube..."
            # Un archivo distinto evita reutilizar una importacion cacheada por tag.
            $imageDirectory = Join-Path $projectRoot ".tmp"
            New-Item -ItemType Directory -Force -Path $imageDirectory | Out-Null
            $imageArchive = Join-Path $imageDirectory "helm-images-$([guid]::NewGuid().ToString('N')).tar"
            try {
                Invoke-Native -Command "docker" -Arguments @("save", "--output", $imageArchive, $backendImage, $frontendImage)
                Invoke-Native -Command "minikube" -Arguments @("image", "load", "--overwrite=true", $imageArchive)
            }
            finally {
                if (Test-Path -LiteralPath $imageArchive) { Remove-Item -LiteralPath $imageArchive -Force }
            }
        }
        else {
            Write-Warning "El contexto '$currentContext' no es minikube: no se cargaron las imagenes. Deben existir en el cluster."
        }
    }
    else {
        Write-Warning "Se omitio la carga de imagenes en el cluster."
    }

    Write-Host "Validando el chart (helm lint)..."
    Invoke-Native -Command "helm" -Arguments @("lint", $chartPath, "-f", $valuesFile)

    if (-not $SkipSecurity) {
        Initialize-PlayHubSecurity -ProjectRoot $projectRoot -AdoptExisting:$AdoptSecurity
    }
    else {
        Write-Host "Se omite la instalacion de Kyverno y Falco (-SkipSecurity)."
    }

    Write-Host "Instalando / actualizando el release con Helm (entorno $Environment)..."
    $helmArgs = @(
        "upgrade", "--install", $ReleaseName, $chartPath,
        "-f", $valuesFile,
        "-n", $Namespace, "--create-namespace",
        "--wait", "--timeout", "5m"
    )

    if ($Environment -eq "prod") {
        $tmpDir = Join-Path $projectRoot ".tmp"
        New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
        $secretsFile = Join-Path $tmpDir "helm-secrets-$([guid]::NewGuid().ToString('N')).yaml"
        $lines = @(
            "secrets:",
            "  dbPassword: $(ConvertTo-YamlSingleQuoted $DbPassword)",
            "  jwtSecret: $(ConvertTo-YamlSingleQuoted $JwtSecret)",
            "  adminPassword: $(ConvertTo-YamlSingleQuoted $AdminPassword)"
        )
        [System.IO.File]::WriteAllText($secretsFile, (($lines -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))
        $helmArgs += @("-f", $secretsFile)
    }

    try {
        Invoke-Native -Command "helm" -Arguments $helmArgs
    }
    catch {
        Write-Warning "El despliegue no se completo. Estado actual del namespace:"
        & kubectl get pods -n $Namespace -o wide
        & kubectl get events -n $Namespace --sort-by=.lastTimestamp
        throw
    }

    Write-Host ""
    Write-Host "Pods, servicios y volumenes del release:"
    Invoke-Native -Command "kubectl" -Arguments @("get", "pods,svc,pvc", "-n", $Namespace)

    Write-Host ""
    Write-Host "Ejecutando helm test..."
    Invoke-Native -Command "helm" -Arguments @("test", $ReleaseName, "-n", $Namespace)

    $base = Get-ResourceBaseName
    Write-Host ""
    if ($Environment -eq "prod") {
        Write-Host "Acceso por Ingress: http://playhub.local"
        Write-Host "Requiere: minikube addons enable ingress, 'minikube tunnel' corriendo y"
        Write-Host "la linea '127.0.0.1 playhub.local' en C:\Windows\System32\drivers\etc\hosts"
    }
    if (-not $NoPortForward) {
        Stop-HelmPortForward
        $accessOk = $true
        if ($Environment -eq "dev") {
            if (-not (Start-HelmPortForward -Name "backend" -Service "$base-backend" -Port 8080)) { $accessOk = $false }
            if (-not (Start-HelmPortForward -Name "frontend" -Service "$base-frontend" -Port 5745)) { $accessOk = $false }
        }
        if (-not (Start-HelmPortForward -Name "prometheus" -Service "$base-prometheus" -Port 9090 -Optional)) { $accessOk = $false }
        if (-not (Start-HelmPortForward -Name "grafana" -Service "$base-grafana" -Port 3000 -Optional)) { $accessOk = $false }
        if (-not $accessOk) {
            Write-Warning "El despliegue termino, pero algun port-forward no pudo iniciarse (ver mensajes arriba)."
            exit 1
        }
        Write-Host ""
        if ($Environment -eq "dev") {
            Write-Host "Frontend disponible en: http://localhost:5745"
            Write-Host "Backend disponible en:  http://localhost:8080/actuator/health"
        }
        Write-Host "Monitoreo habilitado: Prometheus http://localhost:9090 y Grafana http://localhost:3000"
        Write-Host "Para detener los accesos y limpiar el release: .\scripts\cleanup-helm.ps1"
    }
    else {
        Write-Warning "Se omitio el inicio automatico de port-forward (-NoPortForward)."
        Write-Host "Manual: kubectl port-forward -n $Namespace svc/$base-backend 8080:8080"
        Write-Host "        kubectl port-forward -n $Namespace svc/$base-frontend 5745:5745"
        Write-Host "        kubectl port-forward -n $Namespace svc/$base-prometheus 9090:9090"
        Write-Host "        kubectl port-forward -n $Namespace svc/$base-grafana 3000:3000"
    }
}
finally {
    if ($null -ne $secretsFile) { Remove-Item -LiteralPath $secretsFile -Force -ErrorAction SilentlyContinue }
    Pop-Location
}
