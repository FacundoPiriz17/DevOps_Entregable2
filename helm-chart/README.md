# Despliegue con Kubernetes + Helm

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

Debe mostrar la versión instalada, por ejemplo algo así:

```
version.BuildInfo{Version:"v4.3.2", GitCommit:"8346aaa55e7161f7c547212d0a87f01367976727", GitTreeState:"clean", GoVersion:"go1.27.4", KubeClientVersion:"v1.37"}
```

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

Para levantarlo sin reconstruir las imágenes, se puede utilizar el siguiente comando:

```powershell
.\scripts\deploy-helm.ps1 -SkipBuild
```

```bash
scripts/deploy-helm.sh --skip-build
```

**Entorno prod** (requiere credenciales):
```powershell
.\scripts\deploy-helm.ps1 -Environment prod -DbPassword DB_PASSWORD -JwtSecret JWT_SECRET_DE_32_CARACTERES_O_MAS -AdminPassword ADMIN_PASSWORD
```
```bash
scripts/deploy-helm.sh --environment prod --db-password DB_PASSWORD --jwt-secret JWT_SECRET_DE_32_CARACTERES_O_MAS --admin-password ADMIN_PASSWORD
```

Estos datos se van a encontrar en el `.env` que se haya creado.

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
.\scripts\cleanup-helm.ps1 -DeleteNamespace
```

```bash
scripts/cleanup-helm.sh --delete-namespace
```

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

Ambos deben salir vacíos.