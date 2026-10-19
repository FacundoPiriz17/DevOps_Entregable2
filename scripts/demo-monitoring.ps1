<#
.SYNOPSIS
    Genera trafico real contra PlayHub para alimentar los dashboards de Grafana.

.DESCRIPTION
    Este script prueba la demo de monitoreo de extremo a extremo:

    1. Opcionalmente despliega la aplicacion invocando deploy.ps1 (-Deploy).
    2. Espera a que backend, frontend y Prometheus respondan.
    3. Genera trafico contra la API REST con curl.exe (sin dependencias externas):
       logins fallidos, registro e ingreso de usuarios sinteticos, catalogo,
       carrito, compras, wishlist, errores 4xx y una ráfaga de carga concurrente
       que mueve CPU/RAM/red de los workloads y del nodo.
    4. Desactiva los usuarios sinteticos con un administrador (salvo -KeepUsers).
    5. Consulta Prometheus para verificar que las metricas aumentaron e imprime
       un resumen con los enlaces a los dashboards de Grafana.

    Sale con codigo 0 solo si las metricas clave aumentaron (tambien funciona
    como smoke test de la demo de monitoreo).

.EXAMPLE
    .\scripts\demo-monitoring.ps1

.EXAMPLE
    .\scripts\demo-monitoring.ps1 -Deploy -DeployGreen

.EXAMPLE
    .\scripts\demo-monitoring.ps1 -SyntheticUsers 8 -BurstSeconds 60 -BurstConcurrency 12
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Deploy,
    [switch]$DeployGreen,
    [string]$ClusterType = "minikube",
    [string]$ApiUrl = "http://localhost:8080",
    [string]$FrontendUrl = "http://localhost:5745",
    [string]$PrometheusUrl = "http://localhost:9090",
    [ValidateRange(1, 1000)][int]$SyntheticUsers = 5,
    [ValidateRange(1, 86400)][int]$BurstSeconds = 30,
    [ValidateRange(1, 128)][int]$BurstConcurrency = 8,
    [ValidateRange(1, 86400)][int]$TimeoutSec = 180,
    [switch]$KeepUsers,
    [switch]$SkipFrontend
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ----------------------------------------------------------------------------
# Utilidades de log
# ----------------------------------------------------------------------------
$script:FailCount = 0

function Write-Step([string]$Message) { Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "  OK  $Message" -ForegroundColor Green }
function Write-Info([string]$Message) { Write-Host "  ..  $Message" -ForegroundColor Gray }
function Write-WarnLine([string]$Message) { Write-Host "  AVISO  $Message" -ForegroundColor Yellow }
function Write-ErrLine([string]$Message) { Write-Host "  ERROR  $Message" -ForegroundColor Red }

# ----------------------------------------------------------------------------
# Preparacion
# ----------------------------------------------------------------------------
if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
    Write-ErrLine "No se encontro curl.exe en el PATH. Se requiere para generar el trafico."
    exit 2
}

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LogsDir = Join-Path $ProjectRoot "logs"
if (-not (Test-Path $LogsDir)) { New-Item -ItemType Directory -Path $LogsDir | Out-Null }
$RunId = (Get-Date -Format "yyyyMMddHHmmss") + "-" + [guid]::NewGuid().ToString("N").Substring(0, 8)
$WorkDir = Join-Path $LogsDir "demo-monitoring/$RunId"
New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
$ApiUrl = $ApiUrl.TrimEnd('/')
$FrontendUrl = $FrontendUrl.TrimEnd('/')
$PrometheusUrl = $PrometheusUrl.TrimEnd('/')

$AdminEmail = "facundo@playhub.test"
$AdminPassword = "PlayHub123"
$GeneralEmail = "agostina@playhub.test"
$GeneralPassword = "PlayHub123"
$FailedLoginAttempts = 15
$ErrorRequestRounds = 3

# ----------------------------------------------------------------------------
# HTTP basico con curl.exe
# ----------------------------------------------------------------------------
function Invoke-Curl {
    param(
        [string]$Method = "GET",
        [string]$Url,
        [string]$Body,
        [string]$CookieJar,
        [string[]]$ExtraArgs = @()
    )
    $tmp = [System.IO.Path]::GetTempFileName()
    $curlArgs = @("-s", "-S", "-o", $tmp, "-w", "%{http_code}", "-X", $Method, "--max-time", "30")
    if ($CookieJar) { $curlArgs += @("-b", $CookieJar, "-c", $CookieJar) }
    $bodyFile = $null
    try {
        if ($Body) {
            # PowerShell 5.1 removes JSON quotes in native command arguments.
            $bodyFile = [System.IO.Path]::GetTempFileName()
            [System.IO.File]::WriteAllText($bodyFile, $Body, (New-Object System.Text.UTF8Encoding($false)))
            $curlArgs += @("-H", "Content-Type: application/json", "--data-binary", "@$bodyFile")
        }
        $curlArgs += $ExtraArgs
        $curlArgs += $Url
        # Connection errors must not terminate readiness polling in PowerShell 5.1.
        $code = (& curl.exe @curlArgs 2>&1 | Select-Object -Last 1)
        $curlExitCode = $LASTEXITCODE
        $content = [System.IO.File]::ReadAllText($tmp)
        $status = 0
        if ($curlExitCode -eq 0 -and "$code" -match "^\d+$") { $status = [int]"$code" }
        [pscustomobject]@{ StatusCode = $status; Body = $content }
    } catch {
        [pscustomobject]@{ StatusCode = 0; Body = "" }
    } finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        if ($bodyFile) { Remove-Item -LiteralPath $bodyFile -Force -ErrorAction SilentlyContinue }
    }
}

function Get-Json([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    try { return $Text | ConvertFrom-Json } catch { return $null }
}

# ----------------------------------------------------------------------------
# Espera de disponibilidad
# ----------------------------------------------------------------------------
function Wait-HttpOk {
    param([string]$Url, [string]$Label, [int]$Seconds = $TimeoutSec)
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $r = Invoke-Curl -Url $Url -ExtraArgs @("--location")
            if ($r.StatusCode -eq 200) { return $true }
        } catch { }
        Start-Sleep -Seconds 2
    }
    Write-WarnLine "Tiempo agotado esperando $Label ($Url)."
    return $false
}

# ----------------------------------------------------------------------------
# Prometheus
# ----------------------------------------------------------------------------
function Get-PromValue([string]$Query) {
    $encoded = [uri]::EscapeDataString($Query)
    $r = Invoke-Curl -Url "$PrometheusUrl/api/v1/query?query=$encoded"
    $json = Get-Json $r.Body
    if ($r.StatusCode -ne 200 -or $null -eq $json -or $json.status -ne "success" -or
            $json.data.resultType -ne "vector" -or $null -eq $json.data.result) { return $null }
    $result = @($json.data.result)
    if ($result.Count -eq 0) { return 0 }
    $value = 0.0
    if (-not [double]::TryParse([string]$result[0].value[1], [Globalization.NumberStyles]::Float,
            [Globalization.CultureInfo]::InvariantCulture, [ref]$value) -or
            [double]::IsNaN($value) -or [double]::IsInfinity($value)) { return $null }
    return $value
}

# ----------------------------------------------------------------------------
# Sesiones de usuario (cookie playhub_session en jar de curl)
# ----------------------------------------------------------------------------
function New-Session {
    param([string]$Email, [string]$Password)
    $jar = Join-Path $WorkDir ("jar-" + ($Email -replace "[^a-zA-Z0-9]", "_") + ".txt")
    $body = (@{ email = $Email; password = $Password } | ConvertTo-Json -Compress)
    $r = Invoke-Curl -Method POST -Url "$ApiUrl/api/auth/login" -Body $body -CookieJar $jar
    if ($r.StatusCode -ne 200) { return $null }
    return $jar
}

function Register-SyntheticUser([int]$Index) {
    $email = "demo-load-$RunId-$Index@playhub.test"
    $body = @{
        name     = "Demo Load $Index"
        email    = $email
        country  = "UY"
        password = "PlayHubDemo123"
    } | ConvertTo-Json -Compress
    $r = Invoke-Curl -Method POST -Url "$ApiUrl/api/auth/register" -Body $body
    if ($r.StatusCode -eq 201) {
        $jar = New-Session -Email $email -Password "PlayHubDemo123"
        return @{ Email = $email; Jar = $jar }
    }
    return $null
}

# ----------------------------------------------------------------------------
# Fase 1: despliegue opcional y espera
# ----------------------------------------------------------------------------
if ($Deploy) {
    Write-Step "Desplegando la aplicacion con deploy.ps1 (-ClusterType $ClusterType$(if ($DeployGreen) { ' -DeployGreen' }))"
    $deployArgs = @{ ClusterType = $ClusterType }
    if ($DeployGreen) { $deployArgs.DeployGreen = $true }
    & (Join-Path $PSScriptRoot "deploy.ps1") @deployArgs
    if ($LASTEXITCODE -ne 0) {
        Write-ErrLine "deploy.ps1 termino con error (codigo $LASTEXITCODE)."
        exit 2
    }
}

Write-Step "Esperando a que la aplicacion y el monitoreo respondan"
if (-not (Wait-HttpOk -Url "$ApiUrl/actuator/health" -Label "backend")) {
    Write-ErrLine "El backend no responde en $ApiUrl. Ejecuta el deploy o revisa los port-forward."
    exit 2
}
Write-Ok "Backend disponible en $ApiUrl"
if (-not $SkipFrontend) {
    if (Wait-HttpOk -Url $FrontendUrl -Label "frontend" -Seconds ([Math]::Min($TimeoutSec, 60))) {
        Write-Ok "Frontend disponible en $FrontendUrl"
    } else {
        Write-WarnLine "El frontend no responde en $FrontendUrl; la ráfaga salteara el trafico al frontend."
        $SkipFrontend = $true
    }
}
if (-not (Wait-HttpOk -Url "$PrometheusUrl/-/ready" -Label "prometheus" -Seconds 60)) {
    Write-ErrLine "Prometheus no responde en $PrometheusUrl."
    exit 2
}
Write-Ok "Prometheus disponible en $PrometheusUrl"

$targetUp = Get-PromValue 'max(up{job="playhub-backend"})'
if ($null -eq $targetUp) {
    Write-WarnLine "No se pudo consultar el target playhub-backend en Prometheus."
} elseif ($targetUp -lt 1) {
    Write-WarnLine "El target playhub-backend esta DOWN en Prometheus (http://localhost:9090/targets)."
} else {
    Write-Ok "Target playhub-backend UP en Prometheus"
}

# ----------------------------------------------------------------------------
# Fase 2: metricas antes de generar trafico
# ----------------------------------------------------------------------------
Write-Step "Leyendo metricas base en Prometheus"
$before = @{
    failedLogins = Get-PromValue "sum(failed_logins_total)"
    purchases    = Get-PromValue "sum(total_purchases_total)"
    earnings     = Get-PromValue "sum(total_earnings_currency_units_total)"
    requests     = Get-PromValue 'sum(http_server_requests_seconds_count{uri!~"/actuator.*"})'
}
foreach ($k in @("failedLogins", "purchases", "earnings", "requests")) {
    if ($null -eq $before[$k]) {
        Write-ErrLine "No se pudo consultar la metrica base $k en Prometheus."
        exit 2
    }
}
Write-Info ("failed_logins={0} purchases={1} earnings={2} http_requests={3}" -f `
        $before.failedLogins, $before.purchases, $before.earnings, $before.requests)

Write-Step "Generando $FailedLoginAttempts logins fallidos"
$failedBody = @{ email = $AdminEmail; password = "IncorrectDemoPassword" } | ConvertTo-Json -Compress
$failedResponses = 0
for ($i = 0; $i -lt $FailedLoginAttempts; $i++) {
    $r = Invoke-Curl -Method POST -Url "$ApiUrl/api/auth/login" -Body $failedBody
    if ($r.StatusCode -eq 401) { $failedResponses++ }
}
if ($failedResponses -eq $FailedLoginAttempts) { Write-Ok "$failedResponses respuestas 401 de login" }
else { Write-ErrLine "Solo $failedResponses de $FailedLoginAttempts logins devolvieron 401."; $script:FailCount++ }

# ----------------------------------------------------------------------------
# Fase 3: sesiones
# ----------------------------------------------------------------------------
Write-Step "Abriendo sesiones de usuario"
$adminJar = New-Session -Email $AdminEmail -Password $AdminPassword
if (-not $adminJar) {
    Write-ErrLine "No se pudo iniciar sesion como $AdminEmail."
    exit 2
}
Write-Ok "Sesion admin ($AdminEmail)"
$generalJar = New-Session -Email $GeneralEmail -Password $GeneralPassword
if ($generalJar) { Write-Ok "Sesion usuario general ($GeneralEmail)" }
else { Write-WarnLine "No se pudo iniciar sesion como $GeneralEmail." }

$synthetic = @()
for ($i = 1; $i -le $SyntheticUsers; $i++) {
    $u = Register-SyntheticUser -Index $i
    if ($u) { $synthetic += $u }
    if ($u -and $u.Jar) { Write-Ok "Usuario sintetico $($u.Email)" }
    else { Write-ErrLine "No se pudo registrar/iniciar sesion del usuario sintetico #$i."; $script:FailCount++ }
}

# ----------------------------------------------------------------------------
# Fase 4: catalogo (lecturas GET para latencia y throughput)
# ----------------------------------------------------------------------------
Write-Step "Generando trafico de catalogo"
$games = Get-Json (Invoke-Curl -Url "$ApiUrl/api/games" -CookieJar $adminJar).Body
$gameIds = @()
if ($games) { $gameIds = @($games | Where-Object { $_.available } | Select-Object -ExpandProperty id -Unique | Select-Object -First 12) }
if ($gameIds.Count -eq 0) {
    Write-ErrLine "El catalogo no contiene juegos disponibles para comprar."
    $script:FailCount++
} else {
    Write-Ok ("Juegos comprables detectados: " + $gameIds.Count)
}

$allSessions = @($adminJar, $generalJar) + @($synthetic | ForEach-Object { $_.Jar })
$browseCount = 0
foreach ($jar in $allSessions) {
    if (-not $jar) { continue }
    for ($n = 0; $n -lt 3; $n++) {
        $null = Invoke-Curl -Url "$ApiUrl/api/games" -CookieJar $jar
        $browseCount++
    }
    for ($n = 0; $n -lt 4 -and $gameIds.Count -gt 0; $n++) {
        $gid = Get-Random -InputObject $gameIds
        $null = Invoke-Curl -Url "$ApiUrl/api/games/$gid" -CookieJar $jar
        $browseCount++
    }
}
Write-Ok "$browseCount lecturas de catalogo"

# ----------------------------------------------------------------------------
# Fase 5: carrito y compras (alimenta total_purchases / total_earnings)
# ----------------------------------------------------------------------------
Write-Step "Generando carritos y compras"
$cartSessions = @()
if ($generalJar) { $cartSessions += @{ Email = $GeneralEmail; Jar = $generalJar } }
$cartSessions += $synthetic

$purchases = 0
foreach ($u in $cartSessions) {
    if (-not $u.Jar) { continue }
    if ($gameIds.Count -eq 0) { continue }
    $pick = @($gameIds | Get-Random -Count ([Math]::Min(3, $gameIds.Count)))
    $added = @()
    foreach ($gid in $pick) {
        $r = Invoke-Curl -Method POST -Url "$ApiUrl/api/cart/games/$gid" -CookieJar $u.Jar
        if ($r.StatusCode -eq 201) { $added += $gid }
    }
    $null = Invoke-Curl -Url "$ApiUrl/api/cart" -CookieJar $u.Jar
    if ($added.Count -gt 0) {
        $removeId = $added[0]
        $null = Invoke-Curl -Method DELETE -Url "$ApiUrl/api/cart/games/$removeId" -CookieJar $u.Jar
        $null = Invoke-Curl -Method POST -Url "$ApiUrl/api/cart/games/$removeId" -CookieJar $u.Jar
    }
    $co = Invoke-Curl -Method POST -Url "$ApiUrl/api/cart/checkout" -CookieJar $u.Jar
    if ($co.StatusCode -eq 200) { $purchases++ }
    $null = Invoke-Curl -Url "$ApiUrl/api/library" -CookieJar $u.Jar 2>$null
}
Write-Ok "Compras procesadas: $purchases de $($cartSessions.Count) usuarios"
if ($purchases -lt 1) {
    Write-ErrLine "Esta corrida no pudo completar ninguna compra."
    $script:FailCount++
}

# ----------------------------------------------------------------------------
# Fase 6: wishlist y biblioteca
# ----------------------------------------------------------------------------
Write-Step "Generando trafico de wishlist y biblioteca"
$wishOps = 0
foreach ($u in $synthetic) {
    if (-not $u.Jar -or $gameIds.Count -eq 0) { continue }
    $pick = @($gameIds | Get-Random -Count ([Math]::Min(2, $gameIds.Count)))
    foreach ($gid in $pick) {
        $r = Invoke-Curl -Method POST -Url "$ApiUrl/api/wishlist/games/$gid" -CookieJar $u.Jar
        if ($r.StatusCode -eq 201) { $wishOps++ }
    }
    $null = Invoke-Curl -Url "$ApiUrl/api/wishlist" -CookieJar $u.Jar
    if ($pick.Count -gt 0) {
        $null = Invoke-Curl -Method DELETE -Url "$ApiUrl/api/wishlist/games/$($pick[0])" -CookieJar $u.Jar
    }
}
foreach ($jar in @($adminJar, $generalJar)) {
    if (-not $jar) { continue }
    $null = Invoke-Curl -Url "$ApiUrl/api/library" -CookieJar $jar
    $null = Invoke-Curl -Url "$ApiUrl/api/users/me" -CookieJar $jar
}
Write-Ok "Operaciones de wishlist: $wishOps"

# ----------------------------------------------------------------------------
# Fase 7: errores 4xx (404, 400 y 403)
# ----------------------------------------------------------------------------
Write-Step "Generando errores 4xx (404/400/403)"
$errorJar = $null
if ($synthetic.Count -gt 0) { $errorJar = $synthetic[0].Jar }
if (-not $errorJar) { $errorJar = $generalJar }
$errorOps = 0
for ($n = 0; $n -lt $ErrorRequestRounds; $n++) {
    if ($errorJar) {
        $null = Invoke-Curl -Url "$ApiUrl/api/games/999999" -CookieJar $errorJar
        $null = Invoke-Curl -Method POST -Url "$ApiUrl/api/cart/checkout" -CookieJar $errorJar
    }
    $null = Invoke-Curl -Url "$ApiUrl/api/games/999999" -CookieJar $adminJar
    $null = Invoke-Curl -Url "$ApiUrl/api/admin/users" -CookieJar $errorJar
    $null = Invoke-Curl -Url "$ApiUrl/api/admin/users" -CookieJar $generalJar
    $errorOps += 5
}
Write-Ok "$errorOps peticiones que producen respuestas 4xx"

# ----------------------------------------------------------------------------
# Fase 8: ráfaga de carga concurrente
# ----------------------------------------------------------------------------
Write-Step "Ráfaga de carga: $BurstConcurrency workers durante $BurstSeconds segundos"
$burstScript = {
    param($Api, $Frontend, $Jar, $Seconds, $HitFrontend)
    $end = (Get-Date).AddSeconds($Seconds)
    $count = 0
    while ((Get-Date) -lt $end) {
        & curl.exe -s -o NUL -b $Jar --max-time 10 "$Api/api/games" 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { $count++ }
        & curl.exe -s -o NUL -b $Jar --max-time 10 "$Api/api/cart" 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { $count++ }
        if ($HitFrontend) {
            & curl.exe -s -L -o NUL --max-time 10 "$Frontend/" 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { $count++ }
        }
    }
    return $count
}

$burstJar = $adminJar
$jobs = @()
$burstStart = Get-Date
for ($w = 0; $w -lt $BurstConcurrency; $w++) {
    $jobs += Start-Job -ScriptBlock $burstScript -ArgumentList @(
        $ApiUrl, $FrontendUrl, $burstJar, $BurstSeconds, (-not $SkipFrontend)
    )
}
$null = Wait-Job -Job $jobs -Timeout ($BurstSeconds + 60) | Out-Null
$burstTotal = 0
foreach ($j in $jobs) {
    if ($j.State -ne "Completed") { Write-ErrLine "Worker de carga incompleto: $($j.State)"; $script:FailCount++ }
    $r = Receive-Job -Job $j -ErrorAction SilentlyContinue
    if ($r) { $burstTotal += [int]($r | Select-Object -Last 1) }
}
Remove-Job -Job $jobs -Force -ErrorAction SilentlyContinue
$burstElapsed = ((Get-Date) - $burstStart).TotalSeconds
Write-Ok ("Ráfaga completada: {0} requests en {1:N0}s (~{2:N0} req/s)" -f $burstTotal, $burstElapsed, ($burstTotal / [Math]::Max($burstElapsed, 1)))

# ----------------------------------------------------------------------------
# Fase 9: limpieza de usuarios sinteticos
# ----------------------------------------------------------------------------
if (-not $KeepUsers -and $synthetic.Count -gt 0) {
    Write-Step "Desactivando usuarios sinteticos (usa -KeepUsers para conservarlos)"
    $deactivated = 0
    foreach ($u in $synthetic) {
        $encodedEmail = [uri]::EscapeDataString($u.Email)
        $r = Invoke-Curl -Method PATCH -Url "$ApiUrl/api/admin/users/$encodedEmail/deactivate" -CookieJar $adminJar
        if ($r.StatusCode -eq 200) { $deactivated++ }
    }
    Write-Ok "$deactivated de $($synthetic.Count) usuarios sinteticos desactivados"
    if ($deactivated -ne $synthetic.Count) { $script:FailCount++; Write-ErrLine "No se pudo completar la limpieza." }
} elseif ($synthetic.Count -gt 0) {
    Write-Info "Usuarios sinteticos conservados (-KeepUsers): $($synthetic.Count)"
}

# ----------------------------------------------------------------------------
# Fase 10: verificacion en Prometheus
# ----------------------------------------------------------------------------
Write-Step "Verificando metricas en Prometheus"
$metricsDeadline = (Get-Date).AddSeconds($TimeoutSec)
do {
    $after = @{
        failedLogins   = Get-PromValue "sum(failed_logins_total)"
        purchases      = Get-PromValue "sum(total_purchases_total)"
        earnings       = Get-PromValue "sum(total_earnings_currency_units_total)"
        requests       = Get-PromValue 'sum(http_server_requests_seconds_count{uri!~"/actuator.*"})'
        targetUp       = Get-PromValue 'max(up{job="playhub-backend"})'
    }
    $metricsReady = ($null -ne $after.failedLogins -and $null -ne $after.purchases -and
        $null -ne $after.requests -and $null -ne $after.earnings -and
        ($after.failedLogins - $before.failedLogins) -ge $FailedLoginAttempts -and
        ($after.purchases - $before.purchases) -ge 1 -and
        ($after.requests - $before.requests) -ge 200 -and $after.targetUp -ge 1)
    if ($metricsReady -or (Get-Date) -ge $metricsDeadline) { break }
    Start-Sleep -Seconds 2
} while ($true)

function Get-Delta([double]$Before, $After) {
    if ($null -eq $After) { return 0 }
    $d = $After - $Before
    if ($d -lt 0) { return $After }
    return $d
}

$deltaFailed = Get-Delta $before.failedLogins $after.failedLogins
$deltaPurchases = Get-Delta $before.purchases $after.purchases
$deltaEarnings = Get-Delta $before.earnings $after.earnings
$deltaRequests = Get-Delta $before.requests $after.requests

Write-Host ""
Write-Host ("  {0,-38} {1,10} {2,12} {3,12}" -f "Metrica", "Antes", "Despues", "Delta")
Write-Host ("  {0,-38} {1,10} {2,12} {3,12}" -f "------", "-----", "-------", "-----")
Write-Host ("  {0,-38} {1,10:N1} {2,12:N1} {3,12:N1}" -f "failed_logins_total", $before.failedLogins, $after.failedLogins, $deltaFailed)
Write-Host ("  {0,-38} {1,10:N1} {2,12:N1} {3,12:N1}" -f "total_purchases_total", $before.purchases, $after.purchases, $deltaPurchases)
Write-Host ("  {0,-38} {1,10:N1} {2,12:N1} {3,12:N1}" -f "total_earnings (unidades)", $before.earnings, $after.earnings, $deltaEarnings)
Write-Host ("  {0,-38} {1,10:N1} {2,12:N1} {3,12:N1}" -f "http_server_requests (count)", $before.requests, $after.requests, $deltaRequests)
Write-Host ("  {0,-38} {1,10} {2,12}" -f "up{job=playhub-backend}", "-", $after.targetUp)
Write-Host ""

$checks = @(
    @{ Name = "Logins fallidos registrados (>= $FailedLoginAttempts)"; Ok = ($deltaFailed -ge $FailedLoginAttempts) },
    @{ Name = "Compras registradas (>= 1)"; Ok = ($deltaPurchases -ge 1) },
    @{ Name = "Requests HTTP generados (>= 200)"; Ok = ($deltaRequests -ge 200) },
    @{ Name = "Metricas finales disponibles"; Ok = ($null -ne $after.failedLogins -and $null -ne $after.purchases -and $null -ne $after.earnings -and $null -ne $after.requests) },
    @{ Name = "Target de Prometheus UP"; Ok = ($null -ne $after.targetUp -and $after.targetUp -ge 1) }
)

$allOk = ($script:FailCount -eq 0)
foreach ($c in $checks) {
    if ($c.Ok) { Write-Ok $c.Name } else { Write-ErrLine $c.Name; $allOk = $false; $script:FailCount++ }
}

Write-Step "Dashboards de Grafana (http://localhost:3000, carpeta PlayHub)"
Write-Host "  http://localhost:3000/d/playhub-counters      Contadores (compras, ganancias, logins fallidos, 500)"
Write-Host "  http://localhost:3000/d/playhub-http-latency  Latencia y throughput HTTP del backend"
Write-Host "  http://localhost:3000/d/playhub-bluegreen     Trafico y latencia por slot Blue/Green"
Write-Host "  http://localhost:3000/d/playhub-workloads     Recursos de workloads (CPU/RAM/red por pod)"
Write-Host "  http://localhost:3000/d/playhub-nodes         Recursos del nodo"
Write-Host ""
Write-Host "  Prometheus targets: http://localhost:9090/targets"

if ($allOk) {
    Write-Ok "Demo de monitoreo verificada: todas las metricas clave aumentaron."
    exit 0
} else {
    Write-ErrLine "Verificacion fallida ($($script:FailCount) chequeos). Revisa los dashboards y los targets de Prometheus."
    exit 1
}
