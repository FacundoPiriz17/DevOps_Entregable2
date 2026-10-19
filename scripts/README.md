# Scripts de despliegue (PlayHub en Kubernetes)

Esta carpeta contiene los scripts para desplegar PlayHub en un cluster de Kubernetes usando la estrategia Blue/Green, y para alternar entre los slots Blue y Green. Cada script existe en dos versiones equivalentes:

- `*.sh` — Bash, para Linux/macOS o Git Bash/WSL en Windows.
- `*.ps1` — PowerShell, para Windows.

## Requisitos previos

- Tener `kubectl` instalado y disponible en el `PATH`.
- Tener el `kubectl context` apuntando al cluster correcto (verificar con `kubectl config current-context`).
- Ejecutar los scripts desde cualquier ubicación dentro del repo: ambos scripts resuelven automáticamente la raíz del proyecto en base a su propia ubicación.
- Los manifiestos de Kubernetes deben existir en `k8s/` y `k8s/monitoring/`. Las credenciales se toman de `secret.yaml` o se inicializan desde `secret.yaml.example`.
- Las migraciones SQL deben existir en `backend/src/main/resources/db/migration`.
- Si falta `k8s/secret.yaml`, el despliegue lo crea automáticamente copiando `k8s/secret.yaml.example`. Si ya existe, conserva su contenido. El ejemplo contiene los mismos valores del entorno de desarrollo.
- Kubernetes no requiere `.env`: utiliza `k8s/configmap.yaml` y `k8s/secret.yaml`. `.env` es necesario para Docker Compose; se puede preparar a partir de `.env.example` completando sus valores.
- El clúster debe disponer de una StorageClass predeterminada para PostgreSQL, Prometheus y Grafana, y permitir los exporters que acceden al nodo Linux.

## `deploy.sh` / `deploy.ps1`

Despliega la base (ConfigMap, Secret, PostgreSQL), corre las migraciones de Flyway como un Job, y despliega los Services junto con el slot **Blue** (activo por defecto). Opcionalmente también puede desplegar el slot **Green** en paralelo (sin activarlo).

### Qué hace, en orden

1. Verifica que `kubectl` esté disponible.
2. Aplica `configmap.yaml`, `secret.yaml`, `postgres-pvc.yaml`, `postgres-service.yaml` y `postgres-deployment.yaml`, y espera a que el rollout de PostgreSQL complete.
3. Genera un ConfigMap (`playhub-migration-sql`) a partir de los archivos SQL de migración y lo aplica. PowerShell utiliza `binaryData` en base64 para preservar los bytes originales incluso con pipelines ASCII de Windows PowerShell 5.1; Kubernetes monta los archivos SQL normalmente.
4. Elimina el Job `playhub-migrations` si existía, aplica `migration-job.yaml`, espera a que el Job complete y muestra sus logs.
5. Aplica `backend-service.yaml`, `frontend-service.yaml`, `backend-blue-deployment.yaml` y `frontend-blue-deployment.yaml`, y espera a que ambos rollouts del slot Blue completen.
6. Si se pide, también despliega el slot Green (`backend-green-deployment.yaml`, `frontend-green-deployment.yaml`).
7. Despliega `k8s/monitoring/`: Prometheus, Grafana, kube-state-metrics, Node Exporter y cAdvisor para la red de pods. Ajusta el binding de Prometheus al namespace actual y espera los rollouts. En despliegues repetidos reinicia Prometheus y Grafana para cargar sus configuraciones actualizadas.
8. Muestra un resumen: pods, jobs, PVCs y services.
9. Inicia automáticamente `kubectl port-forward` para backend (`localhost:8080`), frontend (`localhost:5745`), Prometheus (`localhost:9090`) y Grafana (`localhost:3000`). Los procesos quedan en segundo plano, con PID y log bajo `logs/port-forward-<backend|frontend|prometheus|grafana>.{pid,log}`. Volver a ejecutar el despliegue reemplaza los accesos anteriores. `--no-port-forward` / `-NoPortForward` omite los cuatro accesos, pero despliega el monitoreo igualmente.

Grafana aprovisiona la fuente Prometheus y los dashboards de nodos, workloads y contadores en la carpeta **PlayHub**. El usuario inicial es `admin` y la contraseña inicial es `admin`; se conservan en el PVC después de cambiarlos. Para incorporar dashboards exportados, actualizar su contenido en el ConfigMap de `k8s/monitoring/grafana-config.yaml` antes del deploy. Ver [persistencia y exportación](../monitoring/README.md#persistencia-y-dashboards-exportados).

### Uso — Linux/macOS (Bash)

```bash

# Inicializa minikube
minikube start
# Solo desplegar el slot Blue (activo)
./scripts/deploy.sh

# Desplegar Blue y también Green (sin activarlo)
./scripts/deploy.sh --deploy-green
```

Si el script no tiene permisos de ejecución:

```bash
chmod +x scripts/deploy.sh scripts/switch-slot.sh
```

### Uso — Windows (PowerShell)

```powershell

# Inicializa minikube
minikube start
# Solo desplegar el slot Blue (activo)
.\scripts\deploy.ps1

# Desplegar Blue y también Green (sin activarlo)
.\scripts\deploy.ps1 -DeployGreen
```

> Nota: si PowerShell bloquea la ejecución de scripts, puede ser necesario ajustar la política de ejecución para la sesión actual:
> ```powershell
> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
> ```

Para verificar que las migraciones conservan sus bytes al atravesar un pipeline
ASCII (incluye tildes y otros caracteres UTF-8), sin desplegar ni acceder al cluster:

```powershell
.\scripts\tests\migration-configmap.ps1
```

## `switch-slot.sh` / `switch-slot.ps1`

Alterna el tráfico de los Services `playhub-backend` y `playhub-frontend` entre los slots `blue` y `green`, cambiando el selector `slot` de cada Service.

Los accesos a Prometheus y Grafana siguen activos al cambiar de slot; el monitoreo descubre los pods de ambos slots.

### Qué hace, en orden

1. Verifica que `kubectl` esté disponible.
2. Obtiene el slot activo actual de `playhub-backend` y `playhub-frontend`, y valida que coincidan (si no, aborta con error de estado inconsistente).
3. Si el slot pedido ya está activo, informa y termina sin hacer nada.
4. Verifica que los Deployments del slot destino (`playhub-backend-<target>` y `playhub-frontend-<target>`) estén disponibles (rollout status).
5. Aplica un patch al selector del Service de backend, y luego al de frontend.
6. Si falla el patch del frontend, revierte automáticamente el patch del backend al slot anterior.
7. Muestra el estado final de ambos Services (slot activo por cada uno).

### Uso — Linux/macOS (Bash)

```bash
# Activar el slot Blue
./scripts/switch-slot.sh blue

# Activar el slot Green
./scripts/switch-slot.sh green
```

### Uso — Windows (PowerShell)

```powershell
# Activar el slot Blue
.\scripts\switch-slot.ps1 blue

# Activar el slot Green
.\scripts\switch-slot.ps1 green
```

> Importante: el slot destino (blue o green) debe estar previamente desplegado (ver `deploy.ps1 -DeployGreen` / `deploy.sh --deploy-green`) antes de poder activarlo con `switch-slot`.

### Después de cambiar de slot

Si los port-forward fueron iniciados por `deploy.sh`/`deploy.ps1` (existen `logs/port-forward-backend.pid` y `logs/port-forward-frontend.pid`), `switch-slot` los reinicia automáticamente para que apunten al nuevo slot. Si en cambio estás usando un `kubectl port-forward` manual (por fuera de esos scripts), debés detenerlo y reiniciarlo vos mismo luego de un `switch-slot`.

## `cleanup.sh` / `cleanup.ps1`

Retira la aplicación, el monitoreo, los exporters y sus permisos RBAC, y detiene los cuatro port-forward que registró el despliegue. Conserva por defecto los PVC de PostgreSQL, Prometheus y Grafana. `--delete-data` / `-DeleteData` elimina los tres PVC y sus datos. La limpieza conserva los archivos locales `secret.yaml` y `secret.yaml.example`.

```bash
./scripts/cleanup.sh --dry-run
./scripts/cleanup.sh
```

```powershell
.\scripts\cleanup.ps1 -WhatIf
.\scripts\cleanup.ps1
```

## `demo-monitoring.sh` / `demo-monitoring.ps1`

Genera tráfico real contra la API de PlayHub para alimentar los dashboards de
Grafana y verificar que la demo de monitoreo produce datos. Usa solamente
`curl`; la versión Bash requiere también Python 3 para leer JSON y Bash 4+
(usa `mapfile` y `shuf`). Funciona como smoke test: sale con código
0 solo si las métricas clave aumentaron en Prometheus.

### Qué hace, en orden

1. Opcionalmente ejecuta `deploy.sh` / `deploy.ps1` con la flag `--deploy` /
   `-Deploy` (acepta `--deploy-green` / `-DeployGreen` y `--cluster-type` /
   `-ClusterType`).
2. Espera a que el backend (`/actuator/health`), el frontend y Prometheus
   respondan; aborta con código 2 si el backend o Prometheus no están disponibles.
   Si el frontend no responde, avisa y omite su tráfico. Consulta el estado
   del target `playhub-backend`; exige que esté `UP` al finalizar.
3. Lee las métricas base en Prometheus (`failed_logins_total`,
   `total_purchases_total`, `total_earnings_currency_units_total`,
   `http_server_requests_seconds_count`).
4. Genera tráfico: logins fallidos, registro e ingreso de usuarios sintéticos,
   lecturas de catálogo, carritos con compras (alimenta las métricas de
   compras y ganancias), wishlist, y errores 4xx (404/400/403).
5. Aplica una ráfaga de carga concurrente contra backend y frontend para mover
   CPU, RAM y red de los workloads y del nodo.
6. Desactiva los usuarios sintéticos con el administrador (salvo
   `--keep-users` / `-KeepUsers`; usa emails únicos por corrida, por lo que no
   es necesario limpiar entre ejecuciones).
7. Espera hasta `--timeout` / `-TimeoutSec` segundos a que Prometheus recolecte
   las métricas nuevas (el scrape no es inmediato), imprime la tabla antes/después con los
   deltas y los enlaces a los dashboards. Verifica: logins fallidos >= 15,
   compras >= 1, requests >= 200 y target UP.

### Uso — Linux/macOS (Bash)

```bash
# Con la aplicación ya desplegada
./scripts/demo-monitoring.sh

# Desplegar primero y generar tráfico
./scripts/demo-monitoring.sh --deploy --deploy-green

# Más carga
./scripts/demo-monitoring.sh --synthetic-users 10 --burst-seconds 60 --burst-concurrency 12
```

### Uso — Windows PowerShell

```powershell
# Con la aplicación ya desplegada
.\scripts\demo-monitoring.ps1

# Desplegar primero y generar tráfico
.\scripts\demo-monitoring.ps1 -Deploy -DeployGreen

# Más carga
.\scripts\demo-monitoring.ps1 -SyntheticUsers 10 -BurstSeconds 60 -BurstConcurrency 12
```

### Opciones principales

```text
--deploy / -Deploy              Ejecuta el deploy antes de generar tráfico.
--deploy-green / -DeployGreen   Pasa la opción de Green al deploy.
--api-url / -ApiUrl             Backend (default: http://localhost:8080).
--frontend-url / -FrontendUrl   Frontend (default: http://localhost:5745).
--prometheus-url / -PrometheusUrl  Prometheus (default: http://localhost:9090).
--synthetic-users / -SyntheticUsers  Usuarios sintéticos (default: 5).
--burst-seconds / -BurstSeconds     Duración de la ráfaga (default: 30).
--burst-concurrency / -BurstConcurrency  Workers (default: 8).
--timeout / -TimeoutSec        Espera de disponibilidad y métricas (default: 180 s).
--keep-users / -KeepUsers       No desactiva los usuarios sintéticos.
--skip-frontend / -SkipFrontend No genera tráfico contra el frontend.
```

Los valores de usuarios, duración, concurrencia y timeout deben ser enteros
positivos. Cada corrida guarda sus cookies y contadores de carga en un directorio
único dentro de `logs/`; no borra los archivos de otras corridas. La comprobación
del frontend sigue las redirecciones HTTP. Si el frontend no responde se omite
su tráfico y continúa la prueba del backend.

En Windows PowerShell 5.1, el script envía el JSON a `curl.exe` mediante archivos
temporales UTF-8 para conservar las comillas. Tanto 5.1 como PowerShell 7 están
soportados. Una consulta inválida de Prometheus o una limpieza incompleta produce
un resultado fallido.
La versión Bash puede usarse también desde Git Bash en Windows: normaliza los
finales de línea al leer JSON. Ambas versiones exigen al menos una compra
confirmada por su propia corrida, además del incremento observado en Prometheus.

Códigos de salida: `0` para demo verificada, `1` para verificaciones fallidas
y `2` para requisitos o servicios imprescindibles no disponibles. Los argumentos
inválidos se rechazan antes de generar tráfico.

Ver [monitoring/README.md](../monitoring/README.md) para más detalles sobre la
demo de monitoreo.

## Flujo típico de despliegue Blue/Green

```bash
# 1. Desplegar Blue (activo) y Green en paralelo
./scripts/deploy.sh --deploy-green

# 2. Probar el slot Green por separado (por ejemplo, con port-forward directo al deployment green)

# 3. Cuando esté validado, activar Green
./scripts/switch-slot.sh green

# 4. Si algo falla, volver a Blue
./scripts/switch-slot.sh blue
```
