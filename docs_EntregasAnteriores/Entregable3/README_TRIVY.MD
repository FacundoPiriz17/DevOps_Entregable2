# Actualización de dependencias y correcciones de seguridad en el Backend (Trivy)

## Objetivo

Este documento resume las versiones detectadas en el escaneo inicial de Trivy y las versiones corregidas indicadas por el propio reporte. El objetivo es actualizar las dependencias vulnerables del backend reconstruir las imágenes Docker para volver a escanearlas.

> **NOTA:** las versiones de la columna “Versión corregida” son los objetivos de actualización tomados del reporte de Trivy.

## Instalación de Trivy

Antes de realizar el análisis de vulnerabilidades, es necesario instalar **Trivy** en el sistema. Para ello, se puede utilizar Windows Package Manager (`winget`) ejecutando el siguiente comando en una terminal:

```powershell
winget install AquaSecurity.Trivy
```

Una vez finalizada la instalación, se puede comprobar que Trivy se haya instalado correctamente y consultar su versión mediante:

```powershell
trivy --version
```

## Backend

Archivo principal de configuración: `backend/pom.xml`  
Imagen de ejecución: `backend/Dockerfile.prod`

El reporte inicial del backend encontró **14 vulnerabilidades en dependencias Java (10 HIGH y 4 CRITICAL)** y **1 vulnerabilidad CRITICAL en un paquete de Alpine Linux**.

| Dependencia / componente | Versión detectada | Versión corregida / objetivo | Dónde se gestiona |
|---|---:|---:|---|
| Spring Boot (`spring-boot-starter-parent`) | 4.1.1 | **4.1.2** | `backend/pom.xml`; actualización del BOM para gestionar versiones transitivas. |

La actualización de `spring-boot-starter-parent` a 4.1.2 se plantea para gestionar las versiones de las dependencias transitivas a través del BOM de Spring Boot. Esta versión gestiona Jackson 2.21.7, Jackson 3.1.7 y Tomcat 11.0.27. Después del cambio, conviene comprobar las versiones efectivamente resueltas por Maven.

Para el paquete del sistema operativo, se debe incorporar la actualización disponible de Alpine durante la construcción de la imagen. Por ejemplo, el siguiente comando permite actualizar específicamente `brotli-libs` a una versión corregida disponible en los repositorios:

```dockerfile
RUN apk upgrade --no-cache brotli-libs
```

## Verificación final

Después de actualizar las dependencias y reconstruir las imágenes, volver a ejecutar Trivy:

```bash
trivy image playhub-backend:v2.0
```

La actualización se considera verificada cuando el nuevo reporte de Trivy ya no muestra los hallazgos HIGH y CRITICAL correspondientes a las versiones anteriores.