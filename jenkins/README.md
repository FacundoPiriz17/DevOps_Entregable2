# Pipeline de Jenkins de PlayHub

Esta guía documenta la implementación actual de `jenkins/Jenkinsfile`. Amplía el [README principal](../README.md) y se complementa con los [comandos de CI y despliegue](../scripts/ci/README.md) y la [guía general de scripts](../scripts/README.md).

La documentación se preparó mediante revisión de los archivos. No constituye evidencia de una ejecución de Jenkins, publicación de imágenes o despliegue nuevos. La incorporación de Snyk y los ajustes del agente y del monitoreo remoto siguen pendientes.

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
- En la implementación actual, un agente ejecutado dentro de un contenedor que el daemon pueda identificar mediante `$HOSTNAME`. Los contenedores de build usan `--volumes-from "$HOSTNAME"` para compartir el workspace.
- Permisos del usuario efectivo sobre el workspace y el socket Docker. El contenedor Maven recibe el UID/GID del agente; la accesibilidad del socket también debe ser válida para ese usuario.
- Salida a los registros de imágenes, repositorios Maven/npm y reglas remotas de Semgrep. Para desplegar, también conectividad hacia la API Kubernetes y, si se verifica la URL, hacia el host público.

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
| `DEPLOY` | `false` | Habilita el stage `Deploy Helm`. Con `false` las imágenes igualmente se construyen y publican. |
| `NAMESPACE` | `alumno-team9` | Namespace de la aplicación. |
| `PUBLIC_HOST` | `playhub-team9.reto-ucu.net` | Host público sin esquema ni ruta; se utiliza también durante el build del frontend. |
| `PUBLIC_SCHEME` | `https` | `https` o `http`; compone `PUBLIC_URL`. |
| `MANAGE_TLS` | `false` | Agrega `--tls` para gestionar TLS del Ingress con cert-manager. |
| `INGRESS_CLASS` | `apisix` | Clase del Ingress de destino. |
| `SECURITY_MODE` | `skip` | `skip`, `install` o `adopt` para Kyverno/Falco. |
| `VALUES_ENV` | `dev` | Archivo `values-dev.yaml` o `values-prod.yaml`. |
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
| 2 | `SAST - Semgrep` | Ejecuta reglas locales, `p/security-audit` y `p/owasp-top-ten`; filtra severidad `ERROR`, excluye directorios de dependencias/build y genera `reports/semgrep.json`. |
| 3 | `Build and Test` | Ejecuta las ramas Backend y Frontend en paralelo, con `failFast true`. |
| 3a | `Backend` | Contenedor `maven:3.9-eclipse-temurin-26`, workspace compartido, socket Docker y configuración de host para Testcontainers; ejecuta `mvn -B clean verify`. Publica Surefire con JUnit. |
| 3b | `Frontend` | Contenedor `node:22-alpine`; ejecuta `npm ci`, `npm run lint` y `npm run build`. No hay un comando de tests de frontend en este stage. |
| 4 | `Docker Build and Push` | Usa la credencial del registry e invoca `scripts/ci/build-and-push.sh`. |
| 5 | `Deploy Helm` | Solo con `DEPLOY=true`; enlaza credenciales e invoca el despliegue Bash con imágenes publicadas, host, namespace y archivo de secretos. |

No hay una etapa de Snyk implementada en este flujo. Tampoco se ejecutan los wrappers PowerShell de análisis del repositorio: no atribuir sus reportes históricos a esta pipeline.

`--severity ERROR` selecciona qué hallazgos informa Semgrep; la invocación actual no incluye `--error`, por lo que no se debe documentar como un bloqueo por hallazgos. Los errores de ejecución del comando sí pueden detener el stage.

## Publicación y despliegue

El script de publicación construye ambas imágenes usando los Dockerfiles de producción y publica:

```text
docker.io/agustingarciaa/playhub-backend:<BUILD_NUMBER>-<GIT_SHORT>
docker.io/agustingarciaa/playhub-frontend:<BUILD_NUMBER>-<GIT_SHORT>
```

Es un formato, no una referencia a una ejecución concreta. El frontend recibe `NEXT_PUBLIC_API_URL=PUBLIC_URL` durante el build. Modificar luego el host del despliegue no cambia la URL incorporada en una imagen ya construida.

La publicación y el despliegue usan el mismo `IMAGE_TAG`. El despliegue remoto:

1. Utiliza el kubeconfig entregado por Jenkins y comprueba conectividad y configuración de Ingress.
2. Omite construir/cargar imágenes y abrir port-forward; usa las imágenes del registry.
3. Deshabilita Prometheus/Grafana del release. Este comportamiento no depende del valor base `monitoring.enabled` del chart.
4. Omite, instala o adopta Kyverno/Falco según `SECURITY_MODE`.
5. Genera un archivo temporal de valores con secretos, imágenes, Ingress, CORS y cookies; lo elimina al terminar.
6. Ejecuta `helm lint`, prepara el namespace cuando corresponde y crea/actualiza `regcred` con las credenciales del registry.
7. Ejecuta `helm upgrade --install --atomic --wait`, con timeout remoto de 10 minutos por defecto.
8. Ejecuta `helm test` y, si se solicitó, comprueba `PUBLIC_URL/login` con reintentos.

`--atomic` corresponde a la operación de instalación/actualización de Helm. `helm test` y la verificación pública ocurren después; no se debe afirmar que su fallo provoca automáticamente un rollback de esa operación ya finalizada.

Si `SECURITY_MODE` es distinto de `skip` y el despliegue alcanza ese punto, Jenkins recopila el estado de políticas y Falco en `reports/security-stack.txt`. Las consultas usan `|| true`: ese archivo es un resumen de estado, no una validación de admisión ni la evidencia de un evento Falco.

## Resultados y artefactos

| Resultado | Dónde consultarlo |
| --- | --- |
| Consola de cada etapa | Build correspondiente en Jenkins, con timestamps. |
| Semgrep de la corrida | Artefacto `reports/semgrep.json`. |
| Tests Java | Resultados JUnit de `backend/target/surefire-reports/*.xml`. |
| Estado opcional de seguridad | `reports/security-stack.txt`, bajo las condiciones anteriores. |
| Imágenes publicadas | Registry, con el tag mostrado en `Checkout` y publicación. |
| Release desplegado | Namespace elegido, mediante Helm y kubectl. |

El bloque `post` archiva `reports/**`, publica JUnit y limpia el workspace con `cleanWs()`. Como `reports/` también contiene archivos versionados, un artefacto archivado puede ser un reporte histórico que esta corrida no regeneró. El reporte existente de Snyk no prueba que Jenkins haya ejecutado Snyk.

La pipeline impide builds concurrentes de este job, tiene timeout global de 45 minutos y conserva hasta 20 builds y artefactos de hasta 10 builds. La publicación de JUnit en la rama Backend exige resultados; si no se generan XML, ese paso también informa un fallo.

## Evidencias de ejecución

**TBD:** adjuntar una corrida identificada por número de build, commit, parámetros, resultado, reportes y comprobaciones del release. No se agregan capturas ni salidas inventadas.
