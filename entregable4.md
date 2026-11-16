# Entregable 4: Kyverno y Falco

## Objetivo

Incorporar una cuarta politica de admision, `disallow-privilege-escalation`, verificar
que los Pods que no la cumplen son rechazados y dejar la evidencia en
`reports/kyvernovalidation.log`.

Ademas, verificar la deteccion en tiempo de ejecucion con Falco mediante un
evento controlado que no abre una shell y dejar la evidencia en
`reports/falcoevent.log`.

## Politicas en modo bloqueante

| Politica | Verificacion |
| --- | --- |
| `disallow-latest` | Imagen con tag explicito o digest; revisa containers, initContainers y ephemeralContainers. |
| `require-resources` | requests y limits positivos de CPU y memoria. |
| `disallow-root` | `runAsNonRoot: true` y prohibicion de `runAsUser: 0`. |
| `disallow-privilege-escalation` | `allowPrivilegeEscalation: false` explicito en todos los contenedores. |

## Cuarta politica

`k8s/kyverno/disallow-privilege-escalation.yaml` es una `ValidatingPolicy`
(`policies.kyverno.io/v1`) con `validationActions: [Deny]`. Valida containers,
initContainers y ephemeralContainers, y tambien cubre el subrecurso
`pods/ephemeralcontainers`. Excluye los namespaces de sistema y deshabilita el
escaneo en segundo plano porque usa datos de la solicitud de admision.

La validacion exige que cada contenedor declare:

```yaml
securityContext:
  allowPrivilegeEscalation: false
```

### Excepcion para cAdvisor y Falco

Kubernetes rechaza `allowPrivilegeEscalation: false` junto con `privileged: true`.
Por eso se exceptuan solo los Pods creados por el controlador de DaemonSets con la
identidad `system:serviceaccount:kube-system:daemon-set-controller` y que cumplen:

- cAdvisor: namespace `default`, owner DaemonSet `playhub-cadvisor-network` y label `app=playhub-cadvisor-network`.
- Falco: namespace `falco`, owner DaemonSet `falco` y `serviceAccountName: falco`.

La excepcion no alcanza creaciones manuales: los Pods falsos con esos labels u
owners, pero sin la identidad del controlador, siguen siendo rechazados. Como
consecuencia, se elimino `allowPrivilegeEscalation: false` de
`k8s/monitoring/cadvisor-network.yaml`, donde era invalido por ser privilegiado.

## Cambios

- `k8s/kyverno/disallow-privilege-escalation.yaml`: cuarta politica y excepcion.
- `k8s/monitoring/cadvisor-network.yaml`: eliminada la combinacion invalida.
- `scripts/install-kyverno.ps1`: espera la `ValidatingPolicy` mediante
  `status.conditionStatus.ready`.
- `scripts/validate-kyverno.ps1`: 8 comprobaciones nuevas (53 en total), espera de
  la `ValidatingPolicy`, registro de politicas/acciones y salida a
  `reports/kyvernovalidation.log`.
- `.gitignore`: excepcion para versionar `reports/kyvernovalidation.log`.

Las 8 comprobaciones nuevas cubren: APE faltante, APE en `true`, container sin
`securityContext`, segundo contenedor, initContainer, contenedor efimero y dos
intentos de suplantar la excepcion de cAdvisor y Falco. La creacion real del Pod
invalido ahora tambien verifica el rechazo de la cuarta politica.

## Ejecucion

Requisitos: cluster con Kyverno 1.19.2, Helm y el chart de Falco renderizado.

```powershell
helm repo add falcosecurity https://falcosecurity.github.io/charts --force-update
helm repo update falcosecurity
New-Item -ItemType Directory -Force .tmp/security-reports | Out-Null
helm template falco falcosecurity/falco --version 9.2.2 --namespace falco --values security/falco/values.yaml |
  Set-Content .tmp/security-reports/falco-rendered.yaml
.\scripts\validate-kyverno.ps1
Get-Content reports\kyvernovalidation.log | Select-String '^(PASS|FAIL|RESULTADO)'
```

La validacion se ejecuto sobre Minikube con Kyverno 1.19.2: 53 comprobaciones
correctas, sin fallos. Se confirmo que el Pod valido pasa y que se rechazan los
casos sin `allowPrivilegeEscalation: false`, incluidos init y ephemeral.

## Notas

- Las tres politicas existentes usan `ClusterPolicy`, deprecada en Kyverno 1.19.
- Nombrar `pods/ephemeralcontainers` desactiva el autogen de controladores; la
  politica se aplica igualmente al crear los Pods.
- `scripts/install-kyverno.ps1` espera las tres `ClusterPolicy` y la
  `ValidatingPolicy` antes de finalizar.

## Monitoreo de seguridad en tiempo de ejecucion con Falco

### Instalacion

Falco se instala con Helm mediante `scripts/deploy-falco.ps1` o
`scripts/deploy-falco.sh`. Se requiere `helm`, `kubectl` y Python 3.11+ en el
`PATH`. El proyecto fija el chart `9.2.2`, usa el driver `modern_ebpf` y
configura salida JSON para poder correlacionar los eventos.

```powershell
.\scripts\deploy-falco.ps1
```

```bash
bash scripts/deploy-falco.sh
```

### Evento de prueba

La prueba oficial no abre una shell ni crea un Pod nuevo. Selecciona el Pod
`backend` de PlayHub y ejecuta directamente BusyBox para crear un enlace
simbolico hacia `/etc/shadow`:

```text
kubectl exec -n default <pod-backend> -c backend -- \
  /bin/busybox ln -s /etc/shadow /tmp/playhub-falco-<timestamp>.link
```

El comando no usa `-i`, no usa `-t` y no invoca `sh`. El enlace se elimina al
finalizar con `/bin/busybox rm -f`. No se lee ni se modifica `/etc/shadow`.

Como `kubectl exec` no crea ni modifica un Pod, las politicas de admision de
Kyverno no intervienen. Falco tampoco bloquea la accion: la detecta y la
registra.

```powershell
.\scripts\simulate-symlink-attack.ps1
.\scripts\get-falco-symlink-report.ps1
Get-Content reports\falcoevent.log
```

```bash
bash scripts/simulate-symlink-attack.sh
bash scripts/get-falco-symlink-report.sh
cat reports/falcoevent.log
```

### Deteccion y evidencia

Falco detecta la regla integrada `Create Symlink Over Sensitive Files`, con
prioridad `WARNING` y tactica MITRE `T1555 - Credentials from Password Stores`.
La salida esperada incluye:

```text
Symlinks created over sensitive files | target=/etc/shadow
linkpath=/tmp/playhub-falco-<timestamp>.link ...
```

El recolector correlaciona la alerta con el `container.id` del Pod probado, la
ventana de tiempo y el target `/etc/shadow`. La evidencia principal queda en:

```text
reports/falcoevent.log
```

Tambien se genera un reporte legible en:

```text
reports/falco/falco-symlink-report-<timestamp>.txt
```

### Descripcion del evento

Se creo un enlace simbolico dentro del contenedor `backend` apuntando a
`/etc/shadow`, archivo sensible de credenciales. La accion simula la preparacion
de un acceso no autorizado a credenciales. No se leyo ni se modifico el archivo
y el enlace fue eliminado al finalizar. Falco lo clasifica como `WARNING` y
MITRE `T1555`.

### Verificacion

```powershell
kubectl logs -n falco -l app.kubernetes.io/name=falco -c falco --since=10m |
  Select-String "Symlinks created over sensitive files"

Select-String "Terminal shell in container" reports\falcoevent.log
```

La segunda busqueda no debe devolver resultados. La prueba shell anterior se
conserva como legado, pero la prueba oficial de este entregable es la de
symlink.

### Resultado

La prueba se ejecuto sobre Minikube con el backend Blue. Falco registro una
alerta de `Create Symlink Over Sensitive Files` con `target=/etc/shadow` y
`terminal=0`; la evidencia quedo en `reports/falcoevent.log`. No se detecto la
regla `Terminal shell in container` y la eliminacion del enlace temporal fue
correcta.
