[CmdletBinding()]
param(
    [ValidateSet("dev", "prod")]
    [string]$Environment = "dev",

    [string]$Namespace = "playhub-helm",

    [string]$ReleaseName = "playhub",

    [switch]$SkipBuild,

    [switch]$SkipImageLoad,

    [switch]$NoPortForward,

    [string]$DbPassword,
    [string]$JwtSecret,
    [string]$AdminPassword
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$chartPath = Join-Path $projectRoot "helm-chart"
$valuesFile = Join-Path $chartPath "values-$Environment.yaml"

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
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Fallo: $Command $($Arguments -join ' ')"
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
        [Parameter(Mandatory = $true)][int]$Port
    )

    if (-not (Clear-Port -Port $Port)) { return $false }

    $logsDir = Join-Path $projectRoot "logs"
    New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
    $pidFile = Join-Path $logsDir "helm-port-forward-$Name.pid"
    $logFile = Join-Path $logsDir "helm-port-forward-$Name.log"
    $mapping = "${Port}:${Port}"

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

$currentContext = (& kubectl config current-context)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($currentContext)) {
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
        throw "En prod hay que pasar -DbPassword, -JwtSecret (32+ caracteres) y -AdminPassword."
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
            Write-Host "Cargando imagenes en Minikube..."
            Invoke-Native -Command "minikube" -Arguments @("image", "load", "--overwrite=true", $backendImage)
            Invoke-Native -Command "minikube" -Arguments @("image", "load", "--overwrite=true", $frontendImage)
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
    elseif (-not $NoPortForward) {
        Stop-HelmPortForward
        $backendOk = Start-HelmPortForward -Name "backend" -Service "$base-backend" -Port 8080
        $frontendOk = Start-HelmPortForward -Name "frontend" -Service "$base-frontend" -Port 5745
        if (-not ($backendOk -and $frontendOk)) {
            Write-Warning "El despliegue termino, pero algun port-forward no pudo iniciarse (ver mensajes arriba)."
            exit 1
        }
        Write-Host ""
        Write-Host "Frontend disponible en: http://localhost:5745"
        Write-Host "Backend disponible en:  http://localhost:8080/actuator/health"
        Write-Host "Para detenerlos: Stop-Process -Id (Get-Content logs\helm-port-forward-backend.pid), (Get-Content logs\helm-port-forward-frontend.pid)"
    }
    else {
        Write-Warning "Se omitio el inicio automatico de port-forward (-NoPortForward)."
        Write-Host "Manual: kubectl port-forward -n $Namespace svc/$base-backend 8080:8080"
        Write-Host "        kubectl port-forward -n $Namespace svc/$base-frontend 5745:5745"
    }
}
finally {
    if ($null -ne $secretsFile) { Remove-Item -LiteralPath $secretsFile -Force -ErrorAction SilentlyContinue }
    Pop-Location
}
