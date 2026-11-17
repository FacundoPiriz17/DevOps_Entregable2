# Comandos de CI y despliegue de PlayHub

Esta guía documenta los comandos relacionados con la [pipeline de Jenkins](../../jenkins/README.md). Los ejemplos se ejecutan desde la **raíz del repositorio**. Para Minikube, Blue/Green, carga de tráfico y limpieza local, consultar [scripts/README.md](../README.md).

Los comandos de publicación y despliegue tienen efectos reales si se ejecutan. Son recetas de uso basadas en los scripts actuales; no fueron ejecutados al escribir esta documentación. Elegir el recorrido necesario, sin repetir manualmente una publicación o despliegue que ya esté realizando Jenkins.

## Índice

- [Scripts utilizados](#scripts-utilizados)
- [Preparar herramientas](#preparar-herramientas)
- [Publicar imágenes manualmente](#publicar-imágenes-manualmente)
- [Preparar secretos de la aplicación](#preparar-secretos-de-la-aplicación)
- [Desplegar las imágenes publicadas](#desplegar-las-imágenes-publicadas)
- [Opciones del despliegue Bash](#opciones-del-despliegue-bash)
- [Verificar el despliegue](#verificar-el-despliegue)
- [Limpiar el release remoto](#limpiar-el-release-remoto)
- [Reproducir el análisis Semgrep](#reproducir-el-análisis-semgrep)
- [Diagnóstico](#diagnóstico)

## Scripts utilizados

| Archivo | Uso |
| --- | --- |
| `scripts/ci/build-and-push.sh` | Construye y publica backend/frontend a partir de variables de entorno. |
| `scripts/deploy-helm.sh` | Con `--registry`, despliega imágenes publicadas en un clúster remoto. |
| `scripts/cleanup-helm.sh` | Retira el release del namespace seleccionado; lee el kubeconfig del entorno/contexto. |

Los parámetros remotos son de la variante **Bash**. `scripts/deploy-helm.ps1` conserva su interfaz local y no tiene las opciones `--registry`, `--kubeconfig` o `--secrets-file` de estos ejemplos. Desde Windows, usar un entorno Bash con las herramientas y rutas correspondientes.

## Preparar herramientas

Comprobar las herramientas sin iniciar publicaciones ni despliegues:

```bash
git --version
bash --version
docker version
helm version --short
kubectl version --client
python3 --version
```

La publicación necesita Docker. El despliegue necesita Bash, Helm, kubectl y curl; el instalador de seguridad requiere Python 3. Para usar Python con otro nombre, la utilidad de seguridad también permite la variable `PYTHON`.

La imagen Jenkins se construye con:

```bash
docker build --file jenkins/Dockerfile.jenkins --tag playhub-jenkins:local jenkins
```

Esto no crea ni ejecuta un job. La configuración de Jenkins, credenciales y parámetros está en [jenkins/README.md](../../jenkins/README.md).

## Publicar imágenes manualmente

`build-and-push.sh` no recibe argumentos de línea de comandos. Usa estas variables:

| Variable | Obligatoria | Descripción |
| --- | --- | --- |
| `REGISTRY` | Sí | Prefijo del registry y cuenta, por ejemplo `docker.io/agustingarciaa`. |
| `IMAGE_TAG` | Sí | Tag que se aplicará a ambas imágenes. Jenkins usa número de build y commit corto. |
| `PUBLIC_URL` | Sí | Origen público completo de la aplicación; se incorpora como `NEXT_PUBLIC_API_URL` al frontend. |
| `REG_USER` | Sí | Usuario con permiso de publicación. |
| `REG_PASS` | Sí | Token o contraseña del registry. |
| `IMAGE_BE` | No | Repositorio de backend; por defecto `$REGISTRY/playhub-backend`. |
| `IMAGE_FE` | No | Repositorio de frontend; por defecto `$REGISTRY/playhub-frontend`. |

Preparar una sesión Bash sin escribir el token literalmente en el comando:

```bash
export REGISTRY=docker.io/agustingarciaa
export PUBLIC_URL=https://playhub-team9.reto-ucu.net
export IMAGE_TAG="manual-$(date -u +%Y%m%d%H%M%S)-$(git rev-parse --short HEAD)"
read -r -p "Usuario del registry: " REG_USER
read -r -s -p "Token del registry: " REG_PASS
printf '\n'
export REG_USER REG_PASS
bash scripts/ci/build-and-push.sh
```

Adaptar registry, host y usuario al destino real. Si ya se definieron `IMAGE_BE` o `IMAGE_FE` en esa sesión, revisar sus valores: tienen prioridad sobre los nombres por defecto. El despliegue remoto actual construye los nombres a partir de `REGISTRY/playhub-backend` y `REGISTRY/playhub-frontend`, por lo que los repositorios publicados deben coincidir con ellos.

El script inicia sesión con `docker login --password-stdin`, construye las dos imágenes y ejecuta ambos `docker push`. Al terminar cierra la sesión del registry. Si un push falla, la etapa falla y puede haber quedado publicada la primera imagen; la publicación no es una operación atómica.

El script de publicación no ejecuta tests ni análisis de seguridad. En Jenkins esas etapas están antes; una invocación manual aislada no las reemplaza.

## Preparar secretos de la aplicación

Crear el archivo local a partir del ejemplo:

```bash
cp jenkins/app-secrets.env.example playhub-app-secrets.env
```

Editar sus tres valores antes de desplegar:

```text
DB_PASSWORD=valor_propio
JWT_SECRET=valor_propio_de_al_menos_48_bytes_UTF8
ADMIN_PASSWORD=valor_propio
```

El bloque indica el formato, no credenciales que deban reutilizarse. `playhub-app-secrets.env` está excluido de Git. El parser acepta las claves indicadas, líneas vacías y comentarios; no ejecutar el archivo con `source`, ni agregar claves ajenas o prefijos `export`.

Jenkins recibe este contenido como credencial **Secret file** `playhub-app-secrets`; no necesita crear el archivo en el checkout. El script lo lee solamente cuando se pasa `--secrets-file`.

## Desplegar las imágenes publicadas

La API Kubernetes debe ser accesible, el namespace debe estar disponible o poder crearse, y el Ingress/DNS del host deben estar preparados por la plataforma. Se requiere una StorageClass para PostgreSQL.

En la misma sesión de publicación, con `IMAGE_TAG` correspondiente a imágenes ya publicadas, `REG_USER` y `REG_PASS` definidos, y el kubeconfig disponible:

```bash
bash scripts/deploy-helm.sh \
  --environment dev \
  --namespace alumno-team9 \
  --release-name playhub \
  --kubeconfig ./team9.kubeconfig \
  --registry "$REGISTRY" \
  --image-tag "$IMAGE_TAG" \
  --public-host playhub-team9.reto-ucu.net \
  --public-scheme https \
  --ingress-class apisix \
  --secrets-file ./playhub-app-secrets.env \
  --skip-security \
  --no-monitoring \
  --verify
```

Si las imágenes fueron publicadas por Jenkins, definir `IMAGE_TAG` con el tag que mostró ese build, en lugar de generar uno manual nuevo. El host/esquema deben coincidir con `PUBLIC_URL` utilizado durante el build del frontend.

Este ejemplo utiliza los nombres predeterminados del job; no afirma que el archivo `team9.kubeconfig`, las credenciales, DNS o permisos estén incluidos en Git. `--skip-security` conserva las instalaciones administradas por la plataforma. El script exige `REG_USER` y `REG_PASS` y crea el imagePullSecret incluso si las imágenes son públicas.

La ruta remota omite build, carga a Minikube y port-forward, y aplica el perfil `lab` por defecto. El ejemplo usa `--no-monitoring`, igual que Jenkins con `MONITORING_MODE=disabled`: los limites de CPU de los pods de la aplicacion suman 600m y el pod temporal de Helm test agrega 100m. PostgreSQL conserva su PVC. Sin esa opcion, el script Bash habilita monitoreo en modo `namespace` y los limites suman 850m, mas el test. El descubrimiento usa DNS y no necesita Roles ni acceso a nodos; el monitoreo usa `emptyDir` para no consumir PVC adicionales. `--resource-profile standard --monitoring-mode cluster` requiere cuotas y permisos de infraestructura suficientes. Deshabilitar monitoreo no resuelve la falta de almacenamiento efimero del nodo.

Para TLS gestionado por el propio Ingress, se agregan `--tls --tls-issuer NOMBRE`, siempre que exista cert-manager y ese ClusterIssuer. Si HTTPS termina en la plataforma, como en el ejemplo, se utiliza `--public-scheme https` sin `--tls`.

## Opciones del despliegue Bash

| Opción | Valor por defecto / comportamiento |
| --- | --- |
| `--environment dev` o `prod` | `dev`; selecciona el archivo de valores. |
| `--namespace NOMBRE` | `playhub-helm`; Jenkins pasa `alumno-team9`. |
| `--release-name NOMBRE` | `playhub`. |
| `--kubeconfig RUTA` | Si no se indica, utiliza `KUBECONFIG` o el contexto actual. |
| `--registry PREFIJO` | Activa el modo remoto. |
| `--image-tag TAG` | Tag de ambas imágenes; necesario para la publicación que se pretende desplegar. |
| `--public-host HOST` | Obligatorio en modo remoto; sin esquema ni ruta. |
| `--public-scheme http` o `https` | Si no se pasa: `https` con `--tls`, `http` sin él. Jenkins pasa explícitamente su parámetro. |
| `--ingress-class CLASE` | `nginx` en remoto si no se indica; Jenkins pasa `apisix` por defecto. |
| `--registry-secret NOMBRE` | `regcred`; Secret de acceso al registry. |
| `--secrets-file RUTA` | Archivo con las tres credenciales de aplicación. |
| `--db-password`, `--jwt-secret`, `--admin-password` | Alternativa por argumentos; se prefiere el archivo para evitar valores literales en el historial. |
| `--tls` | Habilita TLS y anotación de cert-manager en el Ingress. |
| `--tls-issuer NOMBRE` | `letsencrypt-prod`; se consulta si se activa TLS. |
| `--tls-secret NOMBRE` | `<release>-tls`. |
| `--verify` | Exige `/login` 200 y `/api/games` 401 sin autenticar; detecta un backend 503. |
| `--wait-timeout DURACIÓN` | `10m` remoto y `5m` local. |
| `--no-monitoring` | Deshabilita monitoreo. |
| `--monitoring-mode namespace\|cluster` | Remoto: `namespace`; local: `cluster`. |
| `--resource-profile lab\|standard` | Remoto: `lab`; local: `standard`. El perfil lab prevalece sobre el dimensionamiento dev/prod. |
| `--recover-pending-install` | Recupera exclusivamente el primer install pendiente de mas de una hora, con PVC retenido. No recupera upgrades pendientes. |
| `--skip-security` | No instala ni adopta Kyverno/Falco. |
| `--adopt-security` | Registra una instalación compatible del proyecto. No se combina con `--skip-security`. |

Los modos de instalación/adopción de seguridad comprueban permisos de alcance clúster y versiones. No activarlos sobre instalaciones ajenas sin la coordinación correspondiente. La [guía general](../README.md) detalla esa distinción.

El script no tiene un modo de simulación del despliegue remoto. Para una validación de sintaxis del chart sin publicar ni desplegar:

```bash
helm lint ./helm-chart -f ./helm-chart/values-dev.yaml
```

Eso valida los valores locales de desarrollo, no los permisos, credenciales, imágenes o Ingress del destino remoto.

## Verificar el despliegue

```bash
kubectl --kubeconfig ./team9.kubeconfig get pods,svc,pvc,ingress -n alumno-team9
helm --kubeconfig ./team9.kubeconfig status playhub -n alumno-team9
helm --kubeconfig ./team9.kubeconfig history playhub -n alumno-team9
```

Se espera que las imágenes de los Deployments lleven el tag publicado, los pods de la aplicación estén listos y el PVC esté `Bound`. Consultar las imágenes sin leer secretos:

```bash
kubectl --kubeconfig ./team9.kubeconfig get deployments -n alumno-team9 \
  -o 'custom-columns=NAME:.metadata.name,IMAGES:.spec.template.spec.containers[*].image'
```

`--verify` comprueba frontend y API; no realiza una compra ni verifica los dashboards. Para mostrar HTTP y negocio, consultar [monitoreo limitado al namespace](../../monitoring/README.md#monitoreo-limitado-al-namespace-del-laboratorio).

Para los logs, con el release predeterminado:

```bash
kubectl --kubeconfig ./team9.kubeconfig logs -n alumno-team9 deployment/playhub-backend
kubectl --kubeconfig ./team9.kubeconfig logs -n alumno-team9 deployment/playhub-backend -c flyway-migrate
kubectl --kubeconfig ./team9.kubeconfig get events -n alumno-team9 --sort-by=.lastTimestamp
```

## Limpiar el release remoto

`cleanup-helm.sh` no tiene un parámetro `--kubeconfig`; se utiliza la variable de entorno. Primero revisar las acciones:

```bash
KUBECONFIG=./team9.kubeconfig bash scripts/cleanup-helm.sh \
  --namespace alumno-team9 --release-name playhub --dry-run
```

Para retirar solamente el release y conservar sus datos:

```bash
KUBECONFIG=./team9.kubeconfig bash scripts/cleanup-helm.sh \
  --namespace alumno-team9 --release-name playhub
```

Este comando no elimina el namespace compartido, las imágenes del registry ni el Secret `regcred` creado por fuera del release. `--delete-data` elimina los PVC del release y sus datos; usarlo solo si se pretende ese resultado. Las opciones de retirada de seguridad no son parte del ejemplo remoto compartido.

## Reproducir el análisis Semgrep

Con Semgrep instalado en el entorno de ejecución, la invocación equivalente a la etapa actual es:

```bash
mkdir -p reports/ci
semgrep --version
semgrep scan \
  --oss-only --jobs=2 --timeout=15 \
  --config security/semgrep/rules \
  --exclude node_modules --exclude .next --exclude target \
  --exclude .tmp --exclude reports --exclude docs/generated \
  --exclude security/semgrep/rules \
  --severity ERROR --error \
  --metrics=off --disable-version-check \
  --json --output reports/ci/semgrep.json .
```

El punto final selecciona la raíz del checkout, equivalente al destino implícito de la etapa. Usa las reglas versionadas, sin descargarlas en cada corrida. `--error` bloquea la pipeline ante hallazgos de severidad ERROR.

## Diagnóstico

| Situación | Comprobación relacionada con la implementación |
| --- | --- |
| `No such container` al ejecutar Maven o Node | Revisar si `$HOSTNAME` identifica el contenedor del agente y si se utiliza el mismo daemon Docker. |
| Permiso denegado sobre el socket o workspace | Revisar UID/GID efectivo del agente y del contenedor Maven, y permisos de volúmenes. |
| Falla de autenticación del push | Revisar credencial `docker-registry`, cuenta de destino y permisos de publicación. |
| No se encuentra un tag en Kubernetes | Comparar el tag del build/push con `--image-tag` y los repositorios efectivos. |
| Error de secretos o JWT | Revisar las tres claves del archivo y longitud del JWT, sin imprimir los valores en consola. |
| Ingress/TLS no verificable | Revisar DNS, IngressClass, terminación HTTPS y, si se usa `--tls`, el ClusterIssuer. |
| No aparecen Grafana/Prometheus tras el deploy | Jenkins usa `MONITORING_MODE=disabled` por defecto. Para habilitarlos, seleccionar `namespace` y revisar cuotas y eventos. En Bash, omitir `--no-monitoring`. |

El detalle del flujo y sus pendientes se mantiene en [jenkins/README.md](../../jenkins/README.md).
