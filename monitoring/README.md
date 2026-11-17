# Monitoreo y visualización con Prometheus y Grafana

## ¿Qué es Prometheus?

**Prometheus** es un sistema de **monitorización** y **alertas** de código abierto. Su funcionamiento se basa en consultar periódicamente los servicios que exponen métricas a través de HTTP. Este proceso se conoce como _scraping_.

Cada métrica recopilada incluye una marca temporal (_timestamp_) y un conjunto de etiquetas (_labels_) en formato clave-valor, que permiten identificar y clasificar las distintas series de datos. Esta información se almacena en una base de datos de series temporales (_Time Series Database_ o _TSDB_), diseñada para gestionar y consultar datos ordenados cronológicamente.

Para consultar, filtrar y agrupar las métricas, Prometheus utiliza su propio lenguaje de consultas: **PromQL**.

## ¿Qué es Grafana?

**Grafana** es una plataforma de **visualización** y **observabilidad** de código abierto. Permite transformar datos provenientes de distintas fuentes en gráficos, tablas y paneles de monitoreo (_dashboards_) personalizados.

Además, permite configurar reglas de evaluación y alertas que notifican cuando se cumplen determinadas condiciones.

Grafana puede integrarse con diferentes sistemas y bases de datos, que actúan como fuentes de información para sus visualizaciones. El lenguaje de consulta utilizado depende de la fuente de datos con la que se integra.

## Implementación de Prometheus

**PlayHub** utiliza **Prometheus** como sistema centralizado de recopilación y almacenamiento de métricas dentro del clúster de Kubernetes. Su implementación permite obtener información sobre el rendimiento de la aplicación, el estado de los recursos de Kubernetes, la infraestructura de los nodos, el tráfico de red y la disponibilidad de los servicios del frontend y backend.

La arquitectura de monitoreo está compuesta por los siguientes componentes, desplegados como recursos de Kubernetes:

- **Spring Boot Actuator y Micrometer**: permiten definir y exponer métricas de la aplicación en un formato compatible con Prometheus.
- **Node Exporter**: recopila métricas relacionadas con el sistema operativo y los recursos de los nodos.
- **cAdvisor**: recopila métricas relacionadas con el tráfico de red de los contenedores.
- **Kube-State-Metrics**: expone información sobre el estado y los metadatos de los objetos de Kubernetes.
- **Blackbox Exporter**: realiza sondeos HTTP para verificar la disponibilidad de los servicios.
- **Prometheus**: descubre los objetivos de monitoreo (targets), recopila las métricas y las almacena como series temporales.

### Prometheus

**Prometheus** fue desplegado mediante un **Deployment** de una réplica y un **Service** de tipo **ClusterIP**, denominado `playhub-prometheus`. Esto permite que otros componentes del clúster, como **Grafana**, puedan acceder a él mediante su dirección interna.

Su configuración se almacena en un **ConfigMap** denominado `playhub-prometheus-config`, que contiene el archivo `prometheus.yml`. En este se definen:

- Un intervalo global de recopilación (_scrape interval_) de 15 segundos.
- Un intervalo de evaluación de reglas (_evaluation interval_) de 15 segundos.
- Los objetivos de monitoreo y sus respectivos mecanismos de descubrimiento.
- Las reglas de filtrado y selección de métricas.
- Las reglas de asignación y organización de etiquetas.

Para conservar los datos recopilados entre reinicios del contenedor, **Prometheus** utiliza un **PersistentVolumeClaim** denominado `playhub-prometheus-data`, que solicita 2 GiB de almacenamiento persistente.

### Métricas Spring Boot

El backend de **PlayHub** define y expone métricas mediante **Spring Boot Actuator** y **Micrometer**. El endpoint utilizado por Prometheus para recopilarlas es `/actuator/prometheus`.

- Entre las métricas implementadas se encuentran:
- Cantidad de inicios de sesión fallidos.
- Cantidad total de compras exitosas.
- Importe acumulado de las compras.

Métricas de solicitudes HTTP, como el código de estado de respuesta y la duración de las solicitudes.

**Prometheus** utiliza el descubrimiento de servicios de Kubernetes para identificar dinámicamente los pods del backend que poseen la etiqueta `app=playhub-backend`. Además, recopila la etiqueta slot, que permite distinguir entre las instancias correspondientes a los despliegues **Blue** y **Green**.

De esta manera, es posible monitorear ambos despliegues de forma independiente y comparar su comportamiento durante el proceso de despliegue.

### Node Exporter

**Node Exporter** fue desplegado mediante un **DaemonSet** denominado `playhub-node-exporter`. Este tipo de recurso garantiza que se ejecute una instancia del exportador en cada nodo Linux elegible del clúster.

Su función es recopilar métricas relacionadas con los recursos y el funcionamiento del sistema operativo, entre ellas:

- Uso de CPU.
- Uso de memoria RAM.
- Capacidad y utilización del sistema de archivos.
- Estadísticas relacionadas con el almacenamiento y el sistema.

**Prometheus** descubre estas instancias dinámicamente mediante Kubernetes y recopila las métricas expuestas por el exportador.

### cAdvisor

**cAdvisor** fue desplegado mediante un **DaemonSet** denominado `playhub-cadvisor-network`.

Su configuración está orientada específicamente a la recopilación de métricas de red de los contenedores. Entre ellas se encuentran:

- Cantidad de bytes recibidos por los contenedores.
- Cantidad de bytes transmitidos por los contenedores.

Estas métricas permiten analizar el tráfico de red asociado a los contenedores y observar su actividad de comunicación.

La implementación utiliza acceso a determinados recursos del nodo anfitrión (_host_), como sus directorios de sistema y ejecución, para obtener la información necesaria. Por este motivo, el contenedor requiere permisos privilegiados.

### Kube-State-Metrics

**Kube-State-Metrics** fue desplegado mediante un **Deployment** denominado `playhub-kube-state-metrics`.

Su función es consultar el estado de los objetos de Kubernetes y exponerlo como métricas para **Prometheus**. En esta implementación, la recopilación se limita a los _pods_ y a un conjunto específico de métricas:

- kube_pod_info: proporciona información general sobre los pods.
- kube_pod_labels: expone las etiquetas seleccionadas de los pods.
- kube_pod_status_phase: indica la fase del ciclo de vida de cada pod.
- kube_pod_container_info: proporciona información sobre los contenedores.
- kube_pod_container_resource_limits: expone los límites de recursos configurados para los contenedores.
- kube_pod_container_resource_requests: expone los recursos solicitados por los contenedores.

También se permite la exposición de la etiqueta _slot_, lo que facilita la identificación de las instancias pertenecientes a los despliegues **Blue** y **Green**.

### Blackbox Exporter

**Blackbox Exporter** fue desplegado mediante un **Deployment** y expuesto a través de un **Service** denominado `playhub-blackbox-exporter`, en el puerto 9115.

Su función es realizar sondeos HTTP sobre los servicios del frontend y backend de PlayHub para verificar su **disponibilidad**.

La configuración utiliza el módulo http_2xx, que realiza solicitudes HTTP mediante el método **GET**, establece un tiempo máximo de espera de cinco segundos y considera exitosas únicamente las respuestas con código HTTP 200. Además, no sigue redirecciones.

Prometheus utiliza este exportador para consultar los siguientes endpoints:

- Backend: http://playhub-backend:8080/actuator/health.
- Frontend: http://playhub-frontend:5745/login.

El resultado de cada sondeo se expone mediante la métrica `probe_success`, que permite identificar si el servicio respondió correctamente.

Como las pruebas se realizan contra los **Services** de Kubernetes, y no directamente contra los _pods_, se comprueba la disponibilidad de los servicios asociados al despliegue activo.

### Descubrimiento de objetivos

**Prometheus** utiliza el mecanismo de descubrimiento de servicios de Kubernetes (_Kubernetes Service Discovery_) para identificar dinámicamente los _pods_ y nodos que debe monitorear.

La configuración utiliza reglas de selección y reasignación de etiquetas (_relabeling_) para filtrar los objetivos según sus etiquetas, puertos y estado. Esto permite recopilar únicamente las métricas correspondientes a los componentes de monitoreo y a las instancias del backend.

Para acceder a la API de Kubernetes, **Prometheus** utiliza una cuenta de servicio denominada `playhub-prometheus`. Los permisos necesarios se definen en el archivo rbac.yaml, mediante los recursos _Role_, _RoleBinding_, _ClusterRole_ y _ClusterRoleBinding_.

Estos permisos permiten consultar y descubrir _pods_ y nodos, así como acceder a los endpoints de métricas del **kubelet** a través del proxy de la API de Kubernetes.

La autenticación se realiza mediante el **token** de la cuenta de servicio y el certificado de la autoridad certificante del clúster, evitando la necesidad de almacenar credenciales manualmente en la configuración.

### Métricas del Kubelet

Además de los exportadores desplegados individualmente, **Prometheus** recopila métricas directamente del **kubelet** mediante la API de Kubernetes.

Para ello, se configuran tres objetivos de monitoreo:

- **kubelet-cadvisor**: recopila métricas de contenedores mediante el endpoint `/metrics/cadvisor`.
- **kubelet**: recopila métricas propias del kubelet mediante `/metrics`.
- **kubelet-resource**: recopila métricas de recursos mediante `/metrics/resource`.

Las solicitudes se realizan mediante HTTPS y utilizan el **token** de la cuenta de servicio de Prometheus y el certificado de la autoridad certificante de Kubernetes para autenticar y validar las conexiones.

De esta manera, se obtiene información adicional sobre el consumo de recursos de los nodos y contenedores, así como sobre otros recursos que dependen de las métricas disponibles en el entorno de Kubernetes.

## Integración con Grafana

**Grafana** fue integrado con **Prometheus** como fuente de datos (_data source_), utilizando la dirección interna del servicio de Kubernetes: http://playhub-prometheus:9090.

A partir de las métricas recopiladas, se crearon dashboards personalizados para visualizar distintos aspectos del funcionamiento de PlayHub, entre ellos:

- Inicios de sesión fallidos.
- Cantidad total de compras.
- Importe acumulado de las compras.
- Respuestas HTTP 500.
- Uso de CPU y memoria RAM.
- Duración de las solicitudes al backend.
- Tráfico de red recibido y transmitido por los contenedores.
- Estado de los pods de Kubernetes.
- Disponibilidad del frontend y backend.
- Comparación del comportamiento de los despliegues Blue y Green.

## Dashboards

Los _dashboards_ desarrollados en **Grafana** fueron exportados como archivos JSON y se encuentran en la carpeta `monitoring/grafana` del proyecto.

La configuración de Kubernetes permite aprovisionar estos dashboards automáticamente al iniciar Grafana. Una vez desplegados los componentes, se puede acceder a la interfaz desde: `http://localhost:3000`

Las credenciales iniciales configuradas son `admin/admin`.

Para generar datos de prueba y observar el funcionamiento de los _dashboards_, se puede ejecutar el script `demo-monitoring`, disponible tanto en una versión para PowerShell como en una versión para Bash.