# Seguridad integrada y evidencias

Este documento amplía el [README principal](../README.md). Los comandos de los wrappers existentes y sus requisitos están en [scripts/README.md](../scripts/README.md). Los archivos citados como evidencia están bajo `reports/`, salvo que se indique otra ubicación.

## Alcance de los resultados

Los reportes son fotografías de ejecuciones concretas. No se ejecutaron escáneres ni pruebas de admisión/runtime para escribir esta guía. Los nombres `inicial` y `post-mitigacion` se conservan, pero no implican que todos los archivos correspondan a las mismas dependencias o imágenes.

Una corrección en el código o el POM requiere una nueva ejecución de la herramienta que detectó el hallazgo para acreditarse con esa herramienta. Un resultado sin vulnerabilidades de Trivy no reemplaza el resultado de Snyk, y un código de salida cero no siempre significa ausencia de hallazgos.

## Semgrep

Las reglas versionadas están en `security/semgrep/rules/`, con su manifiesto en `security/semgrep/rules-manifest.json`. El conjunto Java contiene 60 reglas; el de JavaScript, 74. Entre las reglas específicas se encuentran:

| Lenguaje | Regla incluida | Propósito |
| --- | --- | --- |
| Java | `java.lang.security.httpservlet-path-traversal.httpservlet-path-traversal` | Detectar rutas de archivo controladas por entrada del usuario. |
| Java | `java.lang.security.servletresponse-writer-xss.servletresponse-writer-xss` | Detectar escritura de entrada HTTP sin codificación en la respuesta. |
| JavaScript | `javascript.lang.security.detect-eval-with-expression.detect-eval-with-expression` | Detectar evaluación dinámica mediante expresiones. |

El script actual usa `semgrep/semgrep:1.182.1`, reglas locales y snapshots de los archivos seleccionados por Git; omite `node_modules`, `.next` y `target`.

### Evidencias y justificación

| Reporte | Resultado registrado |
| --- | --- |
| `semgrep-report.txt` | 2 hallazgos: Actuator con `health,prometheus` y privilegios de cAdvisor. |
| `semgrep_scan-post-mitigacion.txt` | 164 reglas sobre 140 archivos: 8 hallazgos por hashes bcrypt en `V2__demo_data.sql` y `db/02_inserts.sql`. |
| `semgrep-kubernetes-post-mitigacion.txt` | 11 reglas sobre 24 archivos: 16 hallazgos de manifiestos. |

Los hashes bcrypt corresponden a los usuarios de demostración que la aplicación carga mediante SQL. Se mantienen como fixtures académicos, con contraseña de prueba conocida; no son credenciales reales recuperadas de una cuenta externa y no deben reutilizarse en producción.

Actuator se mantiene para salud y scraping. `application.properties` limita la exposición a `health,prometheus`, y `SecurityConfig` permite `GET /actuator/prometheus` sin JWT para la recolección. Esto explica el hallazgo, sin convertir el endpoint público de métricas en un endpoint autenticado.

cAdvisor y Falco necesitan acceso al host/runtime para sus funciones. Se mantienen excepciones específicas de admisión y los hallazgos estáticos correspondientes; no se declara que los contenedores de monitoreo tengan las mismas restricciones que la aplicación. También quedan hallazgos de filesystem escribible.

Reproducción con el wrapper existente:

```powershell
.\scripts\scan-semgrep.ps1
```

El script escribe los reportes posteriores, no `semgrep-report.txt`. No agrega `--error`; puede terminar correctamente con hallazgos. Revisar el contenido, no solo el código de salida.

## Snyk: dependencias y críticas registradas

`reports/snyk-report.txt` registra 6 issues abiertas: **2 CRITICAL, 1 HIGH, 2 MEDIUM y 1 LOW**, con 2 proyectos evaluados. Fragmento del resumen existente:

```text
Total security issues: 6
Open   : 6 [ 2 CRITICAL  1 HIGH  2 MEDIUM  1 LOW ]
```

Las dos críticas corresponden a deserialización de datos no confiables:

| Dependencia en el reporte | Ruta indicada | Corrección propuesta en el reporte y estado del código |
| --- | --- | --- |
| `com.fasterxml.jackson.core:jackson-databind:2.21.7` | `jjwt-jackson:0.12.6` | El reporte indica corrección en `2.21.8`, entre otras versiones. El POM actual fija `2.21.8` en dependency management. Falta acreditar el resultado con un nuevo Snyk. |
| `tools.jackson.core:jackson-databind:3.1.7` | Flyway `12.4.0` | El reporte propone subir Flyway a `13.5.0`. El POM actual declara `flyway.version=13.5.0`; se debe verificar la resolución transitiva y repetir Snyk. |

La alta afecta a `jaxb-core`; las medias, a Logback; la baja, a Jakarta Validation. Revisar sus rutas y versiones corregidas en el reporte al planificar una actualización compatible del BOM y las dependencias. Esta guía no afirma que esos hallazgos hayan desaparecido.

No existe un wrapper Snyk en `scripts/`. No se presenta una nueva corrida ni se atribuyen estos resultados a una pipeline.

## Trivy, npm audit y análisis de imágenes

Los reportes `trivyreports_backend-post-mitigacion.txt` y `trivyreports_frontend-post-mitigacion.txt` muestran cero vulnerabilidades en los objetivos analizados. En el backend, el resumen contiene:

```text
playhub-backend:v1.0 (alpine 3.24.3) | alpine | 0
app/app.jar                        | jar    | 0
```

El audit de dependencias de producción `npm-audit-produccion-post-mitigacion.txt` indica:

```text
found 0 vulnerabilities
```

Para el conjunto completo de dependencias, consultar `npm-audit.txt`; no confundirlo con el alcance `--omit=dev`. Los comandos y requisitos de los scripts de regeneración están en [la guía de scripts](../scripts/README.md).

`scan-images.ps1` comprueba además que `v1.0` y `v2.0` tengan el mismo ID por componente antes de escanear. Sus resultados corresponden a esas imágenes, no a cualquier imagen posterior con la misma etiqueta.

El [informe de Dive](../reports/image-analysis.md) complementa el análisis de vulnerabilidades con tamaño, capas y composición. No evalúa vulnerabilidades por sí mismo.

## Kyverno: políticas de admisión

El instalador fija Kyverno `1.19.2` y aplica `k8s/kyverno/`:

| Política | Tipo | Validación |
| --- | --- | --- |
| `disallow-latest` | `ClusterPolicy` | Exige etiqueta explícita distinta de `latest` o digest; revisa también init y ephemeral containers. |
| `require-resources` | `ClusterPolicy` | Requests y limits positivos de CPU y memoria para contenedores e initContainers. La API no permite `resources` en ephemeralContainers. |
| `disallow-root` | `ClusterPolicy` | Exige `runAsNonRoot=true` y prohíbe UID 0, con las excepciones de monitoreo delimitadas en la política. |
| `disallow-privilege-escalation` | `ValidatingPolicy` | Deniega la ausencia de `allowPrivilegeEscalation: false` o su activación. |

Las políticas excluyen namespaces del sistema según su definición. Las excepciones de cAdvisor y Falco verifican datos del DaemonSet y la identidad autenticada del controlador; una etiqueta u owner aislados no bastan para justificar la excepción.

El validador comprueba casos válidos, `latest` explícito e implícito, ausencia de recursos, UID root, escalada de privilegios, initContainers, ephemeralContainers y falsos intentos de utilizar las excepciones. También verifica un pod válido real con UID 1000.

Evidencia disponible:

- `reports/kyvernovalidation.log`: salida del validador; registra fecha UTC `2026-11-16T00:41:25Z`.
- `reports/kyverno-validation-post-mitigacion.txt`: ejecución anterior con **45 comprobaciones correctas**.

Fragmentos del reporte posterior:

```text
PASS: latest rechazado por disallow-latest.
PASS: el proceso del Pod valido ejecuta con UID 1000.
RESULTADO: 45 comprobaciones correctas.
```

Los logs advierten que `ClusterPolicy` está deprecado; migrar esas tres políticas es una mejora pendiente. La política de escalada ya utiliza `ValidatingPolicy`.

El archivo escrito por el script no tiene el nombre exacto `kyverno-validation.log` solicitado en la consigna. La [guía de scripts](../scripts/README.md) incluye la copia posterior a una validación revisada; esta documentación no modifica los logs existentes.

## Falco: evento sin shell interactiva

La configuración fija el chart `9.2.2`, Falco `0.45.2` y el driver `modern_ebpf`. Se instala como DaemonSet con salida JSON y recursos declarados en `security/falco/values.yaml`.

La prueba utilizada para esta entrega crea un enlace simbólico temporal hacia `/etc/shadow` dentro de un backend, mediante `/bin/busybox ln`. No abre una shell interactiva, no asigna TTY y no lee ni modifica el archivo sensible. El script elimina el enlace al terminar.

La evidencia relevante está en:

- `reports/falcoevent.log`: alerta del symlink.
- `reports/falco/falco-symlink-report-2026-11-15_21-42-48.txt`: descripción, pod, ventana temporal, comandos, limpieza y una alerta coincidente.

Fragmentos del informe:

```text
Regla: Create Symlink Over Sensitive Files
Prioridad: WARNING
Target: /etc/shadow
Shell interactiva: no
TTY: no
Limpieza del enlace: correcta
Total de alertas de Falco: 1
```

El recolector usa la regla, la ruta temporal única, el ID de contenedor y la ventana de la corrida para asociar la alerta. Una alerta histórica de otro contenedor no acredita esa prueba.

`reports/falco-event.log`, con guion, conserva una alerta anterior de shell. **No se utiliza como evidencia válida de este requisito.** Los scripts de shell históricos siguen en el repositorio, pero la reproducción indicada en [scripts/README.md](../scripts/README.md) utiliza los scripts de symlink y explica cómo copiar la evidencia verificada al nombre pedido por la consigna.

## Hallazgos complementarios y límites

`reports/kubelinter.txt` conserva **21 hallazgos** y código de salida 1. Incluyen filesystem escribible, montajes sensibles y un Job sin TTL. El archivo no se presenta como un análisis sin observaciones.

Las oportunidades pendientes son volver a ejecutar Snyk con las dependencias actuales, revisar los hallazgos residuales según la función de cada componente, migrar las políticas deprecadas y alinear los nombres de evidencias después de corridas verificadas. No se sustituyen resultados reales por salidas de ejemplo.
