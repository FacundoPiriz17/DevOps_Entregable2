# Pipeline de Jenkins de PlayHub

Esta guía documenta la implementación actual de `jenkins/Jenkinsfile`. Amplía el [README principal](../README.md) y se complementa con los [comandos de CI y despliegue](../scripts/ci/README.md) y la [guía general de scripts](../scripts/README.md).

La revisión del 17/11/2026 incluyó consultas de lectura al namespace: el backend estaba en `FailedCreate` por cuota de CPU y Helm en `pending-install`. Los cambios se validan localmente; no se ejecutó un nuevo despliegue ni una corrida completa de Jenkins. La incorporación de Snyk sigue pendiente.

## Índice

- [Archivos y herramientas](#archivos-y-herramientas)
- [Preparar Jenkins y el job](#preparar-jenkins-y-el-job)
- [Credenciales](#credenciales)
- [Parámetros del job](#parámetros-del-job)
- [Etapas implementadas](#etapas-implementadas)
- [Publicación y despliegue](#publicación-y-despliegue)
- [Resultados y artefactos](#resultados-y-artefactos)
- [Límites actuales y pendientes](#límites-actuales-y-pendientes)
- [Evidencias de ejecución](#evidencias-de-ejecución)

## Archivos y herramientas

| Archivo | Responsabilidad |
| --- | --- |
| `jenkins/Jenkinsfile` | Define checkout, Semgrep, build/test paralelo, publicación y despliegue opcional. |
| `jenkins/Dockerfile.jenkins` | Construye una imagen de Jenkins con Docker CLI, Buildx, Python, Semgrep, kubectl y Helm. |
| `jenkins/plugins.txt` | Plugins que instala la imagen, incluidos Pipeline, Git, JUnit, Credentials Binding, Timestamper, Workspace Cleanup y Docker Pipeline. |
| `jenkins/app-secrets.env.example` | Formato del archivo de secretos de la aplicación. |
| `scripts/ci/build-and-push.sh` | Login, construcción y publicación de las imágenes de backend y frontend. |
| `scripts/deploy-helm.sh` | Despliegue local o remoto según sus argumentos. Jenkins utiliza la ruta remota. |

La imagen de Jenkins parte de `jenkins/jenkins:lts-jdk21`. El Dockerfile fija kubectl `v1.31.0` y Helm `v3.16.4`; Semgrep se instala con pip sin fijar versión. El build Java utiliza otro contenedor con Maven y JDK 26; el frontend utiliza `node:22-alpine`.

## Preparar Jenkins y el job

Desde la raíz del repositorio, se puede construir la imagen incluida con:

```bash
docker build --file jenkins/Dockerfile.jenkins --tag playhub-jenkins:local jenkins
```

El contexto es `jenkins/`, porque el Dockerfile copia `plugins.txt` desde ese contexto. Este comando solo construye la imagen: no inicia un servidor ni configura un job.

Para ejecutar la pipeline, la instalación de Jenkins debe disponer de:

- Un agente Linux con shell, Bash, Git, Semgrep, Docker, Helm, kubectl y Python accesibles según las etapas que ejecute.
- Acceso al daemon Docker para construir imágenes y para Testcontainers.
- `scripts/ci/run-build.sh` comparte el workspace con `--volumes-from` si el agente es un contenedor identificado por `$HOSTNAME`; en un agente Linux instalado directamente utiliza un bind mount. El daemon debe poder acceder a ese workspace.
- Permisos del usuario efectivo sobre el workspace y el socket Docker. El contenedor Maven recibe el UID/GID del agente y el grupo propietario del socket; usa un repositorio Maven escribible en `/tmp/.m2/repository`.
- Salida a los registros de imágenes y repositorios Maven/npm. Semgrep usa las reglas versionadas de `security/semgrep/rules`, cuya procedencia figura en `rules-manifest.json`. Para desplegar, también conectividad hacia la API Kubernetes y el host público.

Configurar un job **Pipeline from SCM** o Multibranch que obtenga este repositorio y seleccione como **Script Path** `jenkins/Jenkinsfile`. La rama a construir y los disparadores se configuran en Jenkins: el archivo no define un webhook, un cron ni `pollSCM`. No se presupone que un push dispare el job sin esa configuración externa.

El archivo usa `agent any`; los requisitos anteriores son condiciones del entorno actual, no restricciones que Jenkins esté imponiendo mediante una etiqueta.

## Credenciales

Registrar las credenciales en Jenkins y permitir su uso por el job:

| ID predeterminado | Tipo de credencial | Uso |
| --- | --- | --- |
| `docker-registry` | Username with password | Usuario y token del registry, disponibles como `REG_USER` y `REG_PASS` durante publicación y despliegue. El ID está fijo en el Jenkinsfile. |
| `playhub-kubeconfig` | Secret file | Kubeconfig del destino. Se utiliza solo si se habilita `DEPLOY`. Su ID puede cambiarse mediante parámetro. |
| `playhub-app-secrets` | Secret file | Archivo con `DB_PASSWORD`, `JWT_SECRET` y `ADMIN_PASSWORD`. Se utiliza solo si se habilita `DEPLOY`. Su ID puede cambiarse mediante parámetro. |

El archivo de secretos debe seguir el formato de `jenkins/app-secrets.env.example`. Sustituir todos los valores de ejemplo antes de cargarlo. El script exige las tres claves y un JWT de al menos 48 bytes UTF-8; no carga automáticamente un `.env` del repositorio.

El kubeconfig debe permitir gestionar los recursos de la aplicación en el namespace elegido. Los modos `install` y `adopt` de seguridad requieren además los permisos de alcance clúster comprobados por el instalador. Para un clúster compartido se utiliza `SECURITY_MODE=skip`.

El registry y namespace deben coincidir con los recursos a los que esas credenciales permiten acceder. El valor de `REGISTRY` no es un parámetro del job: actualmente está declarado como `docker.io/agustingarciaa` en el Jenkinsfile.

## Parámetros del job

Los valores efectivos se establecen en el stage `Checkout`:

| Parámetro | Predeterminado | Efecto |
| --- | --- | --- |
| `DEPLOY` | `true` | Habilita el stage `Deploy Helm` exclusivamente en `main`. Con `false` las imagenes igualmente se construyen y publican. |
| `NAMESPACE` | `alumno-team9` | Namespace de la aplicación. |
| `PUBLIC_HOST` | `playhub-team9.reto-ucu.net` | Host público sin esquema ni ruta; se utiliza también durante el build del frontend. |
| `PUBLIC_SCHEME` | `https` | `https` o `http`; compone `PUBLIC_URL`. |
| `MANAGE_TLS` | `false` | Agrega `--tls` para gestionar TLS del Ingress con cert-manager. |
| `INGRESS_CLASS` | `apisix` | Clase del Ingress de destino. |
| `SECURITY_MODE` | `skip` | `skip`, `install` o `adopt` para Kyverno/Falco. |
| `VALUES_ENV` | `dev` | Archivo `values-dev.yaml` o `values-prod.yaml`. |
| `RESOURCE_PROFILE` | `lab` | Aplica `values-lab.yaml` despues de dev/prod: una replica, actualizaciones `Recreate`, limites compactos y monitoreo sin PVC. `standard` conserva el dimensionamiento original. |
| `MONITORING_MODE` | `namespace` | Prometheus, Grafana y Blackbox solo en el namespace, sin RBAC ni nodos. `disabled` los omite; `cluster` requiere permisos de infraestructura. |
| `RECOVER_PENDING_INSTALL` | `true` | Permite recuperar exclusivamente el primer install pendiente de mas de una hora. Ver condiciones debajo. |
| `VERIFY_DEPLOY` | `true` | Agrega la comprobación de la URL pública si se ejecuta el despliegue. |
| `TLS_ISSUER` | `letsencrypt-prod` | ClusterIssuer requerido si `MANAGE_TLS=true`. |
| `KUBECONFIG_CREDENTIALS_ID` | `playhub-kubeconfig` | ID de la credencial de kubeconfig. |
| `APP_SECRETS_CREDENTIALS_ID` | `playhub-app-secrets` | ID de la credencial del archivo de secretos. |

Para construir y publicar sin desplegar, ejecutar el job con `DEPLOY=false`. Para el recorrido remoto del laboratorio, seleccionar `DEPLOY=true`, revisar host/namespace/credenciales y conservar `SECURITY_MODE=skip` si la seguridad es administrada por la plataforma.

`MANAGE_TLS=false` no obliga a usar HTTP: la plataforma puede terminar HTTPS por fuera del bloque TLS gestionado por el chart. Por eso `PUBLIC_SCHEME` es un parámetro separado.

## Etapas implementadas

| Orden | Stage | Acciones reales |
| --- | --- | --- |
| 1 | `Checkout` | `checkout scm`, commit corto y tag `${BUILD_NUMBER}-${GIT_SHORT}`; prepara parámetros y crea `reports/`. |
| 2 | `SAST - Semgrep` | Ejecuta las reglas locales versionadas; `--severity ERROR --error` detiene la pipeline ante hallazgos. Excluye dependencias, builds, temporales y reportes; genera `reports/ci/semgrep.json`. |
| 2b | `Validate Helm` | Valida dev, lab y prod antes de construir/publicar imagenes, incluso si no se despliega. Prod usa una referencia ficticia a un Secret solo para lint local. |
| 3 | `Build and Test` | Ejecuta las ramas Backend y Frontend en paralelo, con `failFast true`. |
| 3a | `Backend` | Contenedor `maven:3.9-eclipse-temurin-26`, workspace compartido, socket Docker y configuración de host para Testcontainers; ejecuta `mvn -B clean verify`. Publica Surefire con JUnit. |
| 3b | `Frontend` | Contenedor `node:22-alpine`; ejecuta `npm ci`, `npm run lint` y `npm run build`. No hay un comando de tests de frontend en este stage. |
| 4 | `Docker Build and Push` | Usa la credencial del registry e invoca `scripts/ci/build-and-push.sh`. |
| 5 | `Deploy Helm` | Solo con `DEPLOY=true`; enlaza credenciales e invoca el despliegue Bash con imágenes publicadas, host, namespace y archivo de secretos. |

No hay una etapa de Snyk implementada en este flujo. Tampoco se ejecutan los wrappers PowerShell de análisis del repositorio: no atribuir sus reportes históricos a esta pipeline.

Los errores de ejecución de Semgrep también detienen el stage. Sus archivos de reglas se cargan como configuracion pero se excluyen como objetivos: los ejemplos de patrones de secretos dentro de esas reglas no son credenciales de la aplicacion. Los reportes históricos no son resultados de la corrida actual.

## Publicación y despliegue

El script de publicación construye ambas imágenes usando los Dockerfiles de producción y publica:

```text
docker.io/agustingarciaa/playhub-backend:<BUILD_NUMBER>-<GIT_SHORT>
docker.io/agustingarciaa/playhub-frontend:<BUILD_NUMBER>-<GIT_SHORT>
```

Es un formato, no una referencia a una ejecución concreta. El frontend recibe `NEXT_PUBLIC_API_URL=PUBLIC_URL` durante el build. Modificar luego el host del despliegue no cambia la URL incorporada en una imagen ya construida.

La publicación y el despliegue usan el mismo `IMAGE_TAG`. El despliegue remoto:

1. Utiliza el kubeconfig entregado por Jenkins y comprueba conectividad y configuración de Ingress. Las consultas de preparación tienen timeout de 20 segundos por petición; la lectura de `/version` reintenta hasta tres veces ante fallos transitorios y conserva el error real de conexión, autenticación o TLS.
2. Omite construir/cargar imágenes y abrir port-forward; usa las imágenes del registry.
3. Habilita monitoreo limitado al namespace por defecto. El descubrimiento de los pods de backend usa DNS de un Service headless, sin permisos para consultar la API Kubernetes. El perfil `lab` usa almacenamiento efimero para no crear mas PVC.
4. Omite, instala o adopta Kyverno/Falco según `SECURITY_MODE`.
5. Genera un archivo temporal de valores con secretos, imágenes, Ingress, CORS y cookies; lo elimina al terminar.
6. Ejecuta `helm lint`, prepara el namespace cuando corresponde y crea/actualiza `regcred` con las credenciales del registry.
7. Vuelve a comprobar conectividad antes de ejecutar `helm upgrade --install --atomic --wait`, con timeout remoto de 10 minutos por defecto. No reintenta automáticamente una instalación/actualización que pudo haber creado recursos.
8. Ejecuta `helm test` con el mismo timeout y, si se solicitó, comprueba `PUBLIC_URL/login` con reintentos.

`--atomic` corresponde a la operación de instalación/actualización de Helm. `helm test` y la verificación pública ocurren después; no se debe afirmar que su fallo provoca automáticamente un rollback de esa operación ya finalizada.

Antes de desplegar se comprueba el historial. La recuperacion automatica solo acepta revision 1, unico registro, estado `pending-install` y antiguedad mayor a una hora. Con `RECOVER_PENDING_INSTALL=true`, verifica `helm.sh/resource-policy=keep` en el PVC de PostgreSQL y en el manifiesto guardado de Helm, retira los recursos de esa instalacion con `helm uninstall --keep-history --no-hooks --wait` y reinstala. Esto interrumpe los pods incompletos de PlayHub y conserva los datos del PVC; debe mantenerse el mismo `DB_PASSWORD`. Operaciones recientes, upgrades pendientes y PVC sin retencion se rechazan sin desinstalar. No modifica otros releases del namespace.

La verificacion publica exige `/login` HTTP 200 y `/api/games` HTTP 401 sin credenciales (la API requiere autenticacion). Un 503 del backend hace fallar el despliegue aunque el frontend cargue.

Si falla la operación Helm o su test, el script guarda `reports/deploy-diagnostics.txt`. Primero consulta la API con timeout; si sigue inaccesible, omite las consultas adicionales. Si responde, recopila el estado de Deployments, ReplicaSets, pods, Services, PVCs, Ingress y eventos, sin volcar valores de Secrets. Con `--atomic`, algunos recursos pueden haber sido eliminados o revertidos antes de recopilar ese estado.

Un error `dial tcp ...:443: i/o timeout`, `unexpected EOF` o `connection refused` indica un problema de comunicación con la API Kubernetes. No demuestra un fallo del chart ni permite distinguir por sí solo entre caída del servidor, proxy, firewall o red del agente. Aumentar el timeout de Helm no restablece esa conexión. Comprobar desde el mismo agente/contenedor Jenkins, usando su credencial:

```bash
kubectl --kubeconfig "$KUBECONFIG_FILE" --request-timeout=20s get --raw /version
kubectl --kubeconfig "$KUBECONFIG_FILE" --request-timeout=20s get pods -n alumno-team9
```

Que estos comandos funcionen en otra máquina no confirma la conectividad del agente. Un `Forbidden` al consultar `IngressClass` es distinto: la cuenta del laboratorio puede gestionar recursos del namespace sin permisos para listar recursos globales. El script conserva ese aviso y continúa; los errores de red se reportan como tales. Tampoco intenta crear un namespace cuando la consulta falla por problemas de conexión.

Si `SECURITY_MODE` es distinto de `skip` y el despliegue alcanza ese punto, Jenkins recopila el estado de políticas y Falco en `reports/security-stack.txt`. Las consultas usan `|| true`: ese archivo es un resumen de estado, no una validación de admisión ni la evidencia de un evento Falco.

## Resultados y artefactos

| Resultado | Dónde consultarlo |
| --- | --- |
| Consola de cada etapa | Build correspondiente en Jenkins, con timestamps. |
| Semgrep de la corrida | Artefacto `reports/ci/semgrep.json`. |
| Tests Java | Resultados JUnit de `backend/target/surefire-reports/*.xml`. |
| Diagnóstico de un fallo de Helm o `helm test` | `reports/deploy-diagnostics.txt`, si se alcanza esa operación y falla. |
| Estado opcional de seguridad | `reports/security-stack.txt`, bajo las condiciones anteriores. |
| Imágenes publicadas | Registry, con el tag mostrado en `Checkout` y publicación. |
| Release desplegado | Namespace elegido, mediante Helm y kubectl. |

El bloque `post` archiva `reports/ci/**` y los diagnosticos de despliegue/seguridad, y limpia el workspace con `cleanWs()`. JUnit se publica una sola vez, en el `post` del backend. Los reportes historicos versionados no se archivan como resultados actuales. El reporte existente de Snyk no prueba que Jenkins haya ejecutado Snyk.

La pipeline impide builds concurrentes de este job, tiene timeout global de 45 minutos y conserva hasta 20 builds y artefactos de hasta 10 builds. La publicación de JUnit en la rama Backend exige resultados; si no se generan XML, ese paso también informa un fallo.

## Evidencias de ejecución

**TBD:** adjuntar una corrida identificada por número de build, commit, parámetros, resultado, reportes y comprobaciones del release. No se agregan capturas ni salidas inventadas.
