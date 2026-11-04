# Entregable 3 - DevSecOps:

## Seguridad en el codigo:

### NPM Audit:

En esta parte del entregable se realizo un escaneo utilizando la función de:

```bash
npm audit > reports/npm-audit.txt
```

Donde se creo el reporte en forma de archivo .txt mostrando las vulnerabilidades en los paquetes de npm.

En el mismo se encontraron 6 vulnerabilidades, 5 de ellas consideradas como "high" y una como critical. Las mismas consistinan en problemas de versión de NextJS.

**Decisión:** Se decidio ignorar estas vulnerabilidades, dado que arreglarlas consistiria en poner en riesgo el buen funcionamiento del app, por fallos en dependencias y problemas posibles con la imagen de docker.

### Análisis Semgrep

**Comando ejecutado:**

```bash
docker run --rm -e SEMGREP_APP_TOKEN=<token> -v "%cd%:/src" semgrep/semgrep semgrep ci
```

Se ejecutó Semgrep con login en la plataforma cloud, con los productos Code (SAST) y Supply Chain (SCA) habilitados. Se analizaron 202 archivos versionados en git. El escaneo finalizó con 49 hallazgos, ninguno bloqueante.

| Categoría                   | Cantidad |
| --------------------------- | -------- |
| Supply Chain – Reachable    | 6        |
| Supply Chain – Undetermined | 12       |
| Supply Chain – Unreachable  | 9        |
| Code (non-blocking)         | 22       |

**Limitación:** `backend/pom.xml` no fue analizado por Semgrep, por lo que las dependencias Java quedaron fuera del escaneo de Supply Chain.

#### Supply Chain

Los hallazgos de Supply Chain corresponden a los mismos problemas de versión de Next.js detectados por `npm audit`, junto con algunas dependencias transitivas (`sharp`, `js-yaml`, `brace-expansion`, `zod`, `source-map-js`). Los más relevantes, clasificados como _reachable_, son:

| Paquete | Severidad | Advisory            | Descripción                                       |
| ------- | --------- | ------------------- | ------------------------------------------------- |
| next    | Critical  | GHSA-2xp9-vwfh-vxw4 | RCE vía imagen AVIF maliciosa en `/_next/image`   |
| next    | High      | CVE-2026-94483      | SSRF por DNS rebinding en `/_next/image`          |
| next    | Critical  | CVE-2026-75604      | Path traversal en caché (solo servidores Windows) |
| sharp   | High      | GHSA-wq5f-xc86-pv6w | Use-after-free al decodificar SVG                 |
| js-yaml | High      | CVE-2026-84375      | DoS por consumo de CPU al parsear YAML            |

**Decisión:** se ignoraron estas vulnerabilidades, en línea con lo decidido en la sección de NPM Audit, dado que actualizar las dependencias pondría en riesgo el funcionamiento de la aplicación, por posibles fallos de dependencias y problemas con la imagen de Docker.

#### Code (SAST): 22 hallazgos non-blocking

**Hash de contraseñas en los inserts (severidad High):** el hallazgo principal se encontró en los inserts de demostración (`V2__demo_data.sql` y `02_inserts.sql`), donde los hashes bcrypt de 4 usuarios (`@playhub.test`) están cargados directamente junto con los datos. **Decisión:** se ignoró, ya que son datos de demostración del trabajo realizado y no corresponden a usuarios reales, por lo que no se compromete la confidencialidad.

**Archivos YAML (Kubernetes y monitoreo):** el resto de los hallazgos son de severidad moderada y corresponden a configuraciones de seguridad de contenedores (`runAsNonRoot`, `allowPrivilegeEscalation`, `hostPID`, `hostNetwork`, `privileged`) en los manifiestos de despliegue y de monitoreo. **Decisión:** se ignoraron por el momento, dado que serán evaluados con Kyverno y mitigados más adelante en caso de considerarse necesario.

## Actualización de dependencias y correcciones de seguridad (Trivy)

### Objetivo

Este fragmento resume las versiones detectadas en el escaneo inicial de Trivy y las versiones corregidas indicadas por el propio reporte. El objetivo es actualizar las dependencias vulnerables del frontend reconstruir las imágenes Docker para volver a escanearlas.

> **NOTA:** las versiones de la columna “Versión corregida” son los objetivos de actualización tomados del reporte de Trivy. Para considerar una corrección finalizada, hay que comprobar que la versión quedó instalada en el `package-lock.json` o en el artefacto Java y volver a ejecutar Trivy sobre la imagen reconstruida.

### Instalación de Trivy

Antes de realizar el análisis de vulnerabilidades, es necesario instalar **Trivy** en el sistema. Para ello, se puede utilizar Windows Package Manager (`winget`) ejecutando el siguiente comando en una terminal:

```powershell
winget install AquaSecurity.Trivy
```

Una vez finalizada la instalación, se puede comprobar que Trivy se haya instalado correctamente y consultar su versión mediante:

```powershell
trivy --version
```

### Frontend

Archivo de dependencias directas: `frontend/package.json`  
Archivo de bloqueo: `frontend/package-lock.json`

El reporte inicial del frontend (ubicado en la carpeta `../reports/trivyreports_frontend`) encontró **25 vulnerabilidades: 20 HIGH y 5 CRITICAL**.

| Dependencia          | Versión detectada | Versión corregida / objetivo | Observación                                                                                  |
| -------------------- | ----------------: | ---------------------------: | -------------------------------------------------------------------------------------------- |
| `next`               |            16.3.1 |                   **16.4.1** | Actualización principal para corregir los hallazgos CRITICAL y HIGH informados para Next.js. |
| `eslint-config-next` |            16.3.1 |                   **16.4.1** | Se alinea con la versión de Next.js.                                                         |

No se incluyen las dependencias transitivas debido a que son demasiadas y no están declaradas directamente en `package.json`. Estas dependencias son incorporadas automáticamente por npm a través de otras dependencias y sus versiones exactas quedan registradas en `package-lock.json`.

### Sincronización del lockfile

Después de modificar `package.json`, es necesario regenerar el archivo de bloqueo. Desde la carpeta `frontend`:

```bash
npm install
```

`npm install` actualiza `package-lock.json`.

### Verificación final

Después de actualizar las dependencias y reconstruir las imágenes, volver a ejecutar Trivy:

```bash
trivy image playhub-frontend:v2.0
```

La actualización se considera verificada cuando el nuevo reporte de Trivy ya no muestra los hallazgos HIGH y CRITICAL correspondientes a las versiones anteriores.

### Backend

Archivo principal de configuración: `backend/pom.xml`  
Imagen de ejecución: `backend/Dockerfile.prod`

El reporte inicial del backend encontró **14 vulnerabilidades en dependencias Java (10 HIGH y 4 CRITICAL)** y **1 vulnerabilidad CRITICAL en un paquete de Alpine Linux**.

| Dependencia / componente                   | Versión detectada | Versión corregida / objetivo | Dónde se gestiona                                                              |
| ------------------------------------------ | ----------------: | ---------------------------: | ------------------------------------------------------------------------------ |
| Spring Boot (`spring-boot-starter-parent`) |             4.1.1 |                    **4.1.2** | `backend/pom.xml`; actualización del BOM para gestionar versiones transitivas. |

La actualización de `spring-boot-starter-parent` a 4.1.2 se plantea para gestionar las versiones de las dependencias transitivas a través del BOM de Spring Boot. Esta versión gestiona Jackson 2.21.7, Jackson 3.1.7 y Tomcat 11.0.27. Después del cambio, conviene comprobar las versiones efectivamente resueltas por Maven.

Para el paquete del sistema operativo, se debe incorporar la actualización disponible de Alpine durante la construcción de la imagen. Por ejemplo, el siguiente comando permite actualizar específicamente `brotli-libs` a una versión corregida disponible en los repositorios:

```dockerfile
RUN apk upgrade --no-cache brotli-libs
```

### Verificación final

Después de actualizar las dependencias y reconstruir las imágenes, volver a ejecutar Trivy:

```bash
trivy image playhub-backend:v2.0
```

La actualización se considera verificada cuando el nuevo reporte de Trivy ya no muestra los hallazgos HIGH y CRITICAL correspondientes a las versiones anteriores.

## Seguridad en Kubernetes con Kyverno y KubeLinter

Esta parte del entregable incorpora tres políticas de admisión para impedir
imágenes `latest`, exigir recursos y evitar contenedores root. Las políticas
están en modo **Enforce**: Kubernetes rechaza las solicitudes que incumplen las
reglas. Los resultados reales se guardan en `reports/kyverno-validation.txt`
y `reports/kubelinter.txt`.

### Archivos

| Archivo                              | Propósito                                            |
| ------------------------------------ | ---------------------------------------------------- |
| `k8s/kyverno/disallow-latest.yaml`   | Prohibir `latest` explícito e implícito.             |
| `k8s/kyverno/require-resources.yaml` | Exigir requests y limits positivos de CPU y memoria. |
| `k8s/kyverno/disallow-root.yaml`     | Exigir ejecución sin root y prohibir UID 0.          |
| `tests/kyverno/valid-pod.yaml`       | Pod válido que ejecuta con UID 1000.                 |
| `tests/kyverno/invalid-pod.yaml`     | Pod que incumple las tres políticas.                 |
| `scripts/install-kyverno.ps1`        | Instalar Kyverno y aplicar las políticas.            |
| `scripts/validate-kyverno.ps1`       | Ejecutar las pruebas y guardar la evidencia.         |
| `scripts/lint-kubernetes.ps1`        | Ejecutar KubeLinter y guardar todos sus hallazgos.   |

Los ejemplos intencionalmente inválidos quedan fuera de `k8s/`, para evitar su
despliegue junto con la aplicación o confundirlos con los manifiestos analizados.

### Alcance de las políticas

Se utilizan `ClusterPolicy` de `kyverno.io/v1`, compatibles con Kyverno 1.19.2.
Esta versión conserva su soporte, aunque declara estas API obsoletas.
`background: true` habilita la evaluación de recursos existentes para informes;
esto no elimina ni reinicia los Pods que ya existían. Con
`allowExistingViolations: false`, sus futuras modificaciones también deben
cumplir las políticas.

Las reglas cubren todos los namespaces de aplicaciones, sin depender de un
label de habilitación. Se excluyen `kube-system`, `kube-public`, `kube-node-lease`
y `kyverno`, para preservar los componentes del clúster y la recuperación del
propio motor de admisión. Estas exclusiones son límites explícitos de esta
implementación: no se afirma que los Pods del sistema cumplan estas reglas.
También afectan a futuros Pods de otras aplicaciones en el mismo clúster.

### Imágenes

`disallow-latest` revisa todos los contenedores, initContainers y
ephemeralContainers. Rechaza tanto `busybox:latest` como `busybox`, porque una
imagen sin etiqueta utiliza `latest` de forma implícita. Un puerto de registro
no cuenta como etiqueta: `registry.example:5000/demo` también se rechaza.
Se aceptan etiquetas explícitas y referencias por digest. Esta regla no verifica
la existencia de la imagen ni sustituye el análisis de vulnerabilidades de Trivy.

Kyverno genera automáticamente reglas para los controladores habituales, como
Deployment, DaemonSet, Job y CronJob, a partir de esta regla de Pod.

### Recursos

`require-resources` exige valores mayores a cero en los cuatro campos de cada
contenedor e initContainer:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

Se valida el objeto que llega a admisión después de los valores predeterminados
de Kubernetes: un LimitRange, o el default de requests a partir de limits, puede
completar campos antes de la validación. Todos los manifiestos de PlayHub
declaran los cuatro valores explícitamente.

### Ejecución sin root

`disallow-root` calcula el contexto efectivo de cada contenedor, incluyendo
initContainers y ephemeralContainers. Exige `runAsNonRoot: true`, declarado en
el Pod o en el contenedor, y rechaza `runAsUser: 0`. Un contenedor no puede anular
la protección del Pod con `runAsNonRoot: false`. Si no se declara UID, el kubelet
hace cumplir `runAsNonRoot` al iniciar la imagen; los manifiestos de PlayHub
utilizan UID numérico explícito.

Se actualizaron los contextos de seguridad de backend y frontend Blue/Green,
PostgreSQL, Flyway, Grafana y Prometheus. Backend, frontend y Flyway utilizan
UID/GID 1000; PostgreSQL Alpine utiliza UID/GID 70 y `fsGroup: 70`; Grafana
conserva 472 y Prometheus 65534. Los demás exporters ya declaraban ejecución
sin root. El Job manual `scripts/flyway-repair.yaml` también recibió contexto
sin root y requests/limits.

En esta política se deshabilita la generación automática para controladores.
Se valida el **Pod creado por el controlador**, lo que permite identificar
exactamente la excepción de infraestructura siguiente. Por eso un Deployment
con configuración root puede crearse, pero sus Pods serán rechazados y el
Deployment no conseguirá réplicas disponibles. La validación del script extrae
los Pod templates para comprobar también este caso en los manifiestos reales.

### Excepción aprobada para cAdvisor

Se conserva cAdvisor para mantener las métricas de red del entregable anterior.
Necesita observar los procesos, namespaces de red y runtime del nodo, por lo que
su manifiesto mantiene UID 0, `privileged: true`, `hostPID` y montajes del host.

La única excepción adicional a la regla sin root exige simultáneamente:

- Namespace `default`.
- OwnerReference con `kind: DaemonSet`, `controller: true` y nombre
  `playhub-cadvisor-network`.
- Label `app: playhub-cadvisor-network`.

Un Pod que solo copie el label sigue siendo rechazado. La excepción no afecta
las reglas de imágenes ni recursos. Si se despliega cAdvisor en otro namespace,
será rechazado hasta revisar explícitamente este alcance.

Los metadatos de propietario no constituyen una frontera de autenticación:
alguien con permisos para crear Pods puede intentar imitarlos. Esta excepción
se acepta para el laboratorio administrado por el equipo. En un entorno
compartido debe limitarse por RBAC quién puede crear Pods y modificar workloads
de infraestructura y políticas; una alternativa es aislar la infraestructura en
un namespace administrado. No existe una excepción general para cualquier Pod
privilegiado o para todos los componentes de monitoreo.

### Instalación y ejecución

Requisitos: Docker en funcionamiento, un clúster accesible con `kubectl`, acceso
a Internet y permisos para instalar CRD, RBAC y webhooks. Los scripts se ejecutan
desde PowerShell. La validación se realizó en
Minikube con Kubernetes 1.35.1, Kyverno 1.19.2 y KubeLinter 0.8.3.

Las últimas versiones estables se verificaron el **2 de noviembre de 2026**
mediante los releases oficiales de GitHub y su API `releases/latest`:

| Herramienta                                                               | Versión estable utilizada |
| ------------------------------------------------------------------------- | ------------------------- |
| [Kyverno](https://github.com/kyverno/kyverno/releases/tag/v1.19.2)        | 1.19.2                    |
| [KubeLinter](https://github.com/stackrox/kube-linter/releases/tag/v0.8.3) | 0.8.3                     |

Desde la raíz del repositorio:

```powershell
docker desktop start
minikube start --driver=docker
kubectl config current-context
.\scripts\install-kyverno.ps1
.\scripts\validate-kyverno.ps1
.\scripts\lint-kubernetes.ps1
```

El instalador descarga el manifiesto de la versión oficial fijada y utiliza
`kubectl apply --server-side`, para evitar el límite de anotaciones de los CRD
grandes. Espera que los cuatro controladores estén disponibles y que las tres
políticas indiquen `Ready`.

### Validación y evidencia

El script guarda los comandos, respuestas del API server, códigos de salida y
comprobaciones en `reports/kyverno-validation.txt`. Un rechazo solo cuenta como
correcto si proviene del webhook y menciona la política esperada; un error de
conexión, sintaxis o descarga no se considera evidencia de bloqueo.

Las pruebas cubren etiquetas explícitas e implícitas, digest, puertos de
registro, recursos ausentes y cero, UID 0, herencia y sobrescritura del contexto
de seguridad, un segundo contenedor, initContainers, los Pod templates del
proyecto y la excepción de cAdvisor. También se comprueba el subrecurso real
`pods/ephemeralcontainers` con operaciones `dryRun=All`.

Para comprobar los Pod templates sin instalar toda la aplicación, se utiliza
el ServiceAccount `default` en los Pods sintéticos de prueba y se incluyen los
metadatos de propietario de los DaemonSets. Es una prueba de admisión de sus
imágenes, recursos y contexto de seguridad; no verifica la construcción de las
imágenes, la disponibilidad de ConfigMaps/PVC ni el arranque de PlayHub.

Además de los dry-run, se intenta **crear realmente** el manifiesto no conforme:

```powershell
kubectl create namespace kyverno-validation
kubectl create -f tests/kyverno/invalid-pod.yaml
```

Si el namespace ya existe, se omite su creación. La segunda orden debe devolver
un código distinto de cero y mencionar las tres políticas:

```text
admission webhook "validate.kyverno.svc-fail" denied the request
disallow-latest
disallow-root
require-resources
```

El Pod inválido no llega a persistirse. El script también crea el Pod válido,
espera a que esté `Ready`, ejecuta `id -u` y verifica el valor **1000**. Al
terminar elimina únicamente el Pod válido que creó; deja el namespace de pruebas
para repetir la demo. Si ese Pod ya existe, falla sin sobrescribirlo.

La evidencia entregada corresponde a la ejecución del script, no a salidas de
ejemplo: **38 comprobaciones correctas**, incluyendo los 13 Pod templates del
proyecto, el rechazo real del Pod inválido y la ejecución del válido con UID 1000. Para repetir la demostración:

```powershell
.\scripts\validate-kyverno.ps1
Get-Content reports/kyverno-validation.txt
```

### Resultado de KubeLinter

El informe solicitado está en **`reports/kubelinter.txt`**, relativo a la raíz
del repositorio. El script utiliza la imagen oficial fijada y conserva stdout,
stderr y el código de salida. Analiza `k8s/` recursivamente y el Job manual de
reparación de Flyway, con todos los checks predeterminados y sin supresiones.
KubeLinter es un análisis estático; el comportamiento de las políticas de
Kyverno se verifica por separado mediante admisión real.

```powershell
.\scripts\lint-kubernetes.ps1
Get-Content reports/kubelinter.txt
```

La ejecución registra **21 hallazgos** y **exit code 1**.

| Check                            | Hallazgos | Decisión y riesgo pendiente                                                                                                                                                                                                                                                                 |
| -------------------------------- | --------: | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `no-read-only-root-fs`           |        10 | Se conserva el filesystem raíz escribible de estos contenedores. Migrar a solo lectura requiere identificar y montar las rutas temporales, cachés y datos, y probar el funcionamiento. La ejecución sin root reduce permisos, pero no elimina el riesgo de escritura dentro del contenedor. |
| `job-ttl-seconds-after-finished` |         2 | Los Jobs de migración y reparación conservan su estado y logs para diagnóstico. El despliegue ya gestiona la sustitución del Job de migración; debe definirse una retención antes de agregar TTL y automatizar la limpieza del Job manual.                                                  |
| `host-pid`                       |         2 | cAdvisor y node-exporter observan procesos del nodo. El acceso amplía la visibilidad sobre el host y debe limitarse a estos exporters.                                                                                                                                                      |
| `host-network`                   |         1 | node-exporter utiliza la red del host para observar el nodo. Se mantiene su configuración existente para preservar las métricas.                                                                                                                                                            |
| `sensitive-host-mounts`          |         3 | cAdvisor monta `/` y `/sys`; node-exporter monta `/`. Son montajes de observación configurados como solo lectura; siguen exponiendo información del host.                                                                                                                                   |
| `privileged-container`           |         1 | cAdvisor requiere privilegios para las métricas de red existentes. Excepción de infraestructura aprobada y documentada arriba.                                                                                                                                                              |
| `privilege-escalation-container` |         1 | Deriva del modo privilegiado de cAdvisor; se acepta el mismo riesgo de infraestructura.                                                                                                                                                                                                     |
| `run-as-non-root`                |         1 | Corresponde únicamente a cAdvisor. Los demás manifiestos analizados cumplen el contexto sin root.                                                                                                                                                                                           |

Estos hallazgos quedan documentados y visibles; la entrega no afirma que todos
los checks de KubeLinter estén resueltos.

## Seguridad en tiempo de ejecución con Falco
### Instalación y configuración
En primer lugar, instalamos Helm, el gestor de paquetes utilizado para desplegar Falco en Kubernetes.

```powershell
winget install --id Helm.Helm -e
```

Agregamos el repositorio oficial de Falco a Helm.

```powershell
helm repo add falcosecurity https://falcosecurity.github.io/charts
```

Se creó el directorio security/falco para almacenar el archivo de configuración values.yaml. Este archivo define los parámetros del despliegue de Falco, incluyendo el uso de un DaemonSet, que permite ejecutar un Pod de Falco en cada nodo elegible del clúster.

También se configuró el uso del driver modern_ebpf para la captura de eventos del sistema y se habilitó la salida de alertas por consola.

Se utilizaron las reglas de Falco para detectar la ejecución de shells interactivas dentro de los contenedores. En particular, se utiliza la regla integrada `A shell was spawned in a container with an attached terminal`, que permite identificar cuándo se abre una terminal interactiva dentro de un contenedor.

Finalmente, desplegamos Falco mediante Helm, utilizando el archivo de configuración anterior desde el directorio raíz del proyecto.

```powershell
helm upgrade --install falco falcosecurity/falco `
    --version 9.2.2 `
    --namespace falco `
    --create-namespace `
    --values .\security\falco\values.yaml `
    --wait `
    --timeout 5m
```

### Simulación de ataque
Una vez desplegado Falco, realizamos una simulación para comprobar el funcionamiento de las reglas de detección.

Para esto abrimos una shell interactiva dentro del backend de PlayHub.

```powershell
kubectl exec -it -n default playhub-backend-blue-5f6b87ddb-4zvvk -- sh
```

Dentro de la terminal se ejecutan comandos básicos.

```bash
whoami
hostname
ps
```

Luego salimos con el comando `exit`.

Verificamos que se hayan registrado estos eventos.

```powershell
kubectl logs -n falco -l app.kubernetes.io/name=falco -c falco --since=5m |
    Select-String "A shell was spawned in a container with an attached terminal"
```

### Creación de scripts
Para facilitar el trabajo de instalación, simulación y obtención de reportes se crearon tres scripts, cada uno con su versión en PowerShell y en Bash.

- `falco-deploy` verifica que exista el comando `helm`, `kubectl`, que exista el archivo de configuración de Falco, que se pueda conectar con Kubernetes, agrega Falco al repositorio de Helm, lo instala o actualiza y espera a que los Pods de Falco estén listos.

- `simulate-shell-attack` simula un ataque por medio de una shell interactiva. Para esto, identifica un Pod en ejecución mediante su etiqueta y obtiene el nombre del contenedor en el que se abrirá la terminal.

- `get-falco-report` genera dos archivos: un archivo `.log` con los eventos guardados en los logs de Falco y un archivo `.txt` con un reporte resumido de las alertas encontradas. Estos archivos se guardan en la carpeta `reports/falco`. Se ha dejado como constancia dos de estos archivos a modo de ejemplo y como evidencia del trabajo realizado.


