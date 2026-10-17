# Grafana y Prometheus

Servicios con almacenamiento persistente. En Kubernetes, Prometheus recolecta
métricas de infraestructura y del backend; Grafana incluye la fuente de datos y
los dashboards de infraestructura y contadores. En Docker Compose, Prometheus
comienza sin objetivos de recolección y Grafana sin fuentes de datos ni dashboards.

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

### Persistencia y dashboards exportados

En Kubernetes, los dashboards versionados se cargan automáticamente en la carpeta
**PlayHub** a partir de los JSON incluidos en el ConfigMap
`playhub-grafana-resource-dashboards` de `k8s/monitoring/grafana-config.yaml`.
Los archivos de `monitoring/grafana/dashboards/` conservan las exportaciones;
al modificar un dashboard, actualizar también su contenido en el ConfigMap.

Para agregar o actualizar uno:

1. En Grafana, exportar como código/JSON, modelo **Classic**. Para esta instalación,
   dejar desactivada la opción de compartir con otra instancia. Conservar un `uid`
   único y estable, y dejar `id` nulo o ausente. Las referencias a Prometheus deben
   usar el UID `playhub-prometheus`.
2. Guardar el archivo `.json` en `monitoring/grafana/dashboards/`.
3. Copiar también su contenido al campo `data` del ConfigMap de dashboards, bajo
   una clave como `mi-dashboard.json: |`. La clave debe tener dos espacios de
   indentación y las líneas del JSON al menos cuatro, igual que los dashboards
   existentes.
4. Versionar los JSON y el ConfigMap. Ejecutar el deploy habitual o aplicar
   `kubectl apply -f k8s/monitoring/`. Grafana revisa los archivos cada 30 segundos;
   Kubernetes también necesita propagar primero la actualización del ConfigMap al pod.

Revisar la indentación del YAML: una clave mal alineada puede introducir un
dashboard dentro del contenido de otro y dejar ambos sin cargar.

Los dashboards creados o importados y guardados desde la interfaz se almacenan
en la base de Grafana, dentro de `/var/lib/grafana`. Kubernetes conserva esa base
en el PVC `playhub-grafana-data`.
Recrear pods reutilizando ese volumen conserva los datos.
La limpieza normal (`cleanup.ps1` / `cleanup.sh`) también conserva el PVC.
`-DeleteData`, `--delete-data` o eliminar el clúster y
su almacenamiento destruyen esos datos; los dashboards versionados se pueden
reconstruir desde los JSON en el siguiente despliegue.

Los dashboards provisionados tienen `allowUiUpdates: false`: sus cambios deben
exportarse y guardarse en el repositorio siguiendo los pasos anteriores.
Exportar solo descarga una copia; Grafana no la agrega al despliegue automáticamente.

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
