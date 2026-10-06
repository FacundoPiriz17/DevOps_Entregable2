# Grafana y Prometheus

Servicios base con almacenamiento persistente. Prometheus comienza sin objetivos
de recolección. Grafana comienza sin fuentes de datos ni dashboards.

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
Estos manifiestos se aplican por separado de los scripts de despliegue de la aplicación.

Para acceder, ejecutar cada comando en una terminal distinta:

```bash
kubectl port-forward service/playhub-prometheus 9090:9090
kubectl port-forward service/playhub-grafana 3000:3000
```

Grafana utiliza inicialmente el usuario `admin` y la contraseña `admin`, y solicita
cambiarla al iniciar sesión por primera vez. Los datos se conservan en los volúmenes.
