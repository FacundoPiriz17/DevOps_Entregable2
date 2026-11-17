# Despliegue con Kubernetes + Helm

Esta guía amplía el [README principal](../README.md). Para las opciones de los scripts, seguridad compartida, tráfico automático y limpieza completa, consultar [scripts/README.md](../scripts/README.md). Los comandos de este documento se ejecutan desde la raíz del repositorio.

## ¿Qué es Helm Chart?

**Helm** es el gestor de paquetes de Kubernetes. Un **Helm Chart** es un paquete de plantillas YAML (Deployments, Services, ConfigMaps, etc.) más un archivo de valores configurables, siendo que en vez de mantener varios manifiestos casi iguales, el chart se escribe una sola vez y se adapta a cada entorno cambiando solo los valores.

Cada instalación de un chart es un **release**, o sea que Helm lo registra, guarda su historial de revisiones y permite actualizarlo (`helm upgrade`), volver atrás (`helm rollback`) o eliminarlo completo (`helm uninstall`) con un solo comando.

En este proyecto, chart despliega **PlayHub**, que tiene frontend (Next.js), backend (Spring Boot) y PostgreSQL.

## Instalación de Helm Chart

Para usar el chart hace falta tener instalada la herramienta **Helm**, además de Docker, Minikube y `kubectl`.

### Requisitos previos

- **Docker Desktop** abierto.
- Minikube iniciado: `minikube start`
- **kubectl** instalado.
- **Python 3** disponible para las utilidades de seguridad y limpieza utilizadas por los scripts.

### Instalar Helm con el script

Desde la raíz del proyecto (la carpeta que contiene `scripts/`, `helm-chart/`, `backend/` y `frontend/`):

**Windows (PowerShell):**
```powershell
.\scripts\install-helm.ps1
```

**Linux / macOS:**
```bash
chmod +x scripts/install-helm.sh
./scripts/install-helm.sh
```

El script descarga el binario oficial desde `get.helm.sh`, verifica su SHA256 y lo copia a una carpeta del usuario (no requiere permisos de administrador). Si Helm ya está instalado, no hace nada. En Windows, abre una ventana nueva de PowerShell si `helm` no se reconoce en las que ya tenías abiertas.

**Opciones:** `-Version vX.Y.Z` (`--version` en bash) para elegir otra versión y `-Force` (`--force`) para reinstalar.

### Comprobar la instalación

```
helm version
```

Debe mostrar la versión instalada. El instalador incluido tiene `v4.3.1` como valor predeterminado y permite cambiarlo con sus parámetros; la salida depende del binario realmente instalado.

## Levantar proyecto

La forma recomendada para levantar el proyecto es utilizando los **scripts**, teniendo que escribir lo siguiente en la terminal:

```powershell
.\scripts\deploy-helm.ps1
```

```bash
scripts/deploy-helm.sh
```

El script construye las imágenes, las carga en Minikube, valida el chart (`helm lint`), instala o actualiza el release en el namespace `playhub-helm`, ejecuta `helm test` y abre los `port-forward`. Al terminar muestra:

```
Frontend disponible en: http://localhost:5745
Backend disponible en: http://localhost:8080/actuator/health
```

También instala por defecto Kyverno, sus políticas y Falco. Si existe un stack compartido sin marcador de PlayHub, puede requerir `-SkipSecurity` / `--skip-security` o la adopción explícita de una instalación compatible. Ver la distinción en la guía de scripts. Los accesos de monitoreo son Prometheus en `http://localhost:9090` y Grafana en `http://localhost:3000`.

Para levantarlo sin reconstruir las imágenes, se puede utilizar el siguiente comando:

```powershell
.\scripts\deploy-helm.ps1 -SkipBuild
```

```bash
scripts/deploy-helm.sh --skip-build
```

**Entorno prod** (requiere credenciales):
```powershell
.\scripts\deploy-helm.ps1 -Environment prod -DbPassword $env:PLAYHUB_DB_PASSWORD -JwtSecret $env:PLAYHUB_JWT_SECRET -AdminPassword $env:PLAYHUB_ADMIN_PASSWORD
```
```bash
bash scripts/deploy-helm.sh --environment prod --db-password "$PLAYHUB_DB_PASSWORD" --jwt-secret "$PLAYHUB_JWT_SECRET" --admin-password "$PLAYHUB_ADMIN_PASSWORD"
```

Definir esas variables de entorno con credenciales propias antes de ejecutar los ejemplos. El JWT debe tener al menos **48 bytes UTF-8**. El script recibe los valores como parámetros y **no lee `.env`**. En `dev`, utiliza los valores de demostración del chart; en `prod`, el archivo de valores deja los secretos vacíos para exigir su provisión.

`values-prod.yaml` habilita el Ingress para `playhub.local`. El controlador Ingress, la resolución del hostname y, cuando corresponda al driver de Minikube, `minikube tunnel`, se preparan por separado. El script no instala ese controlador. El acceso y las imágenes deben adaptarse al entorno antes de considerar esta configuración un despliegue de producción.

## Eliminar proyecto

La forma recomendada para eliminar el proyecto es utilizando los **scripts**, teniendo que escribir lo siguiente en la terminal:


```powershell
.\scripts\cleanup-helm.ps1
```

```bash
scripts/cleanup-helm.sh
```

El script cierra los `port-forward` del chart y desinstala el release. 

En caso de que también se quiera eliminar el namespace, se puede ejecutar lo siguiente: 

```powershell
.\scripts\cleanup-helm.ps1 -DeleteData -DeleteNamespace
```

```bash
bash scripts/cleanup-helm.sh --delete-data --delete-namespace
```

Eliminar el namespace requiere eliminar también los datos de sus PVC. Estas opciones borran los datos de PostgreSQL, Prometheus y Grafana; la limpieza normal los conserva.

Si también se quiere eliminar el las imágenes de minikube y docker, se puede ejecutar lo siguiente: 

```powershell
.\scripts\cleanup-helm.ps1 -RemoveImages
```

```bash
scripts/cleanup-helm.sh --remove-images
```

Y si solamente se quiere saber qué haría el script sin ejecutarlo, se puede escribir lo siguiente:

```powershell
.\scripts\cleanup-helm.ps1 -WhatIf
```

```bash
scripts/cleanup-helm.sh --dry-run
```

Ninguno de estos scripts toca el despliegue de `deploy.ps1` / `deploy.sh` (namespace `default`).

### Comprobar que quedó limpio

```powershell
helm list -n playhub-helm
kubectl get all -n playhub-helm
```

El release debe dejar de aparecer. Después de una limpieza normal pueden seguir presentes los PVC conservados; `kubectl get all` no enumera PVC. Comprobarlos con `kubectl get pvc -n playhub-helm`. Si también se eliminó el namespace, la consulta puede indicar que ya no existe.

## Comandos complementarios de Helm

Los siguientes comandos permiten revisar el chart sin construir ni desplegar la aplicación:

```bash
helm lint ./helm-chart -f ./helm-chart/values-dev.yaml
helm template playhub ./helm-chart -n playhub-helm -f ./helm-chart/values-dev.yaml
```

`helm template` incluye el Secret del chart en la salida; evitar guardar o compartir un render con credenciales reales.

La instalación manual es una **alternativa** al script, no un paso posterior sobre un release ya instalado. Requiere las imágenes disponibles en el runtime del clúster, la seguridad preparada y una StorageClass:

```bash
bash scripts/install-kyverno.sh
bash scripts/deploy-falco.sh
helm install playhub ./helm-chart -n playhub-helm --create-namespace -f ./helm-chart/values-dev.yaml --wait --timeout 5m
helm test playhub -n playhub-helm
```

Si se omitió el script de despliegue, esta instalación manual no construye ni carga imágenes y no abre port-forward. Los comandos de acceso manual están en [scripts/README.md](../scripts/README.md).

Para consultar un release existente:

```bash
helm status playhub -n playhub-helm
helm history playhub -n playhub-helm
kubectl get pods,svc,pvc -n playhub-helm
```

### Parámetros configurables

| Archivo o valor | Uso |
| --- | --- |
| `values.yaml` | Valores base del chart, imágenes, puertos, recursos, credenciales de demostración y monitoreo. |
| `values-dev.yaml` | Ajustes para desarrollo local. |
| `values-prod.yaml` | Dos réplicas de aplicación, mayores recursos, almacenamiento e Ingress; requiere credenciales. |
| `backend` / `frontend` | Imagen, réplicas, puerto de contenedor, Service y recursos. |
| `postgres.persistence` | Activación, tamaño, StorageClass y retención del volumen. |
| `monitoring.enabled` | Incluir Prometheus, Grafana y exporters. |
| `monitoring.persistence.retain` | Conservar los PVC de monitoreo al desinstalar. |
| `monitoring.nodeExporter.port` | Puerto explícito o `0` para calcularlo por release y namespace. |
| `secrets.existingSecret` | Utilizar un Secret preexistente con las claves requeridas por el chart. |

Las plantillas incluyen Deployments, Services, ConfigMap, Secret, PVC, migraciones e Ingress opcional. El hook `helm test` comprueba readiness del backend y `/login` del frontend. La configuración de métricas y los JSON de dashboards se explican en [docs/monitoring.md](../docs/monitoring.md).
