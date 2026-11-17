# Monitoreo y observabilidad de PlayHub

Esta guía amplía el [README principal](../README.md). Los comandos de arranque, tráfico y limpieza están en [scripts/README.md](../scripts/README.md); las opciones del chart se mantienen en [helm-chart/README.md](../helm-chart/README.md).

## Componentes y recolección

| Componente | Función |
| --- | --- |
| Actuator + Micrometer | Expone métricas HTTP, JVM y contadores propios del backend en `/actuator/prometheus`. |
| Prometheus | Recolecta cada 15 segundos y almacena las series en un PVC. |
| Grafana | Consulta Prometheus y carga los dashboards JSON mediante provisioning. Conserva su base en un PVC. |
| kube-state-metrics | Publica estado, etiquetas y recursos declarados de Kubernetes. |
| node-exporter | Publica CPU, memoria, disco y red del nodo. |
| kubelet | Se consulta mediante el API server para métricas de contenedores y volúmenes. |
| cAdvisor auxiliar | Complementa métricas de red que pueden faltar con cri-dockerd. |
| blackbox-exporter | Comprueba por HTTP los Services estables del frontend y backend. |

La configuración de referencia está en `k8s/monitoring/prometheus.yaml`. Descubre los pods del backend, incluidos ambos slots cuando se utiliza Blue/Green, y agrega las etiquetas `pod`, `node` y `slot`. Para infraestructura, el acceso a kubelet utiliza el token del ServiceAccount y el certificado de la API.

En Helm, esos manifiestos se empaquetan bajo `helm-chart/files/monitoring/` y las plantillas adaptan los nombres al release y namespace. `monitoring.enabled` activa el monitoreo; está habilitado por defecto.

## Dashboards y relación con la consigna

La entrega organiza los indicadores en **cinco dashboards**, sin un archivo único `grafana/dashboard.json`. Los JSON exportados están en `monitoring/grafana/dashboards/`.

| Dashboard / UID | Indicadores |
| --- | --- |
| `playhub-http-latency` | RPS, latencia promedio, p50/p95/p99, distribución de tiempos y throughput por endpoint. |
| `playhub-workloads` | CPU y memoria por pod/contenedor, porcentaje del límite, red, throttling y estado de recolección. |
| `playhub-counters` | Compras, ingresos, ganancia promedio, logins fallidos y errores 500. |
| `playhub-bluegreen` | Targets, tráfico, códigos HTTP y latencia por slot. |
| `playhub-nodes` | CPU, RAM, disco y red del nodo. |

RPS y latencia promedio cubren los indicadores de peticiones y respuesta; workloads cubre CPU y memoria por pod; compras e ingresos son las métricas de negocio. Las vistas de nodo y Blue/Green amplían ese conjunto. El despliegue Helm utiliza un slot llamado `helm`; el dashboard por slot no implica que el chart despliegue Blue y Green.

## Acceder y comprobar los datos

Después del despliegue, con los port-forward activos:

1. Abrir [Prometheus](http://localhost:9090) y revisar la página de targets. `playhub-backend` debe aparecer `UP`; con Blue/Green se espera un target por pod descubierto.
2. Consultar el endpoint [Actuator Prometheus](http://localhost:8080/actuator/prometheus). Debe responder con texto de métricas.
3. Abrir [Grafana](http://localhost:3000), acceder con las credenciales de la instancia y seleccionar la carpeta **PlayHub**. Los manifiestos del proyecto no establecen una contraseña administrativa explícita de Grafana; una base persistida conserva la configuración de esa instancia.
4. Elegir el namespace y pod apropiados en los dashboards que tengan esos selectores. Para el recorrido principal, el namespace es `playhub-helm`.
5. Generar tráfico con una de las variantes siguientes:

```powershell
.\scripts\demo-monitoring.ps1
```

```bash
bash scripts/demo-monitoring.sh
```

6. Esperar al menos un ciclo de recolección y elegir un intervalo reciente en Grafana. Las tasas requieren al menos dos muestras de la serie; si una serie HTTP se crea con las primeras solicitudes, puede ser necesaria otra ronda de tráfico para observar su incremento.

El datasource provisionado se llama **Prometheus**, tiene UID `playhub-prometheus` y usa `http://playhub-prometheus:9090` para el release predeterminado. La URL es interna al clúster, diferente del acceso por port-forward del navegador.

## Consultas utilizadas

### Peticiones por segundo

```promql
sum(rate(http_server_requests_seconds_count{uri!~"/actuator.*"}[5m]))
```

Se excluyen las consultas de Actuator para que el scraping y las sondas no dominen el tráfico observado. El valor es una tasa en la ventana de cinco minutos; una ráfaga breve no mantiene un RPS constante durante toda esa ventana.

### Latencia promedio

```promql
sum(rate(http_server_requests_seconds_sum{uri!~"/actuator.*"}[5m]))
/
sum(rate(http_server_requests_seconds_count{uri!~"/actuator.*"}[5m]))
```

El resultado está en segundos. El dashboard también calcula percentiles sobre el histograma. Sin peticiones en la ventana, el promedio puede no tener datos o resultar `NaN`; no corresponde interpretarlo como latencia cero.

### CPU y memoria por pod/contenedor

En los paneles de workloads se utiliza `kubelet-resource`. Por ejemplo, para consultar CPU de un pod desde Prometheus, reemplazar el patrón según el despliegue:

```promql
sum by (namespace, pod, container) (
  rate(container_cpu_usage_seconds_total{
    job="kubelet-resource", namespace="playhub-helm",
    pod=~"playhub-.*", container!="", container!="POD"
  }[5m])
)
```

```promql
sum by (namespace, pod, container) (
  container_memory_working_set_bytes{
    job="kubelet-resource", namespace="playhub-helm",
    pod=~"playhub-.*", container!="", container!="POD"
  }
)
```

CPU está expresada en cores y memoria en bytes. Los JSON usan variables de Grafana y `$__rate_interval`; esas variables no se pegan literalmente en la consola de Prometheus.

### Métricas de negocio

```promql
total_purchases_total
total_earnings_currency_units_total
failed_logins_total
```

Los componentes `PurchaseMetrics` y `LoginMetrics` registran los contadores. El checkout incrementa compras e ingresos; el login fallido incrementa su contador. Son contadores en memoria de cada proceso: pueden reiniciarse con el backend y no sustituyen una consulta histórica a la base de datos. Los ingresos se expresan en unidades monetarias del catálogo, no en una divisa asumida.

## Resultados observados y resultados esperados

En la revisión del **16 de noviembre de 2026**, sobre el despliegue existente en `default`, se comprobó:

- Ambos backends, Prometheus y Grafana estaban listos.
- Los 12 targets activos de Prometheus estaban `UP`.
- CPU y memoria devolvían cinco series para los pods de backend, frontend y PostgreSQL.
- Grafana respondía con `database: ok` y tenía montados los cinco JSON.
- Tras solicitudes de lectura a `/v3/api-docs`, las consultas de los paneles devolvieron aproximadamente `0.020816` RPS y `0.004949` segundos de latencia promedio.

Esos valores describen una comprobación de funcionamiento con poco tráfico. No son una medición de capacidad ni una ejecución de la demo de compras. Los contadores de compras e ingresos estaban expuestos con valor cero tras el arranque.

Para una nueva demostración se espera que el script de tráfico muestre incrementos de compras, peticiones y logins fallidos, y que los paneles reflejen la actividad. Guardar la salida de esa corrida si se necesita evidencia adicional; esta documentación no inventa capturas ni logs de una ejecución nueva.

## Persistencia y actualización de dashboards

Los PVC de Prometheus y Grafana se conservan en la limpieza normal. Los datos se pierden si se utiliza la opción de borrado de datos o se elimina su almacenamiento.

Los dashboards provisionados tienen `allowUiUpdates: false`. Para modificar uno:

1. Exportar el modelo JSON Classic desde Grafana. Conservar un UID estable, `id` nulo o ausente y las referencias al datasource `playhub-prometheus`.
2. Guardar el JSON en `monitoring/grafana/dashboards/`.
3. Actualizar la entrada correspondiente del ConfigMap de dashboards en `k8s/monitoring/grafana-config.yaml`. El script de sincronización actual **no regenera** este ConfigMap.
4. Sincronizar las copias empaquetadas para Helm:

```powershell
.\helm-chart\sync-monitoring-assets.ps1
```

5. Revisar los cambios de fuentes y copias, ejecutar `helm lint ./helm-chart` y actualizar el release mediante el script de despliegue. Para manifiestos, aplicar `k8s/monitoring/`; si cambia la configuración de Prometheus, reiniciarlo para cargarla. `deploy.sh` / `deploy.ps1` ya contemplan ese reinicio.

El sincronizador copia manifiestos y JSON hacia `helm-chart/files/`; no elimina automáticamente copias de archivos que ya no existen. Si se elimina un dashboard, retirar también su entrada del ConfigMap y su copia empaquetada.

Grafana revisa los archivos cada 30 segundos, después de que Kubernetes propague el ConfigMap. Un cambio visible puede requerir ambas esperas. Los dashboards nuevos creados solo desde la interfaz se guardan en la base de Grafana; deben exportarse y agregarse al repositorio para reconstruirlos en otro despliegue.

## Alertas y diagnóstico

Las reglas provisionadas están en `k8s/monitoring/grafana-alerts.yaml`, con su copia para Helm. Para ver la definición de cada condición y su duración, revisar ese archivo. Su existencia no demuestra que todas las reglas hayan sido disparadas en una prueba.

Si un panel está vacío, comprobar en orden:

1. Readiness del backend y target `UP` en Prometheus.
2. Consulta directa de la métrica y existencia de muestras suficientes para `rate`.
3. Namespace, pod, slot e intervalo seleccionados.
4. Datasource y logs de Grafana/Prometheus.
5. Que se hayan actualizado las copias que utiliza la modalidad desplegada.

Los comandos concretos de logs y port-forward están en [la guía de scripts](../scripts/README.md).
