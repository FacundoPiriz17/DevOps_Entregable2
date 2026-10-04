[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("blue", "green")]
    [string]$Target
)

$ErrorActionPreference = "Stop"

function Invoke-Kubectl {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & kubectl @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "Fallo kubectl $($Arguments -join ' ')"
    }
}

function Get-ServiceSlot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Service
    )

    $slot = & kubectl get service $Service -o "jsonpath={.spec.selector.slot}"

    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo obtener el slot del Service $Service."
    }

    return $slot.Trim()
}

function Set-ServiceSlot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Service,

        [Parameter(Mandatory = $true)]
        [ValidateSet("blue", "green")]
        [string]$Slot
    )

    $patch = @{
        spec = @{
            selector = @{
                slot = $Slot
            }
        }
    } | ConvertTo-Json -Compress

    $patchFile = [System.IO.Path]::GetTempFileName()

    try {
        $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($patchFile, $patch, $utf8WithoutBom)

        Invoke-Kubectl -Arguments @(
            "patch",
            "service",
            $Service,
            "--type=merge",
            "--patch-file=$patchFile"
        )
    }
    finally {
        Remove-Item -LiteralPath $patchFile -Force -ErrorAction SilentlyContinue
    }
}

function Restart-TrackedPortForward {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Service,

        [Parameter(Mandatory = $true)]
        [int]$LocalPort,

        [Parameter(Mandatory = $true)]
        [int]$RemotePort,

        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    $pidFile = Join-Path $ProjectRoot "logs\port-forward-$Name.pid"

    if (-not (Test-Path -LiteralPath $pidFile)) {
        return $false
    }

    $processId = Get-Content -LiteralPath $pidFile -ErrorAction SilentlyContinue

    if (-not [string]::IsNullOrWhiteSpace($processId)) {
        $existing = Get-Process -Id $processId -ErrorAction SilentlyContinue

        if ($null -ne $existing) {
            Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
        }
    }

    $logFile = Join-Path $ProjectRoot "logs\port-forward-$Name.log"
    $portMapping = "${LocalPort}:${RemotePort}"

    $proc = Start-Process -FilePath "kubectl" `
        -ArgumentList @("port-forward", "svc/$Service", $portMapping) `
        -RedirectStandardOutput $logFile `
        -RedirectStandardError "$logFile.err" `
        -WindowStyle Hidden `
        -PassThru

    Set-Content -LiteralPath $pidFile -Value $proc.Id

    Write-Host "Port-forward de '$Service' reiniciado para apuntar al nuevo slot (log: $logFile)."

    return $true
}

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    throw "No se encontro kubectl en PATH."
}

$projectRoot = Split-Path -Parent $PSScriptRoot

$backendDeployment = "playhub-backend-$Target"
$frontendDeployment = "playhub-frontend-$Target"

$currentBackendSlot = Get-ServiceSlot -Service "playhub-backend"
$currentFrontendSlot = Get-ServiceSlot -Service "playhub-frontend"

if ($currentBackendSlot -ne $currentFrontendSlot) {
    throw "Estado inconsistente: frontend=$currentFrontendSlot, backend=$currentBackendSlot."
}

$currentSlot = $currentBackendSlot

if ($currentSlot -eq $Target) {
    Write-Host "PlayHub ya utiliza el slot '$Target'."
    exit 0
}

Write-Host "Comprobando que Backend $Target este disponible..."
Invoke-Kubectl -Arguments @("rollout", "status", "deployment/$backendDeployment", "--timeout=180s")

Write-Host "Comprobando que Frontend $Target este disponible..."
Invoke-Kubectl -Arguments @("rollout", "status", "deployment/$frontendDeployment", "--timeout=180s")

$backendChanged = $false

try {
    Write-Host "Cambiando el backend de $currentSlot a $Target..."
    Set-ServiceSlot -Service "playhub-backend" -Slot $Target
    $backendChanged = $true

    Write-Host "Cambiando el frontend de $currentSlot a $Target..."
    Set-ServiceSlot -Service "playhub-frontend" -Slot $Target
}
catch {
    if ($backendChanged) {
        Write-Warning "Fallo el cambio del frontend. Restaurando el backend a $currentSlot..."
        Set-ServiceSlot -Service "playhub-backend" -Slot $currentSlot
    }

    throw
}

Write-Host ""
Write-Host "PlayHub ahora utiliza el slot '$Target'."

Invoke-Kubectl -Arguments @(
    "get",
    "service",
    "playhub-backend",
    "playhub-frontend",
    "-o=custom-columns=SERVICE:.metadata.name,SLOT:.spec.selector.slot"
)

$backendRestarted = Restart-TrackedPortForward -Name "backend" -Service "playhub-backend" -LocalPort 8080 -RemotePort 8080 -ProjectRoot $projectRoot
$frontendRestarted = Restart-TrackedPortForward -Name "frontend" -Service "playhub-frontend" -LocalPort 5745 -RemotePort 5745 -ProjectRoot $projectRoot

if (-not $backendRestarted -or -not $frontendRestarted) {
    Write-Warning "Si utilizas port-forward manual, detenlo y vuelvelo a iniciar para conectarte a los Pods del nuevo slot."
}
