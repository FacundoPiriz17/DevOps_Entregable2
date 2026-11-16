# PlayHub - DevOps Entregable 1

Proyecto académico de una tienda de videojuegos, con backend en Spring Boot, frontend en Next.js y base de datos PostgreSQL.

Incluye migraciones versionadas con Flyway, autenticación mediante JWT, contenedores Docker y despliegue en Kubernetes utilizando una estrategia Blue/Green.

La aplicación está compuesta por:

- **Frontend:** Next.js
- **Backend:** Spring Boot
- **Base de datos:** PostgreSQL
- **Migraciones:** Flyway
- **Autenticación:** JWT
- **Contenedores:** Docker
- **Orquestación:** Kubernetes
- **Cluster local:** Minikube
- **Estrategia de despliegue:** Blue/Green
- **Documentación técnica:** Doxygen

El proyecto incluye scripts para automatizar el despliegue, cambio de slot y limpieza del entorno Kubernetes tanto en **Windows PowerShell** como en **Linux/macOS**.

---

## Arquitectura

```text
                         ┌─────────────────────┐
                         │       Usuario       │
                         └──────────┬──────────┘
                                    │
                                    ▼
                         ┌─────────────────────┐
                         │  Frontend - Next.js │
                         │      Puerto 5745    │
                         └──────────┬──────────┘
                                    │
                              HTTP / REST
                                    │
                                    ▼
                       ┌─────────────────────────┐
                       │ Backend - Spring Boot   │
                       │       Puerto 8080       │
                       │        JWT / JPA        │
                       └────────────┬────────────┘
                                    │
                                   JDBC
                                    │
                                    ▼
                         ┌─────────────────────┐
                         │     PostgreSQL      │
                         │       5432          │
                         └─────────────────────┘
```

En Kubernetes se mantienen dos slots independientes:

```text
                    ┌────────────────────┐
                    │   Service estable  │
                    └─────────┬──────────┘
                              │
                       selector: slot
                              │
               ┌──────────────┴──────────────┐
               │                             │
               ▼                             ▼
        ┌─────────────┐               ┌─────────────┐
        │    BLUE     │               │    GREEN    │
        │     v1      │               │     v2      │
        └─────────────┘               └─────────────┘
```

El cambio Blue/Green se realiza modificando el selector `slot` de los Services estables de frontend y backend.

---

## Requisitos previos

### Aplicación local

- [Docker](https://www.docker.com/)
- Docker Compose

### Kubernetes

- [Docker](https://www.docker.com/)
- [Minikube](https://minikube.sigs.k8s.io/)
- `kubectl`

Comprobar las instalaciones:

```bash
docker --version
minikube version
kubectl version --client
```

---
# Levantar la aplicación:

## *Revisar README en scripts/README.md*
# Cómo probar la aplicación

## Frontend

Una vez expuesto el frontend:

```text
http://localhost:5745
```

Desde allí se pueden probar, según el rol:

- Registro e inicio de sesión.
- Catálogo de juegos.
- Carrito.
- Lista de deseados.
- Biblioteca.
- Administración de juegos.
- Administración de usuarios.

---

## Swagger UI

La documentación interactiva del backend está disponible en:

```text
http://localhost:8080/swagger-ui.html
```

PlayHub utiliza JWT para la autenticación.

Al iniciar sesión, el backend almacena el JWT en una cookie HttpOnly llamada:

```text
playhub_session
```

El backend también soporta autenticación mediante:

```http
Authorization: Bearer <token>
```

La aplicación web utiliza principalmente la cookie de sesión.

---

# Usuarios de prueba

La migración `V2__demo_data.sql` incluye los siguientes usuarios:

| Nombre | Email | Rol | Contraseña |
|---|---|---|---|
| Facundo | `facundo@playhub.test` | Administrador | `PlayHub123` |
| Santiago | `santiago@playhub.test` | Administrador | `PlayHub123` |
| Agostina | `agostina@playhub.test` | Usuario general | `PlayHub123` |
| Agustín | `agustin@playhub.test` | Usuario general | `PlayHub123` |

## Administradores

Permiten probar funcionalidades administrativas como:

- Gestión de juegos.
- Gestión de usuarios.
- Operaciones protegidas por rol administrador.

## Usuarios generales

Permiten probar:

- Catálogo.
- Biblioteca.
- Deseados.
- Carrito.
- Compra de juegos.

---

# Despliegue en Kubernetes con Minikube

## 1. Iniciar Minikube utilizando Docker

```bash
minikube start --driver=docker
```

Comprobar estado:

```bash
minikube status
```

Comprobar el contexto actual:

```bash
kubectl config current-context
```

Debería aparecer:

```text
minikube
```

Si fuera necesario:

```bash
kubectl config use-context minikube
```

Comprobar la conexión:

```bash
kubectl cluster-info
```

---

# Desplegar PlayHub

Los scripts de despliegue realizan automáticamente:

1. Validación de los manifiestos Kubernetes.
2. Construcción de las imágenes Docker.
3. Carga de las imágenes en el runtime del cluster.
4. Despliegue de PostgreSQL.
5. Espera hasta que PostgreSQL esté disponible.
6. Creación del ConfigMap con las migraciones SQL.
7. Ejecución del Job de Flyway.
8. Creación de los Services.
9. Despliegue del slot Blue.
10. Opcionalmente, despliegue del slot Green.
11. Verificación del estado de los Deployments.
12. Inicio automático de los `port-forward` del frontend y backend.

---

## Linux/macOS

Dar permisos de ejecución la primera vez:

```bash
chmod +x scripts/*.sh
```

### Desplegar solamente Blue

```bash
./scripts/deploy.sh --cluster-type minikube
```

### Desplegar Blue y Green

```bash
./scripts/deploy.sh --cluster-type minikube --deploy-green
```

---

## Windows PowerShell

### Desplegar solamente Blue

```powershell
.\scripts\deploy.ps1 -ClusterType minikube
```

### Desplegar Blue y Green

```powershell
.\scripts\deploy.ps1 -ClusterType minikube -DeployGreen
```

---

# Opciones adicionales de deploy

## Linux/macOS

Mostrar ayuda:

```bash
./scripts/deploy.sh --help
```

Opciones principales:

```text
--deploy-green
--cluster-type
--cluster-name
--frontend-api-url
--skip-build
--skip-image-load
--no-port-forward
```

Ejemplo:

```bash
./scripts/deploy.sh 
  --cluster-type minikube 
  --deploy-green 
  --frontend-api-url http://localhost:8080
```

### No iniciar port-forward automáticamente

```bash
./scripts/deploy.sh 
  --cluster-type minikube 
  --no-port-forward
```

---

## Windows PowerShell

Opciones equivalentes:

```text
-DeployGreen
-ClusterType
-ClusterName
-FrontendApiUrl
-SkipBuild
-SkipImageLoad
-NoPortForward
```

Ejemplo:

```powershell
.\scripts\deploy.ps1 `
  -ClusterType minikube `
  -DeployGreen `
  -FrontendApiUrl http://localhost:8080
```

---

# Port-forward

Por defecto, los scripts `deploy.sh` y `deploy.ps1` crean automáticamente:

```text
playhub-backend  -> localhost:8080
playhub-frontend -> localhost:5745
```

Por lo tanto, después de ejecutar `deploy` normalmente **no es necesario ejecutar manualmente `kubectl port-forward`**.

Los PID y logs de estos procesos se almacenan en:

```text
logs/port-forward-backend.pid
logs/port-forward-backend.log

logs/port-forward-frontend.pid
logs/port-forward-frontend.log
```

---

## Port-forward manual

Solo es necesario si el despliegue se realizó con:

### Linux/macOS

```text
--no-port-forward
```

### PowerShell

```text
-NoPortForward
```

En ese caso:

```bash
kubectl port-forward service/playhub-backend 8080:8080
```

y en otra terminal:

```bash
kubectl port-forward service/playhub-frontend 5745:5745
```

---

# Estrategia Blue/Green

PlayHub mantiene dos slots independientes para frontend y backend:

| Slot | Backend | Frontend | Imagen |
|---|---|---|---|
| Blue | `playhub-backend-blue` | `playhub-frontend-blue` | `v1.0` |
| Green | `playhub-backend-green` | `playhub-frontend-green` | `v2.0` |

Los Services estables son:

```text
playhub-backend
playhub-frontend
```

Inicialmente apuntan a:

```yaml
slot: blue
```

Para activar Green se modifica el selector a:

```yaml
slot: green
```

Esto permite cambiar el tráfico sin cambiar la URL utilizada por los clientes.

> **Nota:** los tags `v1.0` y `v2.0` representan imágenes independientes para los slots Blue y Green. Si ambas imágenes se construyen durante la misma ejecución de `deploy`, pueden contener el mismo código fuente. Para demostrar un cambio real de versión se debe construir cada imagen desde la versión correspondiente del código.

---

# Cambiar de slot

> **Importante:** el slot destino debe estar desplegado previamente. Para utilizar Green primero se debe ejecutar `deploy` con `-DeployGreen` o `--deploy-green`.

## Activar Green

### Linux/macOS

```bash
./scripts/switch-slot.sh green
```

### Windows PowerShell

```powershell
.\scripts\switch-slot.ps1 green
```

---

## Volver a Blue

### Linux/macOS

```bash
./scripts/switch-slot.sh blue
```

### Windows PowerShell

```powershell
.\scripts\switch-slot.ps1 blue
```

---

## Verificar el slot activo

```bash
kubectl get service playhub-backend playhub-frontend \
  -o custom-columns='SERVICE:.metadata.name,SLOT:.spec.selector.slot'
```

Ejemplo:

```text
SERVICE             SLOT
playhub-backend     blue
playhub-frontend    blue
```

---

# Port-forward después de un switch

Si los `port-forward` fueron creados por `deploy.sh` o `deploy.ps1`, los scripts `switch-slot` los reinician automáticamente para que apunten a los Pods del nuevo slot.

Por lo tanto, normalmente **no es necesario reiniciarlos manualmente**.

Solo será necesario hacerlo si fueron creados manualmente fuera de los scripts.

---

# Migraciones con Flyway

Las migraciones se encuentran en:

```text
backend/src/main/resources/db/migration/
```

Actualmente existen:

```text
V1__init.sql
V2__demo_data.sql
```

Durante el despliegue Kubernetes:

1. Los scripts crean el ConfigMap:

```text
playhub-migration-sql
```

2. Los archivos SQL son montados dentro del contenedor Flyway.

3. Se ejecuta el Job:

```text
playhub-migrations
```

4. Flyway aplica automáticamente las migraciones pendientes.

Comprobar el Job:

```bash
kubectl get jobs
```

Ver logs:

```bash
kubectl logs job/playhub-migrations
```

Describir el Job:

```bash
kubectl describe job playhub-migrations
```

Flyway está deshabilitado dentro del backend desplegado en Kubernetes mediante:

```text
SPRING_FLYWAY_ENABLED=false
```

De esta manera, la responsabilidad de ejecutar migraciones queda separada del arranque de la aplicación.

---

# PostgreSQL

PostgreSQL se despliega mediante:

```text
playhub-postgres
```

El Service utilizado por el backend es:

```text
playhub-db
```

Puerto interno:

```text
5432
```

La base utiliza un PersistentVolumeClaim:

```text
playhub-postgres-data
```

con:

```text
2Gi
```

de almacenamiento solicitado.

Comprobar:

```bash
kubectl get deployment playhub-postgres
kubectl get service playhub-db
kubectl get pvc
```

---

# Comprobar el despliegue

Después de ejecutar `deploy`:

```bash
kubectl get pods
```

```bash
kubectl get deployments
```

```bash
kubectl get services
```

```bash
kubectl get jobs
```

```bash
kubectl get pvc
```

También se puede utilizar:

```bash
kubectl get all
```

---

# Diagnóstico

## Ver Pods

```bash
kubectl get pods -o wide
```

## Describir un Pod

```bash
kubectl describe pod <nombre-pod>
```

## Logs del backend Blue

```bash
kubectl logs deployment/playhub-backend-blue
```

## Logs del backend Green

```bash
kubectl logs deployment/playhub-backend-green
```

## Logs del frontend Blue

```bash
kubectl logs deployment/playhub-frontend-blue
```

## Logs del frontend Green

```bash
kubectl logs deployment/playhub-frontend-green
```

## Logs de PostgreSQL

```bash
kubectl logs deployment/playhub-postgres
```

## Eventos Kubernetes

```bash
kubectl get events --sort-by=.lastTimestamp
```

---

# Limpieza del entorno

El proyecto incluye scripts para eliminar exclusivamente los recursos Kubernetes pertenecientes a PlayHub.

Por defecto, el PVC de PostgreSQL se conserva para no perder los datos.

---

## Windows PowerShell

### Limpiar recursos manteniendo PostgreSQL

```powershell
.\scripts\cleanup.ps1
```

### Eliminar también los datos de PostgreSQL

```powershell
.\scripts\cleanup.ps1 -DeleteData
```

### Eliminar datos e imágenes Docker/Minikube

```powershell
.\scripts\cleanup.ps1 -DeleteData -RemoveImages
```

---

## Linux/macOS

### Limpiar recursos manteniendo PostgreSQL

```bash
./scripts/cleanup.sh
```

### Eliminar también PostgreSQL

```bash
./scripts/cleanup.sh --delete-data
```

### Eliminar datos e imágenes

```bash
./scripts/cleanup.sh --delete-data --remove-images
```

### Simular la limpieza sin eliminar nada

```bash
./scripts/cleanup.sh --dry-run
```

> **Advertencia:** `-DeleteData` / `--delete-data` elimina el PersistentVolumeClaim `playhub-postgres-data` y, por lo tanto, los datos almacenados en PostgreSQL.

---

# Flujo recomendado para una demo

## 1. Iniciar Minikube

```bash
minikube start --driver=docker
```

---

## 2. Comprobar Minikube

```bash
minikube status
kubectl config current-context
```

---

## 3. Desplegar Blue y Green

### Windows

```powershell
.\scripts\deploy.ps1 -ClusterType minikube -DeployGreen
```

### Linux/macOS

```bash
./scripts/deploy.sh --cluster-type minikube --deploy-green
```

Los port-forward del backend y frontend se crearán automáticamente.

---

## 4. Comprobar recursos

```bash
kubectl get pods
kubectl get services
kubectl get jobs
kubectl get pvc
```

Todos los Pods necesarios deberían encontrarse en estado:

```text
Running
```

y el Job:

```text
playhub-migrations
```

debería aparecer como:

```text
Complete
```

---

## 5. Abrir PlayHub

```text
http://localhost:5745
```

---

## 6. Abrir Swagger

```text
http://localhost:8080/swagger-ui.html
```

---

## 7. Iniciar sesión

Administrador:

```text
facundo@playhub.test
PlayHub123
```

Usuario general:

```text
agostina@playhub.test
PlayHub123
```

---

## 8. Verificar el slot activo

```bash
kubectl get service playhub-backend playhub-frontend \
  -o custom-columns='SERVICE:.metadata.name,SLOT:.spec.selector.slot'
```

Inicialmente debería mostrarse:

```text
blue
```

---

## 9. Cambiar a Green

### Windows

```powershell
.\scripts\switch-slot.ps1 green
```

### Linux/macOS

```bash
./scripts/switch-slot.sh green
```

Comprobar nuevamente:

```bash
kubectl get service playhub-backend playhub-frontend \
  -o custom-columns='SERVICE:.metadata.name,SLOT:.spec.selector.slot'
```

Ahora debería aparecer:

```text
green
```

---

## 10. Mostrar rollback

Volver a Blue.

### Windows

```powershell
.\scripts\switch-slot.ps1 blue
```

### Linux/macOS

```bash
./scripts/switch-slot.sh blue
```

El tráfico vuelve inmediatamente al slot anterior sin cambiar las URLs utilizadas por el cliente.

---

# Estructura Kubernetes

Los manifiestos se encuentran en:

```text
k8s/
```

Incluyen:

```text
configmap.yaml
secret.yaml

postgres-pvc.yaml
postgres-service.yaml
postgres-deployment.yaml

migration-job.yaml

backend-service.yaml
backend-blue-deployment.yaml
backend-green-deployment.yaml

frontend-service.yaml
frontend-blue-deployment.yaml
frontend-green-deployment.yaml
```

---

# Scripts

Los scripts están disponibles en:

```text
scripts/
```

## Despliegue

```text
deploy.sh
deploy.ps1
```

## Cambio Blue/Green

```text
switch-slot.sh
switch-slot.ps1
```

## Limpieza

```text
cleanup.sh
cleanup.ps1
```

Existe documentación adicional sobre los scripts en:

```text
scripts/README.md
```

---

# Escenarios BDD

La carpeta:

```text
features/
```

contiene especificaciones Gherkin utilizadas para describir los principales comportamientos del sistema.

Incluyen escenarios relacionados con:

- Autenticación.
- Catálogo.
- Biblioteca.
- Carrito.
- Deseados.
- Administración de usuarios.
- Administración de juegos.

---

# Documentación con Doxygen

El proyecto incluye:

```text
Doxyfile
```

Para generar la documentación:

```bash
doxygen Doxyfile
```

La documentación se genera en:

```text
docs/generated/html/
```

La página principal puede abrirse desde:

```text
docs/generated/html/index.html
```

El Doxyfile procesa documentación de:

```text
README.md
docs/
backend/src/main/java/
frontend/src/
```

---

# Resumen de puertos en Kubernetes

| Componente | Puerto |
|---|---:|
| Frontend | `5745` |
| Backend | `8080` |
| PostgreSQL | `5432` |

Con los port-forward automáticos:

```text
http://localhost:5745
http://localhost:8080
```

---

# Resumen rápido

### Iniciar Minikube

```bash
minikube start --driver=docker
```

### Deploy Blue + Green

Windows:

```powershell
.\scripts\deploy.ps1 -ClusterType minikube -DeployGreen
```

Linux/macOS:

```bash
./scripts/deploy.sh --cluster-type minikube --deploy-green
```

### Activar Green

Windows:

```powershell
.\scripts\switch-slot.ps1 green
```

Linux/macOS:

```bash
./scripts/switch-slot.sh green
```

### Rollback a Blue

Windows:

```powershell
.\scripts\switch-slot.ps1 blue
```

Linux/macOS:

```bash
./scripts/switch-slot.sh blue
```

### Limpiar

Windows:

```powershell
.\scripts\cleanup.ps1
```

Linux/macOS:

```bash
./scripts/cleanup.sh
```
