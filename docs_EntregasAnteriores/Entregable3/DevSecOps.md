# Entregable 3 - DevSecOps:

## Seguridad en el codigo:

### NPM Audit:

En esta parte del entregable se realizo un escaneo utilizando la función de:

```bash
npm audit > reports/npm-audit.txt
```

Donde se creo el reporte en forma de archivo .txt mostrando las vulnerabilidades en los paquetes de npm.

En el análisis inicial, se encontraron 6 vulnerabilidades: 5 HIGH y 1 CRITICAL. Afectaban las dependencias del frontend, entre ellas Next.js.

#### Análisis posterior a las mitigaciones

El 10 de noviembre de 2026 se generaron los reportes de npm audit después
de ejecutar `npm ci`. El informe completo registra 7 vulnerabilidades
moderadas, 0 HIGH y 0 CRITICAL; el audit con `--omit=dev` registra
0 vulnerabilidades.

**Decisión:** Se aceptan las moderadas de la cadena de ESLint/typescript-eslint
por `minimatch` (GHSA-g3hv-75wg-m249) para el entregable: procesan archivos del
repositorio y se excluyen del runtime mediante `npm prune --omit=dev`. Existe
una actualización compatible pendiente para esa cadena de desarrollo. Esto no
equivale a afirmar que el audit completo está libre de hallazgos.

```powershell
.\scripts\audit-frontend.ps1
```

### Análisis Semgrep

**Comando ejecutado:**

```bash
docker run --rm -e SEMGREP_APP_TOKEN=<token> -v "%cd%:/src" semgrep/semgrep semgrep ci
```

En el análisis inicial se ejecutó Semgrep con login en la plataforma cloud, con los productos Code (SAST) y Supply Chain (SCA) habilitados. Se analizaron 202 archivos versionados en git. El escaneo finalizó con 49 hallazgos, ninguno bloqueante.

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

**Decisión:** Se actualizaron las dependencias afectadas y se verificaron con npm audit y Trivy.

#### Code (SAST): 22 hallazgos non-blocking

**Hash de contraseñas en los inserts (severidad High):** el hallazgo principal se encontró en los inserts de demostración (`V2__demo_data.sql` y `02_inserts.sql`), donde los hashes bcrypt de 4 usuarios (`@playhub.test`) están cargados directamente junto con los datos. **Decisión:** Se mantienen sin modificar porque son datos demo necesarios para probar la aplicación y no corresponden a usuarios reales.

**Archivos YAML (Kubernetes y monitoreo):** el resto de los hallazgos son de severidad moderada y corresponden a configuraciones de seguridad de contenedores (`runAsNonRoot`, `allowPrivilegeEscalation`, `hostPID`, `hostNetwork`, `privileged`) en los manifiestos de despliegue y de monitoreo. **Decisión:** Se aplicaron los contextos de seguridad y las políticas de Kyverno. Los hallazgos de infraestructura y filesystem que permanecen se justifican en la sección de KubeLinter.

#### Análisis posterior a las mitigaciones

El 10 de noviembre de 2026 se generaron los reportes de Semgrep 1.182.1
en modo SAST local, con reglas oficiales para Java, JavaScript, secretos
y Kubernetes.

| Alcance posterior | Reglas ejecutadas | Archivos | Hallazgos | Exit code |
| --- | ---: | ---: | ---: | ---: |
| Java, JavaScript y datos SQL | 164 | 140 | 8 | 0 |
| Kubernetes y Job de reparación | 11 | 24 | 16 | 0 |

Los 8 hallazgos de código son los cuatro hashes bcrypt demo repetidos en los
dos archivos SQL. Se mantienen para probar la aplicación. Los 16 de Kubernetes
corresponden a diez filesystems escribibles y seis alertas de los exporters.
No hubo errores de análisis. El SAST incluye 84 archivos Java; la ausencia de
Supply Chain Maven no significa que el código fuente Java haya quedado fuera.
Esta ejecución local no repite el producto SCA cloud ni su análisis de
alcanzabilidad, por lo que los conteos no se comparan como si tuvieran el mismo
alcance. La etiqueta `blocking` de las reglas no cambia el exit code de
`semgrep scan` sin `--error`; para bloquear por hallazgos debe configurarse.

```powershell
.\scripts\scan-semgrep.ps1
```

## Actualización de dependencias y correcciones de seguridad (Trivy)

### Objetivo

Este fragmento resume las versiones detectadas en el escaneo inicial de Trivy y las versiones corregidas indicadas por el propio reporte. Se actualizaron los componentes afectados, se reconstruyeron las imágenes y se volvió a ejecutar Trivy para verificar las mitigaciones.

> **NOTA:** Las tablas muestran las versiones detectadas y sus correcciones. El estado `fixed` de una vulnerabilidad indica que existe una corrección, no que ya esté instalada.

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

El reporte inicial del frontend encontró **25 vulnerabilidades: 20 HIGH y 5 CRITICAL**.

| Dependencia          | Versión detectada | Versión corregida / objetivo | Observación                                                                                  |
| -------------------- | ----------------: | ---------------------------: | -------------------------------------------------------------------------------------------- |
| `next`               |            16.3.1 |                   **16.4.1** | Actualización principal para corregir los hallazgos CRITICAL y HIGH informados para Next.js. |
| `eslint-config-next` |            16.3.1 |                   **16.4.1** | Se alinea con la versión de Next.js.                                                         |

Las tablas resumen las dependencias principales. Los informes completos también incluyen las transitivas y los paquetes del sistema operativo; no se descartan por su cantidad. Sus versiones exactas se comprueban en el lockfile y en las imágenes reconstruidas.

### Sincronización del lockfile

Después de modificar `package.json`, es necesario regenerar el archivo de bloqueo. Desde la carpeta `frontend`:

```bash
npm install
```

`npm install` actualiza `package-lock.json`.

### Verificación final

Después de actualizar las dependencias y reconstruir las imágenes, volver a ejecutar Trivy:

```bash
trivy image playhub-frontend:v1.0 > reports/trivyreports_frontend-post-mitigacion.txt
```

El 10 de noviembre de 2026 se generó el reporte de la imagen reconstruida con Trivy 0.75.0: 0 vulnerabilidades, incluidas 0 HIGH y 0 CRITICAL.

### Backend

Archivo principal de configuración: `backend/pom.xml`  
Imagen de ejecución: `backend/Dockerfile.prod`

El reporte inicial del backend encontró **14 vulnerabilidades en dependencias Java (10 HIGH y 4 CRITICAL)** y **1 vulnerabilidad CRITICAL en un paquete de Alpine Linux**.

| Dependencia / componente                   | Versión detectada | Versión corregida / objetivo | Dónde se gestiona                                                              |
| ------------------------------------------ | ----------------: | ---------------------------: | ------------------------------------------------------------------------------ |
| Spring Boot (`spring-boot-starter-parent`) |             4.1.1 |                    **4.1.2** | `backend/pom.xml`; actualización del BOM para gestionar versiones transitivas. |

La actualización de `spring-boot-starter-parent` a 4.1.2 se plantea para gestionar las versiones de las dependencias transitivas a través del BOM de Spring Boot. El árbol de dependencias resuelto con Maven confirmó Jackson 2.21.7, Jackson 3.1.7, Tomcat 11.0.27 y Spring Security 7.1.2; no se dedujeron únicamente a partir del parent.

Para el paquete del sistema operativo, se debe incorporar la actualización disponible de Alpine durante la construcción de la imagen. Por ejemplo, el siguiente comando permite actualizar específicamente `brotli-libs` a una versión corregida disponible en los repositorios:

```dockerfile
RUN apk upgrade --no-cache brotli-libs libexpat zlib
```

### Verificación final

Después de actualizar las dependencias y reconstruir las imágenes, volver a ejecutar Trivy:

```bash
trivy image playhub-backend:v1.0 > reports/trivyreports_backend-post-mitigacion.txt
```

El 10 de noviembre de 2026 se generó el reporte de la imagen reconstruida con Trivy 0.75.0: 0 vulnerabilidades, incluidas 0 HIGH y 0 CRITICAL.

### Análisis posterior a las mitigaciones

El frontend utiliza Next 16.4.1 y React 19.2.8; se actualizó zlib
a 1.4-r0. En el backend quedaron brotli-libs 1.2.1-r0, libexpat 2.10.0-r0 y
zlib 1.4-r0. La actualización de libexpat corrigió los HIGH
CVE-2026-113351, CVE-2026-115506, CVE-2026-117610 y CVE-2026-118370;
zlib corrigió CVE-2026-4738. Los resultados finales de ambas imágenes son
0 vulnerabilidades detectadas.

Las bases de producción están fijadas por digest. El frontend arranca con
Node directamente, copia `next.config.mjs` y responde `/login` con UID 1000.
Se comprobó que Blue y Green ejecutan las mismas imágenes analizadas:

| Componente | ID de la imagen escaneada en Docker host |
| --- | --- |
| Frontend | `sha256:87c8ade147603421f39568a6b72dcbce54e70331d7e2ce0647405d4369b8d3dc` |
| Backend | `sha256:94239c3879d55e618305eaddc9bbedfbd75c6febc71281b923c03a8d88581583` |

```powershell
.\scripts\scan-images.ps1
```

El consolidado `reports/trivyreport.txt` contiene las tablas de ambas imágenes.

## Seguridad en Kubernetes con Kyverno y KubeLinter

Esta parte del entregable incorpora tres políticas de admisión para impedir
imágenes `latest`, exigir recursos y evitar contenedores root. Las políticas
están en modo **Enforce**: Kubernetes rechaza las solicitudes que incumplen las
reglas. Los resultados reales se guardan en `reports/kyverno-validation-post-mitigacion.txt`
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
`background: true` se conserva en las políticas de imágenes y recursos. La
política sin root usa `background: false` porque comprueba la identidad de la
solicitud de admisión. Las tres mantienen **Enforce** y
`allowExistingViolations: false`; no se desactivan para desplegar Falco.

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

### Excepciones aprobadas para cAdvisor y Falco

cAdvisor recolecta las métricas de red de los Pods.
Necesita observar los procesos, namespaces de red y runtime del nodo, por lo que
mantiene UID 0, `privileged: true`, `hostPID` y montajes del host. Falco utiliza
`modern_ebpf` con privilegios para observar los eventos del nodo.

La excepción de la regla sin root exige que el Pod haya sido creado por la
identidad autenticada `system:serviceaccount:kube-system:daemon-set-controller`
y que también coincidan estas condiciones:

| Componente | Namespace | Condiciones adicionales |
| --- | --- | --- |
| cAdvisor | `default` | OwnerReference DaemonSet `playhub-cadvisor-network` y label `app=playhub-cadvisor-network`. |
| Falco | `falco` | OwnerReference DaemonSet `falco` y ServiceAccount `falco`. |

Los labels y ownerReferences por sí solos no autentican al creador. Se comprobó
que un Pod de aplicación que imita esos metadatos sigue siendo rechazado.
Las reglas de imágenes y recursos también se aplican a Falco. El contenedor
principal tiene recursos explícitos; el initContainer y el sidecar falcoctl
también los declaran y ejecutan con UID 1000, sin escalada de privilegios.

Esta identidad corresponde al Minikube probado, configurado con
`--use-service-account-credentials=true`. En otro clúster debe verificarse antes
de adaptar la excepción. El namespace `falco`, las políticas y los permisos de
impersonación quedan reservados a los administradores del laboratorio; no se
conceden a usuarios de aplicaciones. No se afirma que estos componentes
privilegiados cumplan la regla sin root.

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
.\scripts\deploy.ps1 -DeployGreen
.\scripts\deploy-falco.ps1
.\scripts\validate-kyverno.ps1
.\scripts\lint-kubernetes.ps1
```

El instalador descarga el manifiesto de la versión oficial fijada y utiliza
`kubectl apply --server-side`, para evitar el límite de anotaciones de los CRD
grandes. Espera que los cuatro controladores estén disponibles y que las tres
políticas indiquen `Ready`.

### Validación y evidencia

El script guarda los comandos, respuestas del API server, códigos de salida y
comprobaciones en `reports/kyverno-validation-post-mitigacion.txt`. Un rechazo solo cuenta como
correcto si proviene del webhook y menciona la política esperada; un error de
conexión, sintaxis o descarga no se considera evidencia de bloqueo.

Las pruebas cubren etiquetas explícitas e implícitas, digest, puertos de
registro, recursos ausentes y cero, UID 0, herencia y sobrescritura del contexto
de seguridad, un segundo contenedor, initContainers, los Pod templates del
proyecto y la excepción de cAdvisor. También se comprueba el subrecurso real
`pods/ephemeralcontainers` con operaciones `dryRun=All`.

Para comprobar los Pod templates sin instalar toda la aplicación, se utiliza
el ServiceAccount `default` en los Pods de aplicación de prueba. El template
de Falco conserva su ServiceAccount y los templates de infraestructura se
comprueban impersonando la identidad del controlador de DaemonSets. Es una prueba de admisión de sus
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

El 10 de noviembre de 2026 se generó el reporte de validación con
**45 comprobaciones correctas**. Incluye el template de Falco, los cuatro Pods
auxiliares y el rechazo de metadatos de infraestructura imitados. Se verificó
el rechazo real del Pod inválido y la ejecución del válido con UID 1000. Para
repetir la demostración:

```powershell
.\scripts\validate-kyverno.ps1
Get-Content reports/kyverno-validation-post-mitigacion.txt
```

### Resultado de KubeLinter

El informe está en **`reports/kubelinter.txt`**, relativo a la raíz del
repositorio. El script utiliza la imagen oficial fijada y registra stdout,
stderr y el código de salida. Analiza `k8s/` recursivamente y el Job manual de
reparación de Flyway, con todos los checks predeterminados y sin supresiones.
KubeLinter es un análisis estático; el comportamiento de las políticas de
Kyverno se verifica por separado mediante admisión real.

```powershell
.\scripts\lint-kubernetes.ps1
Get-Content reports/kubelinter.txt
```

El reporte generado el 10 de noviembre de 2026 registra **21 hallazgos**
y **exit code 1**. Las decisiones sobre cada grupo se detallan a continuación.

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

Se utilizaron las reglas de Falco para detectar la ejecución de shells interactivas dentro de los contenedores. En particular, se utiliza la regla integrada `Terminal shell in container`, cuyo mensaje es `A shell was spawned in a container with an attached terminal` y que permite identificar cuándo se abre una terminal interactiva dentro de un contenedor.

Finalmente, desplegamos Falco mediante Helm, utilizando el archivo de configuración del proyecto desde el directorio raíz.

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
.\scripts\simulate-shell-attack.ps1
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

- `deploy-falco` verifica que exista el comando `helm`, `kubectl`, que exista el archivo de configuración de Falco, que se pueda conectar con Kubernetes, agrega Falco al repositorio de Helm, lo instala o actualiza y espera a que los Pods de Falco estén listos.

- `simulate-shell-attack` simula un ataque por medio de una shell interactiva. Para esto, identifica un Pod en ejecución mediante su etiqueta y obtiene el nombre del contenedor en el que se abrirá la terminal.

- `get-falco-report` guarda la alerta real en `reports/falco-event.log` y un resumen en `reports/falco/falco-report-AAAA-MM-DD_HH-MM-SS.txt`. Solo cuenta eventos cuyo ID de contenedor y ventana temporal coinciden con la prueba; si no hay detección, devuelve un error.

### Validación posterior a las mitigaciones

Se instaló y actualizó Falco después de activar Kyverno, tanto con PowerShell
como con Bash. El chart 9.2.2 utiliza Falco 0.45.2 y falcoctl 0.14.3; el
DaemonSet quedó disponible con sus dos contenedores Ready. Se configuraron
recursos y contextos de seguridad para el initContainer y el sidecar falcoctl.

El 10 de noviembre de 2026 se generó
`reports/falco/falco-report-2026-11-10_11-11-00.txt`. La shell de prueba
ejecutó como UID 1000 y produjo una alerta real `Terminal shell in container`.
Los scripts de simulación y recolección del proyecto requieren Python 3.11
o posterior.

```powershell
.\scripts\deploy-falco.ps1
.\scripts\simulate-shell-attack.ps1 -Seconds 2
.\scripts\get-falco-report.ps1
Get-Content reports/falco-event.log
```

## Comparación de informes

| Herramienta | Informe inicial | Informe posterior |
| --- | --- | --- |
| npm audit | `reports/npm-audit-frontend.txt` | `reports/npm-audit.txt` |
| Semgrep código | `reports/semgrep_scan.txt` | `reports/semgrep_scan-post-mitigacion.txt` |
| Semgrep Kubernetes | `reports/semgrep-kubernetes.txt` | `reports/semgrep-kubernetes-post-mitigacion.txt` |
| Trivy frontend | `reports/trivyreports_frontend.txt` | `reports/trivyreports_frontend-post-mitigacion.txt` |
| Trivy backend | `reports/trivyreports_backend.txt` | `reports/trivyreports_backend-post-mitigacion.txt` |
| KubeLinter | `reports/kubelinter-inicial.txt` | `reports/kubelinter.txt`, con el nombre obligatorio |
| Kyverno | `reports/kyverno-validation.txt` | `reports/kyverno-validation-post-mitigacion.txt` |
| Falco | `reports/falco/falco-report-2026-11-04_14-17-09.txt` | `reports/falco/falco-report-2026-11-10_11-11-00.txt` y alerta obligatoria `reports/falco-event.log` |
