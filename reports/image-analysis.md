# Análisis de imágenes Docker con Dive

**Fecha:** 10 de noviembre de 2026.  
**Herramienta:** Dive 0.13.1, ejecutado en Windows sobre imágenes locales de Docker Desktop.

## Alcance y metodología

Se analizaron las imágenes de producción de PlayHub utilizadas para desplegar el backend y el frontend en Kubernetes:

| Componente | Imagen analizada | Dockerfile | Evidencia |
| --- | --- | --- | --- |
| Backend Spring Boot | `playhub-backend:v1.0` | [Dockerfile.prod](../backend/Dockerfile.prod) | [dive-backend.json](dive-backend.json) |
| Frontend Next.js | `playhub-frontend:v1.0` | [Dockerfile.prod](../frontend/Dockerfile.prod) | [dive-frontend.json](dive-frontend.json) |

El análisis comprende el tamaño, la composición de las capas y las oportunidades de optimización de estas dos imágenes. Las imágenes oficiales de servicios auxiliares quedan fuera de estos dos reportes.

Los valores se obtuvieron directamente de los JSON exportados: `image.sizeBytes` para el tamaño total, la cantidad de entradas de `layer` para las capas, `image.inefficientBytes` para el espacio potencialmente desperdiciado y `image.efficiencyScore × 100` para la eficiencia. Se comprobó que la suma de `layer[].sizeBytes` coincide con el tamaño total en ambos archivos.

Los tamaños corresponden al contenido de las capas medido por Dive, sin equipararlos con la descarga comprimida ni con el almacenamiento físico informado por Docker Desktop. Se utiliza **MiB = 1.048.576 bytes**. La cantidad de capas incluye las entradas de tamaño cero presentes en la exportación; no equivale al número de instrucciones del Dockerfile.

## Resultados generales

| Métrica | Backend | Frontend |
| --- | ---: | ---: |
| Tamaño total, en bytes | 301.790.180 | 754.885.415 |
| Tamaño total, en MiB | 287,81 | 719,91 |
| Cantidad de capas | 9 | 11 |
| Eficiencia estimada por Dive | 99,42 % | 99,98 % |
| Espacio potencialmente desperdiciado, en bytes | 1.954.481 | 203.446 |
| Espacio potencialmente desperdiciado, en MiB | 1,864 | 0,194 |

Ambas imágenes presentan poca duplicación o sustitución de archivos entre capas según la estimación de Dive. Esta métrica no determina si todos los archivos incluidos son necesarios: una imagen puede tener alta eficiencia y conservar dependencias o cachés prescindibles. La herramienta describe esta estimación en su [documentación oficial](https://github.com/wagoodman/dive/tree/v0.13.1#basic-features).

## Backend: composición y observaciones

El backend utiliza un build de dos etapas. Maven compila la aplicación y la etapa final utiliza Eclipse Temurin JRE sobre Alpine, copia únicamente el JAR de la aplicación y configura el usuario `spring` con UID 1000. Las bases están fijadas por digest SHA-256.

Las capas de mayor contribución al tamaño son:

| Contenido de la capa | Tamaño en MiB | Porcentaje del total |
| --- | ---: | ---: |
| Instalación del runtime Java en `/opt/java/openjdk` | 193,32 | 67,17 % |
| Copia del artefacto `/app/app.jar` | 66,74 | 23,19 % |
| Paquetes del sistema y certificados de la base | 18,44 | 6,41 % |
| Sistema de archivos inicial de Alpine | 8,03 | 2,79 % |
| Actualización de `brotli-libs`, `libexpat` y `zlib` | 1,26 | 0,44 % |

Las cuatro capas restantes corresponden al entrypoint de certificados, el directorio de trabajo, la creación del usuario y una comprobación de Java. Sus tamaños individuales y digests se conservan en el JSON.

El runtime Java y el JAR explican aproximadamente el 90,36 % del tamaño. La separación entre compilación y ejecución evita incorporar Maven y su repositorio de dependencias a la imagen final. No se dispone de una medición previa que permita cuantificar el ahorro producido por esta separación.

El desperdicio estimado se concentra principalmente en archivos sustituidos durante las actualizaciones de paquetes y certificados. Entre los archivos señalados aparecen bibliotecas de Brotli, libexpat, zlib y la base de datos de APK. Estas sustituciones son coherentes con las actualizaciones de seguridad del Dockerfile.

**Posibles optimizaciones:**

- Revisar las dependencias empaquetadas en el JAR para identificar bibliotecas que la aplicación no utilice. El análisis de capas por sí solo no permite determinar cuáles pueden eliminarse.
- Evaluar una base Java compatible que ya incorpore los paquetes corregidos para reducir sustituciones en capas posteriores. Se deben conservar las correcciones de seguridad y verificar el funcionamiento antes de reemplazar la base actual.
- Priorizar cambios que reduzcan el runtime o el artefacto de aplicación: el desperdicio detectado entre capas es pequeño frente a esos componentes.

## Frontend: composición y observaciones

El frontend utiliza tres etapas: instalación de dependencias, compilación y ejecución. Se ejecuta `npm ci`, se construye la aplicación y se eliminan dependencias de desarrollo mediante `npm prune --omit=dev`. La etapa final utiliza una base Node sobre Alpine fijada por digest y ejecuta el proceso como usuario `node`.

Las capas de mayor contribución al tamaño son:

| Contenido de la capa | Tamaño en MiB | Porcentaje del total |
| --- | ---: | ---: |
| Copia de `/app/node_modules` | 473,80 | 65,81 % |
| Instalación de Node y componentes de su base | 147,28 | 20,46 % |
| Copia de `/app/.next` | 84,24 | 11,70 % |
| Sistema de archivos inicial de Alpine | 8,04 | 1,12 % |
| Instalación de Yarn heredada de la base | 5,12 | 0,71 % |
| Copia de `/app/public` | 1,31 | 0,18 % |

Las cinco capas restantes corresponden al entrypoint, el directorio de trabajo, la actualización de zlib y eliminación de npm/npx, y las copias de `package.json` y `next.config.mjs`.

`node_modules` y `.next` representan en conjunto el 77,52 % del tamaño. Aunque se eliminaron las dependencias de desarrollo, se copia el árbol completo de dependencias de producción y todo el directorio de salida de Next.js.

La exportación contiene **70.250.192 bytes (67,00 MiB)** bajo `/app/.next/cache/turbopack/`. Esta caché de compilación representa el 79,53 % de la capa `.next` y el 9,31 % de la imagen completa. Su presencia explica por qué una eficiencia del 99,98 % no implica que la imagen tenga el mínimo contenido necesario.

**Posibles optimizaciones, por prioridad:**

1. **Excluir la caché de compilación de la imagen final.** Conservarla en la etapa de build o en el mecanismo de caché del pipeline y evitar copiar `.next/cache/turbopack` al runtime. El contenido identificado equivale a 67,00 MiB; el ahorro efectivo debe medirse después de reconstruir y validar la imagen. La [documentación de Next.js sobre caché de build](https://nextjs.org/docs/app/guides/ci-build-caching) explica su uso entre compilaciones.
2. **Evaluar `output: 'standalone'`.** Esta opción no está configurada actualmente. Permitiría copiar la salida y las dependencias seleccionadas por el trazado de Next.js en lugar de todo `node_modules`. Se debe adaptar el arranque a `server.js`, incluir `public` y `.next/static`, y verificar las rutas y los recursos de la aplicación. Es una propuesta pendiente, sin un ahorro medido. Ver la [documentación oficial de salida standalone](https://nextjs.org/docs/app/api-reference/config/next-config-js/output).
3. **Revisar herramientas heredadas de la base.** La imagen conserva la capa que incorpora Yarn. Además, borrar npm en una capa posterior evita que esté disponible en el filesystem final, pero no elimina su contenido de las capas anteriores. Una base que omita herramientas innecesarias desde su construcción podría reducir tamaño; debe verificarse su compatibilidad con la aplicación.

El desperdicio calculado por Dive es de aproximadamente 0,194 MiB y se relaciona principalmente con la sustitución de zlib y metadatos de APK. La oportunidad principal está en seleccionar el contenido que se copia al runtime.

## Reproducción del análisis

Desde la raíz del repositorio, con Docker Desktop en funcionamiento y las imágenes locales disponibles, los siguientes comandos son compatibles con CMD y PowerShell:

```console
dive --version
dive playhub-backend:v1.0 --json .\reports\dive-backend.json
dive playhub-frontend:v1.0 --json .\reports\dive-frontend.json
docker image inspect playhub-backend:v1.0 playhub-frontend:v1.0 --format "{{.RepoTags}} | ID={{.Id}} | Capas={{len .RootFS.Layers}}"
```

Para explorar los archivos de cada capa en la interfaz interactiva:

```console
dive playhub-backend:v1.0
dive playhub-frontend:v1.0
```

Las observaciones anteriores describen las imágenes de los JSON adjuntos. Las optimizaciones propuestas requieren una nueva construcción y medición para comparar resultados. El análisis de vulnerabilidades complementario se encuentra en los reportes existentes de [Trivy para backend](trivyreports_backend-post-mitigacion.txt) y [Trivy para frontend](trivyreports_frontend-post-mitigacion.txt).
