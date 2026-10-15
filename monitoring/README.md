# Grafana y Prometheus

Servicios con almacenamiento persistente. En Kubernetes, Prometheus recolecta
métricas de infraestructura y del backend; Grafana incluye la fuente de datos y
los dashboards de infraestructura. En Docker Compose, Prometheus comienza sin
objetivos de recolección y Grafana sin fuentes de datos ni dashboards.

## Docker Compose

Con el archivo `.env` de la aplicación completo, desde la raíz del repositorio:

```bash
docker compose up -d prometheus grafana
```

- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000

También se incluyen al ejecutar `docker compose up -d` para toda la aplicación.

## Kubernetes

Desde la raíz del repositorio, con el contexto apuntando al cluster deseado:

```bash
kubectl apply -f k8s/monitoring/
kubectl rollout status deployment/playhub-prometheus --timeout=180s
kubectl rollout status deployment/playhub-grafana --timeout=180s
```

El cluster debe disponer de una StorageClass predeterminada para los PVC.
Los scripts de despliegue de la aplicación también aplican estos manifiestos y
reinician Prometheus para cargar los cambios de configuración.

### Scraping del backend

El job `playhub-backend` consulta `http://playhub-backend:8080/actuator/prometheus`
cada 15 segundos. El servicio apunta al slot activo de Blue/Green. Este endpoint
permite `GET` sin JWT; la API mantiene su autenticación habitual.

Al cambiar el código Java o las dependencias, hay que reconstruir las imágenes,
cargarlas en el cluster y recrear los pods. Aplicar solamente los manifiestos de
monitoring no actualiza el backend. Por ejemplo, para Minikube desde PowerShell:

```powershell
.\scripts\deploy.ps1 -ClusterType minikube -DeployGreen
```

Este comando reconstruye y carga ambos slots. Para verificar esta corrección,
no utilizar `-SkipBuild` ni `-SkipImageLoad`.

Con el port-forward del backend activo, comprobar desde otra terminal:

```powershell
curl.exe -i http://localhost:8080/actuator/prometheus
```

Debe responder `200` con métricas en texto, incluyendo `failed_logins_total`.
En `http://localhost:9090/targets`, el job `playhub-backend` debe figurar `UP`.
Si todavía devuelve `401`, comprobar que el slot activo esté ejecutando la imagen
recién construida y probar sin encabezado `Authorization` ni cookies de sesión.

Para acceder, ejecutar cada comando en una terminal distinta:

```bash
kubectl port-forward service/playhub-prometheus 9090:9090
kubectl port-forward service/playhub-grafana 3000:3000
```

Grafana utiliza inicialmente el usuario `admin` y la contraseña `admin`, y solicita
cambiarla al iniciar sesión por primera vez. Los datos se conservan en los volúmenes.
