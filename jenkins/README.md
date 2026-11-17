# Pipeline Jenkins local

La pipeline contiene cinco etapas en `jenkins/Jenkinsfile`:

1. Clonacion del repositorio y preparacion de las imagenes de herramientas.
2. Analisis estatico con Semgrep. Los hallazgos ERROR bloquean la ejecucion.
3. Construccion y tests: Maven `clean verify` con Testcontainers y JUnit; frontend `npm ci`, lint y build, en paralelo.
4. Construccion y publicacion de ambas imagenes en el registro local `localhost:5001`.
5. Despliegue automatico en Minikube mediante Helm, espera de disponibilidad y `helm test`.

El release y namespace son **playhub-local**. No se utilizan credenciales ni URLs de team9. Las imagenes llevan `local-<build>-<commit>`, se publican en el registry local y se importan en el runtime Docker de Minikube. El monitoreo existente del chart queda habilitado en modo `cluster`. No se instala ni modifica el stack Kyverno/Falco desde esta pipeline.

## Conservar la automatizacion actual

Mantener el job **Pipeline from SCM**, su repositorio, rama `*/main`, Script Path `jenkins/Jenkinsfile` y webhook existente. La pipeline agrega `pollSCM('H/2 * * * *')`: comprueba nuevos commits cada dos minutos. El webhook puede disparar inmediatamente; varios pushes entre comprobaciones pueden agruparse en un build. Ejecutar una primera corrida para registrar los parametros y el disparador actualizados.

`DEPLOY=true` despliega solo main; pull requests, tags y otras ramas no actualizan Kubernetes. `DEPLOY=false` permite CI y publicacion local sin desplegar.

El agente debe ser Linux, con Bash, Git, Docker CLI y acceso al socket `/var/run/docker.sock` del Docker local donde esta Minikube. Las otras herramientas se construyen y ejecutan en contenedores, por lo que no hace falta reemplazar el servidor Jenkins existente. Las caches Maven/npm usan volumenes propios y sobreviven a la limpieza del workspace.

Para un repositorio Git privado puede conservarse la credencial SCM existente. El resto del flujo local no requiere credenciales de servicios externos.

## Preparacion local

Iniciar el perfil Docker de Minikube antes de ejecutar el job:

```powershell
minikube start --profile minikube --driver=docker --container-runtime=docker
```

El despliegue verifica la etiqueta del contenedor `minikube`, usa solo su configuracion Kubernetes temporal y la elimina al terminar. No usa el contexto Kubernetes ni el kubeconfig remoto del agente. Los valores se aplican en orden: `values-dev.yaml`, `values-lab.yaml`, `values-local.yaml`. PostgreSQL conserva su PVC; el monitoreo usa almacenamiento efimero.

## Reportes y acceso

Jenkins archiva `reports/ci/**` y `reports/semgrep-report.txt`. JUnit publica `backend/target/surefire-reports/*.xml`. Si falla Helm, el diagnostico queda en `reports/ci/local-deploy-diagnostics.txt`. El workspace se limpia al terminar; las caches de dependencias sobreviven.

Tras un despliegue exitoso, ejecutar en terminales separadas:

```powershell
kubectl --context minikube -n playhub-local port-forward svc/playhub-local-frontend 5745:5745
kubectl --context minikube -n playhub-local port-forward svc/playhub-local-backend 8080:8080
kubectl --context minikube -n playhub-local port-forward svc/playhub-local-grafana 3000:3000
kubectl --context minikube -n playhub-local port-forward svc/playhub-local-prometheus 9090:9090
```

Frontend: http://localhost:5745. API: http://localhost:8080. Grafana: http://localhost:3000, usuario `admin`, clave local `PlayHub123`. Prometheus: http://localhost:9090. Las imagenes del frontend se construyen con API `http://localhost:8080` y CORS permite el origen `http://localhost:5745`.

La validacion local de etapas individuales no equivale a una corrida completa del job. Registrar el numero de build y sus artefactos cuando se ejecute desde Jenkins.
