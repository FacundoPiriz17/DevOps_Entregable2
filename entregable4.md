# Entregable 4: cuarta politica Kyverno

## Objetivo

Incorporar una cuarta politica de admision, `disallow-privilege-escalation`, verificar
que los Pods que no la cumplen son rechazados y dejar la evidencia en
`reports/kyvernovalidation.log`.

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
