# Guía de scripts de PlayHub

Esta guía amplía el [README principal](../README.md). Los ejemplos se ejecutan desde la **raíz del repositorio**, aunque este documento se encuentre en `scripts/`. Se documentan opciones existentes; los resultados esperados no son nuevas evidencias de ejecución.

## Elegir la modalidad de despliegue

| Modalidad | Despliegue | Limpieza | Alcance |
| --- | --- | --- | --- |
| Helm, recorrido principal | `deploy-helm.sh` / `deploy-helm.ps1` | `cleanup-helm.sh` / `cleanup-helm.ps1` | Release `playhub`, namespace `playhub-helm`, slot `helm`. |
| Manifiestos Blue/Green | `deploy.sh` / `deploy.ps1` | `cleanup.sh` / `cleanup.ps1` | Namespace del contexto activo; Blue y, opcionalmente, Green. |

Ambas modalidades incluyen monitoreo y utilizan el mismo stack de seguridad compartido. No intercambiar sus scripts de limpieza. Las alternativas de los ejemplos son excluyentes: elegir Bash o PowerShell y la modalidad correspondiente.

## Preparar herramientas y clúster

Los scripts no crean el clúster. Docker, Minikube, `kubectl` y Python deben estar disponibles. La demo Bash requiere Bash 4+, `curl`, Python 3 y utilidades como `shuf`; la demo PowerShell requiere `curl.exe`.

```bash
minikube start
kubectl config use-context minikube
bash scripts/install-helm.sh
export PATH="$HOME/.local/bin:$PATH"
```

```powershell
minikube start
kubectl config use-context minikube
.\scripts\install-helm.ps1
```

Opciones del instalador de Helm:

| Bash | PowerShell | Uso |
| --- | --- | --- |
| `--version vX.Y.Z` | `-Version vX.Y.Z` | Elegir versión; el valor actual por defecto es `v4.3.1`. |
| `--install-dir RUTA` | `-InstallDir RUTA` | Cambiar carpeta de instalación. |
| `--force` | `-Force` | Instalar aunque Helm ya se encuentre en `PATH`. |

El instalador verifica SHA256. Bash instala por defecto en `$HOME/.local/bin`; PowerShell, en `%LOCALAPPDATA%\Programs\helm`. Si se modifica el destino, ajustar `PATH` antes de desplegar.

## Despliegue con Helm

```bash
bash scripts/deploy-helm.sh
```

```powershell
.\scripts\deploy-helm.ps1
```

El script construye, carga las imágenes en Minikube, valida el chart, prepara seguridad, instala o actualiza el release, espera los recursos, ejecuta el hook de prueba y abre los accesos de frontend, backend, Prometheus y Grafana.

| Bash | PowerShell | Comportamiento |
| --- | --- | --- |
| `--environment dev` o `prod` | `-Environment dev` o `prod` | Selecciona `values-dev.yaml` o `values-prod.yaml`. |
| `--namespace NOMBRE` | `-Namespace NOMBRE` | Namespace; por defecto `playhub-helm`. |
| `--release-name NOMBRE` | `-ReleaseName NOMBRE` | Release; por defecto `playhub`. |
| `--skip-build` | `-SkipBuild` | Reutiliza las imágenes locales; no reconstruye. |
| `--skip-image-load` | `-SkipImageLoad` | Omite la importación; las imágenes deben existir en el runtime del clúster. |
| `--no-port-forward` | `-NoPortForward` | Despliega sin abrir los accesos locales. |
| `--skip-security` | `-SkipSecurity` | No instala ni adopta Kyverno/Falco. |
| `--adopt-security` | `-AdoptSecurity` | Registra la instalación compatible existente como instalación de PlayHub. |
| `--db-password VALOR` | `-DbPassword VALOR` | Credencial obligatoria para `prod`. |
| `--jwt-secret VALOR` | `-JwtSecret VALOR` | Secreto obligatorio para `prod`, mínimo 48 bytes UTF-8. |
| `--admin-password VALOR` | `-AdminPassword VALOR` | Credencial obligatoria para `prod`. |

Ejemplos para reutilizar imágenes sin reconstruir, conservando su carga al clúster:

```bash
bash scripts/deploy-helm.sh --skip-build
```

```powershell
.\scripts\deploy-helm.ps1 -SkipBuild
```

Si las imágenes ya están cargadas y son las correctas:

```bash
bash scripts/deploy-helm.sh --skip-build --skip-image-load --no-port-forward
```

```powershell
.\scripts\deploy-helm.ps1 -SkipBuild -SkipImageLoad -NoPortForward
```

Las etiquetas reutilizadas no garantizan que el código de una imagen coincida con el checkout actual. Si cambia Java, Next.js o `NEXT_PUBLIC_API_URL`, reconstruir la imagen correspondiente.

El detalle de `prod`, Ingress y la instalación manual con `helm install` se mantiene en [helm-chart/README.md](../helm-chart/README.md). Los scripts Helm no leen `.env`.

## Seguridad compartida del clúster

Por defecto los despliegues llaman a `lib/security-stack.py`, mediante los wrappers Bash o PowerShell. Esta utilidad instala Kyverno **1.19.2**, aplica las cuatro políticas e instala el chart Falco **9.2.2** con `security/falco/values.yaml`.

Si existe una instalación sin el marcador `playhub-security-owner`, el script no la adopta automáticamente:

- Para utilizar seguridad administrada por fuera del proyecto, elegir `--skip-security` / `-SkipSecurity`.
- Para registrar una instalación de PlayHub compatible, elegir `--adopt-security` / `-AdoptSecurity`. La utilidad comprueba versiones y recursos antes de continuar.
- No combinar omisión y adopción: los scripts rechazan esa combinación.

Ejemplos alternativos sobre una instalación existente:

```bash
bash scripts/deploy-helm.sh --skip-build --skip-security
# Solo si la instalación compatible corresponde a este proyecto:
bash scripts/deploy-helm.sh --skip-build --adopt-security
```

```powershell
.\scripts\deploy-helm.ps1 -SkipBuild -SkipSecurity
# Solo si la instalación compatible corresponde a este proyecto:
.\scripts\deploy-helm.ps1 -SkipBuild -AdoptSecurity
```

También hay instaladores independientes:

```bash
bash scripts/install-kyverno.sh
bash scripts/deploy-falco.sh
```

```powershell
.\scripts\install-kyverno.ps1
.\scripts\deploy-falco.ps1
```

Sus opciones de adopción son `--adopt-existing` y `-AdoptExisting`, respectivamente; no llevan el nombre `AdoptSecurity`. Kyverno acepta además `--version` / `-Version`. Esta opción no implica que las políticas del proyecto hayan sido verificadas con cualquier versión.

## Generar tráfico y poblar los dashboards

Con los cuatro accesos locales activos:

```bash
bash scripts/demo-monitoring.sh
bash scripts/demo-monitoring.sh --synthetic-users 8 --burst-seconds 60 --burst-concurrency 12
```

```powershell
.\scripts\demo-monitoring.ps1
.\scripts\demo-monitoring.ps1 -SyntheticUsers 8 -BurstSeconds 60 -BurstConcurrency 12
```

La segunda invocación de cada bloque es una alternativa con más carga; no hace falta ejecutar ambas. La demo utiliza los usuarios de prueba de `V2__demo_data.sql`, crea usuarios sintéticos, consulta catálogo y biblioteca, realiza compras, provoca errores 4xx y ejecuta una ráfaga concurrente.

| Bash | PowerShell | Valor por defecto / efecto |
| --- | --- | --- |
| `--synthetic-users N` | `-SyntheticUsers N` | 5 usuarios. |
| `--burst-seconds N` | `-BurstSeconds N` | 30 segundos. |
| `--burst-concurrency N` | `-BurstConcurrency N` | 8 workers. |
| `--timeout N` | `-TimeoutSec N` | 180 segundos para las esperas de la demo. |
| `--api-url URL` | `-ApiUrl URL` | `http://localhost:8080`. |
| `--frontend-url URL` | `-FrontendUrl URL` | `http://localhost:5745`. |
| `--prometheus-url URL` | `-PrometheusUrl URL` | `http://localhost:9090`. |
| `--keep-users` | `-KeepUsers` | Conserva activos los usuarios sintéticos. |
| `--skip-frontend` | `-SkipFrontend` | Omite tráfico al frontend. |
| `--deploy` | `-Deploy` | Invoca `deploy.sh` / `deploy.ps1`, **no** el script Helm. |
| `--deploy-green` | `-DeployGreen` | Junto con la anterior, agrega Green al despliegue por manifiestos. |
| `--cluster-type TIPO` | `-ClusterType TIPO` | Se pasa al despliegue opcional; por defecto `minikube`. |

**Para el recorrido Helm, ejecutar la demo sin `--deploy` / `-Deploy`.** De lo contrario se inicia además la modalidad por manifiestos.

La salida muestra contadores antes y después y chequeos de incrementos: al menos una compra, los logins fallidos previstos, al menos 200 peticiones y target de backend disponible. Código 0 indica que se cumplieron los chequeos de esa corrida; 1 indica fallos y 2 problemas de preparación/disponibilidad. Revisar siempre los mensajes. La desactivación final no elimina las compras ni los registros creados.

## Manifiestos Blue/Green

Esta alternativa usa el namespace del contexto activo. Antes de ejecutarla, comprobar `kubectl config view --minify`; para el recorrido histórico en `default` puede fijarse con `kubectl config set-context --current --namespace=default`.

```bash
bash scripts/deploy.sh --cluster-type minikube --deploy-green
bash scripts/switch-slot.sh green
bash scripts/switch-slot.sh blue
```

```powershell
.\scripts\deploy.ps1 -ClusterType minikube -DeployGreen
.\scripts\switch-slot.ps1 green
.\scripts\switch-slot.ps1 blue
```

Los cambios de slot son operaciones independientes: elegir el destino que se quiere activar. `switch-slot` exige que el destino esté desplegado y listo. Actualiza los selectores de los Services estables; si falla el cambio del frontend, revierte el selector del backend. Reinicia los port-forward registrados por el despliegue por manifiestos.

Opciones adicionales de `deploy.sh` / `deploy.ps1`:

| Bash | PowerShell | Uso |
| --- | --- | --- |
| `--deploy-green` | `-DeployGreen` | Agrega el slot Green. |
| `--cluster-type TIPO` | `-ClusterType TIPO` | `auto`, `docker-desktop`, `kind`, `minikube`, `k3d` o `none`. |
| `--cluster-name NOMBRE` | `-ClusterName NOMBRE` | Perfil/nombre del clúster local. |
| `--frontend-api-url URL` | `-FrontendApiUrl URL` | URL pública que se incorpora al build del frontend. |
| `--skip-build`, `--skip-image-load` | `-SkipBuild`, `-SkipImageLoad` | Reutilizar imágenes construidas/cargadas. |
| `--no-port-forward` | `-NoPortForward` | Omitir accesos locales. |
| `--skip-security`, `--adopt-security` | `-SkipSecurity`, `-AdoptSecurity` | Misma distinción de seguridad compartida. |

Los secretos de esta modalidad se obtienen de `k8s/secret.yaml`, preparado a partir de `k8s/secret.yaml.example`; ese archivo está excluido de Git. No confundirlos con los valores que utiliza Helm.

## Análisis de seguridad y evidencias

Los siguientes scripts de análisis existen en **PowerShell**; no se presupone una variante Bash que no está en el repositorio:

```powershell
.\scripts\scan-semgrep.ps1
.\scripts\audit-frontend.ps1
.\scripts\lint-kubernetes.ps1
```

- `scan-semgrep.ps1`: requiere Docker, Git y `tar`. Usa reglas locales versionadas y genera `reports/semgrep_scan-post-mitigacion.txt`, `reports/semgrep-kubernetes-post-mitigacion.txt` y metadatos en `.tmp/security-reports/`. No reescribe `semgrep-report.txt`. No utiliza `--error`; puede terminar con código 0 aunque existan hallazgos.
- `audit-frontend.ps1`: ejecuta `npm ci` y los audits completo y de producción. `-SkipInstall` omite la instalación. Escribe `reports/npm-audit.txt` y `reports/npm-audit-produccion-post-mitigacion.txt`. Requiere Node y npm locales.
- `lint-kubernetes.ps1`: ejecuta KubeLinter en Docker sobre `k8s/` y `scripts/flyway-repair.yaml`; genera `reports/kubelinter.txt` y conserva el código de salida de la herramienta.
- `scan-images.ps1`: escanea las imágenes `v1.0` y exige que sus equivalentes `v2.0` tengan el mismo ID. Es apropiado después del build Blue/Green, que prepara ambas etiquetas; no asumir ese requisito satisfecho por un despliegue Helm aislado. Acepta `-TrivyVersion` y genera los reportes posteriores de Trivy.

Para Trivy después de preparar esas imágenes:

```powershell
.\scripts\scan-images.ps1
```

Para Kyverno, la validación completa existente también utiliza imágenes `v1.0`/`v2.0` y el manifiesto Falco renderizado en `.tmp/security-reports/falco-rendered.yaml`, que genera su instalador. Comprobar esos requisitos antes de ejecutar:

```powershell
.\scripts\validate-kyverno.ps1
Copy-Item -LiteralPath reports/kyvernovalidation.log -Destination reports/kyverno-validation.log
```

La copia del segundo comando se realiza después de revisar una validación correcta; adapta el nombre del archivo a la consigna. El script crea pruebas de admisión y un pod válido, comprueba UID no root y limpia el pod de prueba. No es una validación de arranque de todos los servicios renderizados.

El reporte Snyk se conserva en `reports/snyk-report.txt`. No hay un wrapper de Snyk en `scripts/`; el [documento de seguridad](../docs/security.md) distingue esa evidencia de las demás herramientas y de los cambios actuales de dependencias.

## Prueba de Falco válida para el laboratorio 4

Usar la prueba de **enlace simbólico**, no los scripts de shell históricos. Requiere Falco operativo, un backend Ready y Python disponible. Para el release Helm predeterminado:

```bash
bash scripts/simulate-symlink-attack.sh --namespace playhub-helm --selector app=playhub-backend
bash scripts/get-falco-symlink-report.sh --wait-seconds 30
```

```powershell
.\scripts\simulate-symlink-attack.ps1 -Namespace playhub-helm -LabelSelector app=playhub-backend
.\scripts\get-falco-symlink-report.ps1 -WaitSeconds 30
```

Para el despliegue Blue/Green histórico, cambiar el namespace a `default`. Si cambia el nombre base del release Helm, adaptar también el selector de la etiqueta `app`.

Los wrappers Bash utilizan `python3` por defecto. En Git Bash, si el ejecutable se llama `python`, anteponer `PYTHON=python` a cada comando. El ataque crea un enlace temporal hacia `/etc/shadow`, lo elimina y conserva los datos de la corrida en `.tmp/falco-symlink-test.json`. No abre una shell interactiva ni lee el archivo sensible.

El recolector correlaciona la regla, el enlace, el contenedor y la ventana de la corrida. Si encuentra una alerta, escribe `reports/falcoevent.log` y un informe fechado en `reports/falco/`. Si no la encuentra, falla sin reemplazar la evidencia válida anterior. Después de verificar el resultado, se puede adaptar el nombre a la consigna:

```bash
cp reports/falcoevent.log reports/falco-event.log
```

```powershell
Copy-Item -LiteralPath reports/falcoevent.log -Destination reports/falco-event.log
```

## Limpieza y persistencia

### Release Helm

```bash
bash scripts/cleanup-helm.sh --dry-run
bash scripts/cleanup-helm.sh
```

```powershell
.\scripts\cleanup-helm.ps1 -WhatIf
.\scripts\cleanup-helm.ps1
```

La limpieza normal desinstala el release, detiene sus port-forward y conserva los PVC de PostgreSQL, Prometheus y Grafana, junto con las imágenes y el stack de seguridad.

| Bash | PowerShell | Efecto adicional |
| --- | --- | --- |
| `--delete-data` | `-DeleteData` | Borra los PVC y sus datos. |
| `--delete-namespace` | `-DeleteNamespace` | Borra el namespace del release; **requiere** la opción anterior. |
| `--remove-images` | `-RemoveImages` | Retira las etiquetas PlayHub contempladas por el script de Docker y Minikube. |
| `--remove-security` | `-RemoveSecurity` | Retira Kyverno/políticas/Falco registrados por PlayHub si las comprobaciones de propiedad lo permiten. |
| `--namespace NOMBRE` | `-Namespace NOMBRE` | Debe coincidir con el despliegue. |
| `--release-name NOMBRE` | `-ReleaseName NOMBRE` | Debe coincidir con el despliegue. |
| `--minikube-profile NOMBRE` | `-MinikubeProfile NOMBRE` | Perfil del cual retirar imágenes; por defecto `minikube`. |
| `--dry-run` | `-WhatIf` | Muestra acciones sin realizarlas. |

Ejemplo de limpieza con borrado de datos, retirada de imágenes y seguridad:

```bash
bash scripts/cleanup-helm.sh --delete-data --delete-namespace --remove-images --remove-security
```

```powershell
.\scripts\cleanup-helm.ps1 -DeleteData -DeleteNamespace -RemoveImages -RemoveSecurity
```

La eliminación de seguridad conserva sus namespaces y rechaza retirar instalaciones ajenas. Una limpieza Helm no elimina los recursos del despliegue Blue/Green que esté en otro namespace.

### Manifiestos Blue/Green

```bash
bash scripts/cleanup.sh --dry-run
bash scripts/cleanup.sh --delete-data --remove-images --remove-security
```

```powershell
.\scripts\cleanup.ps1 -WhatIf
.\scripts\cleanup.ps1 -DeleteData -RemoveImages -RemoveSecurity
```

Estos scripts usan el namespace del contexto activo. Sin las opciones de borrado, conservan datos, imágenes y seguridad. No tienen una opción `DeleteNamespace`.

### Comprobar el resultado

```bash
helm list -n playhub-helm
kubectl get pods,svc,pvc -n playhub-helm
```

Después de una limpieza normal no debe aparecer el release, pero **los PVC pueden seguir presentes**. Si se eliminó el namespace, es esperable que la consulta indique que ya no existe o no contiene recursos. La limpieza de aplicación no detiene Minikube.

## Diagnóstico y acceso manual

```bash
kubectl get pods -n playhub-helm -o wide
kubectl get events -n playhub-helm --sort-by=.lastTimestamp
kubectl logs -n playhub-helm deployment/playhub-backend
kubectl logs -n playhub-helm deployment/playhub-backend -c flyway-migrate
kubectl logs -n playhub-helm deployment/playhub-prometheus
kubectl logs -n playhub-helm deployment/playhub-grafana
```

Si se desplegó con `--no-port-forward` / `-NoPortForward`, abrir cada acceso necesario en una terminal propia:

```bash
kubectl port-forward -n playhub-helm svc/playhub-frontend 5745:5745
kubectl port-forward -n playhub-helm svc/playhub-backend 8080:8080
kubectl port-forward -n playhub-helm svc/playhub-prometheus 9090:9090
kubectl port-forward -n playhub-helm svc/playhub-grafana 3000:3000
```

Los port-forward manuales se detienen con `Ctrl+C`; no quedan registrados como procesos de los scripts. Los automáticos guardan PID y logs en `logs/`, con prefijo `helm-port-forward-` para Helm y `port-forward-` para los manifiestos.

## Generar la documentación

```bash
doxygen Doxyfile
```

Se ejecuta desde la raíz y genera `docs/generated/html/index.html`. No despliega la aplicación. La portada y sus referencias se configuran en `Doxyfile`.
