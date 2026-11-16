[CmdletBinding()]
param(
    [string]$Version = "v4.3.1",

    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "Programs\helm"),

    [switch]$Force
)

$ErrorActionPreference = "Stop"

if ($Version -notmatch '^v\d+\.\d+\.\d+$') {
    throw "-Version debe tener el formato vX.Y.Z (por ejemplo v4.3.1)."
}

$existing = Get-Command helm -ErrorAction SilentlyContinue
if ($null -ne $existing -and -not $Force) {
    Write-Host "Helm ya esta instalado en: $($existing.Source)"
    & helm version
    Write-Host ""
    Write-Host "No se hizo nada. Usa -Force para instalar la version $Version igualmente."
    return
}

$processorArch = $env:PROCESSOR_ARCHITEW6432
if ([string]::IsNullOrWhiteSpace($processorArch)) { $processorArch = $env:PROCESSOR_ARCHITECTURE }

switch ($processorArch) {
    "AMD64" { $arch = "amd64" }
    "ARM64" { $arch = "arm64" }
    default { throw "Arquitectura no soportada: $processorArch" }
}

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$baseUrl = "https://get.helm.sh"
$archiveName = "helm-$Version-windows-$arch.zip"
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("helm-install-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

try {
    $zipPath = Join-Path $tempDir $archiveName
    $sumPath = "$zipPath.sha256sum"

    Write-Host "Descargando $baseUrl/$archiveName ..."
    Invoke-WebRequest -UseBasicParsing -Uri "$baseUrl/$archiveName" -OutFile $zipPath
    Invoke-WebRequest -UseBasicParsing -Uri "$baseUrl/$archiveName.sha256sum" -OutFile $sumPath

    Write-Host "Verificando SHA256..."
    $expected = ((Get-Content -LiteralPath $sumPath -Raw).Trim() -split '\s+')[0]
    $actual = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
    if ($actual -ne $expected) {
        throw "El SHA256 no coincide. Esperado: $expected, obtenido: $actual. No se instalo nada."
    }
    Write-Host "SHA256 correcto."

    Expand-Archive -LiteralPath $zipPath -DestinationPath $tempDir -Force
    $helmExe = Get-ChildItem -LiteralPath $tempDir -Recurse -Filter "helm.exe" | Select-Object -First 1
    if ($null -eq $helmExe) {
        throw "No se encontro helm.exe dentro de $archiveName."
    }

    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    $target = Join-Path $InstallDir "helm.exe"
    Copy-Item -LiteralPath $helmExe.FullName -Destination $target -Force
    Write-Host "Helm copiado a: $target"

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $entries = @()
    if (-not [string]::IsNullOrWhiteSpace($userPath)) {
        $entries = @($userPath -split ';' | Where-Object { $_ })
    }
    if ($entries -notcontains $InstallDir) {
        [Environment]::SetEnvironmentVariable("Path", (($entries + $InstallDir) -join ';'), "User")
        Write-Host "Se agrego $InstallDir al PATH del usuario."
    }
    if (($env:Path -split ';') -notcontains $InstallDir) {
        $env:Path = "$env:Path;$InstallDir"
    }

    Write-Host ""
    & $target version
    Write-Host ""
    Write-Host "Listo. En esta ventana ya podes usar 'helm'. En otras ventanas de PowerShell abiertas antes, cerralas y abri una nueva."
}
finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
