# Scripts de la pipeline local

La configuracion del job y el acceso a Minikube se documentan en [jenkins/README.md](../../jenkins/README.md).

| Archivo | Funcion |
| --- | --- |
| `with-tools.sh` | Ejecuta comandos en la imagen de herramientas compartiendo el workspace del agente. |
| `scan-semgrep.sh` | Analisis estatico con reglas versionadas; bloquea ERROR. |
| `run-build.sh` | Tests/build Maven y lint/build Node, con caches persistentes. |
| `build-images.sh` | Construye las dos imagenes con un tag `local-*`. |
| `publish-local.sh` | Publica en el registry local, ligado a 127.0.0.1:5001. |
| `deploy-local.sh` | Importa las imagenes a Minikube y ejecuta Helm con monitoreo activo. |
| `cache-volume.sh` | Prepara caches propias sin modificar volumenes ajenos. |

Los scripts remotos anteriores `build-and-push.sh` y `scripts/deploy-helm.sh --registry` no son invocados por Jenkins. El flujo vigente no utiliza credenciales Kubernetes de team9 ni hace push a Docker Hub.
