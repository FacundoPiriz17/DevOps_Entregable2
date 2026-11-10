# Seguridad en Kubernetes con Kyverno y KubeLinter

Esta parte del entregable incorpora tres políticas de admisión para impedir
imágenes `latest`, exigir recursos y evitar contenedores root. Las políticas
están en modo **Enforce**: Kubernetes rechaza las solicitudes que incumplen las
reglas. Los resultados se guardan en `reports/kyverno-validation-post-mitigacion.txt`
y `reports/kubelinter.txt`.

## Archivos

| Archivo | Propósito |
| --- | --- |
| `k8s/kyverno/disallow-latest.yaml` | Prohibir `latest` explícito e implícito. |
| `k8s/kyverno/require-resources.yaml` | Exigir requests y limits positivos de CPU y memoria. |
| `k8s/kyverno/disallow-root.yaml` | Exigir ejecución sin root y prohibir UID 0. |
| `tests/kyverno/valid-pod.yaml` | Pod válido que ejecuta con UID 1000. |
| `tests/kyverno/invalid-pod.yaml` | Pod que incumple las tres políticas. |
| `scripts/install-kyverno.ps1` | Instalar Kyverno y aplicar las políticas. |
| `scripts/validate-kyverno.ps1` | Ejecutar las pruebas y guardar la evidencia. |
| `scripts/lint-kubernetes.ps1` | Ejecutar KubeLinter y guardar todos sus hallazgos. |

Los ejemplos intencionalmente inválidos quedan fuera de `k8s/`, para evitar su
despliegue junto con la aplicación o confundirlos con los manifiestos analizados.

## Alcance de las políticas

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

Los contenedores de PostgreSQL, Grafana, Prometheus y ambos Jobs de Flyway
declaran `securityContext.allowPrivilegeEscalation: false`. Esto corrige los
cinco hallazgos de Semgrep por escalada de privilegios sin restringir en estos
manifiestos. Se conservan las excepciones de cAdvisor y node-exporter para
mantener la recolección actual de métricas del nodo.

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

## Instalación y ejecución

Requisitos: Docker en funcionamiento, un clúster accesible con `kubectl`, acceso
a Internet y permisos para instalar CRD, RBAC y webhooks. Los scripts se ejecutan
desde PowerShell. La validación se realizó en
Minikube con Kubernetes 1.35.1, Kyverno 1.19.2 y KubeLinter 0.8.3.

Las últimas versiones estables se verificaron el **2 de noviembre de 2026**
mediante los releases oficiales de GitHub y su API `releases/latest`:

| Herramienta | Versión estable utilizada |
| --- | --- |
| [Kyverno](https://github.com/kyverno/kyverno/releases/tag/v1.19.2) | 1.19.2 |
| [KubeLinter](https://github.com/stackrox/kube-linter/releases/tag/v0.8.3) | 0.8.3 |

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

## Validación y evidencia

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

## Resultado de KubeLinter

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

| Check | Hallazgos | Decisión y riesgo pendiente |
| --- | ---: | --- |
| `no-read-only-root-fs` | 10 | Se conserva el filesystem raíz escribible de estos contenedores. Migrar a solo lectura requiere identificar y montar las rutas temporales, cachés y datos, y probar el funcionamiento. La ejecución sin root reduce permisos, pero no elimina el riesgo de escritura dentro del contenedor. |
| `job-ttl-seconds-after-finished` | 2 | Los Jobs de migración y reparación conservan su estado y logs para diagnóstico. El despliegue ya gestiona la sustitución del Job de migración; debe definirse una retención antes de agregar TTL y automatizar la limpieza del Job manual. |
| `host-pid` | 2 | cAdvisor y node-exporter observan procesos del nodo. El acceso amplía la visibilidad sobre el host y debe limitarse a estos exporters. |
| `host-network` | 1 | node-exporter utiliza la red del host para observar el nodo. Se mantiene su configuración existente para preservar las métricas. |
| `sensitive-host-mounts` | 3 | cAdvisor monta `/` y `/sys`; node-exporter monta `/`. Son montajes de observación configurados como solo lectura; siguen exponiendo información del host. |
| `privileged-container` | 1 | cAdvisor requiere privilegios para las métricas de red existentes. Excepción de infraestructura aprobada y documentada arriba. |
| `privilege-escalation-container` | 1 | Deriva del modo privilegiado de cAdvisor; se acepta el mismo riesgo de infraestructura. |
| `run-as-non-root` | 1 | Corresponde únicamente a cAdvisor. Los demás manifiestos analizados cumplen el contexto sin root. |

Estos hallazgos quedan documentados y visibles; la entrega no afirma que todos
los checks de KubeLinter estén resueltos.

## Contraste con el reporte de Semgrep

Después de restringir la escalada de privilegios en los cinco contenedores
indicados arriba, se
ejecutó Semgrep 1.182.1 con el conjunto `p/kubernetes` sobre `k8s/` y
`scripts/flyway-repair.yaml`. La salida completa, sin filtros, se guarda en
`reports/semgrep-kubernetes.txt`.

Ese análisis detectó 16 hallazgos: seis corresponden a las excepciones
de cAdvisor y node-exporter, y diez a filesystems raíz escribibles.
Estos últimos ya aparecían en KubeLinter, pero no en el reporte original de
Semgrep, que utilizó otro conjunto de reglas. Los cinco hallazgos originales
por falta de `allowPrivilegeEscalation: false` en Flyway, PostgreSQL, Grafana y
Prometheus ya no aparecen. El análisis sigue teniendo hallazgos pendientes;
su código de salida 0 indica que terminó, no que los manifiestos estén libres
de problemas.

### Análisis posterior a las mitigaciones

El 10 de noviembre de 2026 se generó
`reports/semgrep-kubernetes-post-mitigacion.txt`: 16 hallazgos, 0 errores
y exit code 0, utilizando las reglas oficiales de Kubernetes.
La clasificación blocking no hace fallar el comando sin la opción `--error`.

Los Pods auxiliares de ambos despliegues ahora incluyen requests/limits y
contexto sin root. Se probó el despliegue con las políticas previamente
activas, la instalación posterior de Falco y el rechazo de Pods que imitan
metadatos de infraestructura.
