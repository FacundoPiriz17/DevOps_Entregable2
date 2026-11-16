# Entregable 4: Semgrep, Snyk, Kyverno y Falco:

Seguridad en Entregable 4:

Se debe automiatizar todo el análisis después en la pipeline, por lo tanto se ha de guardar comandos en el readme. 

Semgrep (Usando Docker)

Runnear semgrep-report.txt

Las vulnerabilidades no deben jsutifcarse de vuelta

//Scanneo normal

MSYS_NO_PATHCONV=1 docker run -e SEMGREP_APP_TOKEN=dd3858f4998b5d3614907c66e79817b2f755b22999f79322b52713c75867ab0b --rm -v "$(pwd -W):/src" -w /src semgrep/semgrep semgrep ci > reports/semgrep-report.txt --verbose


Reglas utilizadas: p/java  p/spring p/react p/javascript p/owasp-top-ten

//Scanneo con reglas:
MSYS_NO_PATHCONV=1 docker run --rm -e NO_COLOR=1 -v "$(pwd -W):/src" -w /src semgrep/semgrep semgrep scan --config p/java --config p/findsecbugs --config p/react --config p/javascript --config p/owasp-top-ten --exclude node_modules --exclude logs --exclude reports --text --output reports/semgrep-report.txt

Vulnerabilidad 1:
backend/src/main/resources/application.properties
    ❯❱ java.spring.security.audit.spring-actuator-non-health-enabled.spring-actuator-dangerous-endpoints-enabled
          ❰❰ Blocking ❱❱
          Spring Boot Actuators "health,prometheus" are enabled. Depending on the actuators, this can pose a
          significant security risk. Please double-check if the actuators are needed and properly secured.  
          Details: https://sg.run/5g23                                                                      
                                                                                                            
           27┆ management.endpoints.web.exposure.include=health,prometheus

Es requerida dado que habilita el monitoreo con prometehues, es para medir la latencia de las solicitudes 

Vulnerabilidad 2:
 k8s/monitoring/cadvisor-network.yaml
    ❯❱ yaml.kubernetes.security.allow-privilege-escalation.allow-privilege-escalation
          ❰❰ Blocking ❱❱
          In Kubernetes, each pod runs in its own isolated environment with its own set of security policies. 
          However, certain container images may contain `setuid` or `setgid` binaries that could allow an     
          attacker to perform privilege escalation and gain access to sensitive resources. To mitigate this   
          risk, it's recommended to add a `securityContext` to the container in the pod, with the parameter   
          `allowPrivilegeEscalation` set to `false`. This will prevent the container from running any         
          privileged processes and limit the impact of any potential attacks. By adding the                   
          `allowPrivilegeEscalation` parameter to your the `securityContext`, you can help to ensure that your
          containerized applications are more secure and less vulnerable to privilege escalation attacks.     
          Details: https://sg.run/ljp6                                                                        
                                                                                                              
           ▶▶┆ Autofix ▶ securityContext: allowPrivilegeEscalation: false #
           48┆ securityContext:

Se implemento la flag de "allowPrivilegeEscalation: False" Para mitigar la vulnerabildad. De esta forma se debería evitar el escalado de privilegios.

Snyk:

Instalation: npm install snyk -g

Comando de test: snyk test --all-projects --exclude=node_modules,reports > reports/snyk-report.txt

Se encontraron 2 vulnerabilidades criticas: 

 ✗ [CRITICAL] Deserialization of Untrusted Data
   Finding ID: SNYK-JAVA-COMFASTERXMLJACKSONCORE-21761837
   Info: https://snyk.io/vuln/SNYK-JAVA-COMFASTERXMLJACKSONCORE-21761837
   Introduced by: com.fasterxml.jackson.core:jackson-databind
   Introduced through: com.devops:devops_backend@0.0.1-SNAPSHOT > io.jsonwebtoken:jjwt-jackson@0.12.6 > com.fasterxml.jackson.core:jackson-databind@2.21.7

 ✗ [CRITICAL] Deserialization of Untrusted Data
   Finding ID: SNYK-JAVA-TOOLSJACKSONCORE-21761838
   Info: https://snyk.io/vuln/SNYK-JAVA-TOOLSJACKSONCORE-21761838
   Introduced by: tools.jackson.core:jackson-databind
   Introduced through: com.devops:devops_backend@0.0.1-SNAPSHOT > org.flywaydb:flyway-database-postgresql@12.4.0 > org.flywaydb:flyway-core@12.4.0 > tools.jackson.core:jackson-databind@3.1.7

Vulnerabilidad 1: Jackson 2.21.7 (vía jjwt-jackson), CRITICAL

Decisión: Mitigada, actualizando a jackson-databind 2.21.8.

Justificación:

Permite deserialización de datos no confiables, que en el peor caso lleva a ejecución remota de código (RCE) y compromete la confidencialidad, integridad y disponibilidad del servidor.
La librería procesa el contenido de los tokens JWT, que llegan desde clientes externos. Por lo tanto, existe una ruta por la que un atacante podría enviar datos manipulados.
Existe una versión corregida (2.21.8) del mismo ciclo de versiones, por lo que el cambio es de bajo riesgo y no rompe compatibilidad.
El costo de mitigar (una línea en el pom.xml) es mucho menor que el impacto de una explotación.

Vulnerabilidad 2: Jackson 3.1.7 (vía Flyway), CRITICAL

Decisión: Mitigada, actualizando Flyway a 13.5.0 (o, si la actualización causa incompatibilidades, aceptada con justificación).

Justificación:

Tiene la misma severidad y el mismo tipo de falla que la anterior, y Snyk indica una actualización directa que la corrige.
Mantener dependencias actualizadas es una buena práctica DevSecOps y evita acumular deuda de seguridad.
Si no se puede actualizar: Flyway solo lee los archivos de migración propios del proyecto durante el arranque, no datos de usuarios, por lo que la superficie de ataque es mínima. El riesgo se documenta, se acepta temporalmente y se revisa en el próximo escaneo.

Kyverno:

Se implemento la 4ta policy en kyverno. La misma consiste en bloquear la escalada de privilegios para los contenedores que lo intenten. 

Se hace una excepción para cAdvisor y falco, de forma que se siga pudiendo utilizar el monitoreo. 

Se actualizaron los scripts de install-kyverno.ps1 y validate-kyverno.ps1 para incorporar la nueva funcionalidad.

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
