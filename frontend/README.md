# Actualización de dependencias y correcciones de seguridad en el Frontend (Trivy)

## Objetivo

Este documento resume las versiones detectadas en el escaneo inicial de Trivy y las versiones corregidas indicadas por el propio reporte. El objetivo es actualizar las dependencias vulnerables del frontend reconstruir las imágenes Docker para volver a escanearlas.

> **NOTA:** las versiones de la columna “Versión corregida” son los objetivos de actualización tomados del reporte de Trivy. Para considerar una corrección finalizada, hay que comprobar que la versión quedó instalada en el `package-lock.json` o en el artefacto Java y volver a ejecutar Trivy sobre la imagen reconstruida.

## Instalación de Trivy

Antes de realizar el análisis de vulnerabilidades, es necesario instalar **Trivy** en el sistema. Para ello, se puede utilizar Windows Package Manager (`winget`) ejecutando el siguiente comando en una terminal:

```powershell
winget install AquaSecurity.Trivy
```

Una vez finalizada la instalación, se puede comprobar que Trivy se haya instalado correctamente y consultar su versión mediante:

```powershell
trivy --version
```

## Frontend

Archivo de dependencias directas: `frontend/package.json`  
Archivo de bloqueo: `frontend/package-lock.json`

El reporte inicial del frontend (ubicado en la carpeta `../reports/trivyreports_frontend`) encontró **25 vulnerabilidades: 20 HIGH y 5 CRITICAL**.

| Dependencia | Versión detectada | Versión corregida / objetivo | Observación |
|---|---:|---:|---|
| `next` | 16.3.1 | **16.4.1** | Actualización principal para corregir los hallazgos CRITICAL y HIGH informados para Next.js. |
| `eslint-config-next` | 16.3.1 | **16.4.1** | Se alinea con la versión de Next.js. |

No se incluyen las dependencias transitivas debido a que son demasiadas y no están declaradas directamente en `package.json`. Estas dependencias son incorporadas automáticamente por npm a través de otras dependencias y sus versiones exactas quedan registradas en `package-lock.json`.

### Sincronización del lockfile

Después de modificar `package.json`, es necesario regenerar el archivo de bloqueo. Desde la carpeta `frontend`:

```bash
npm install
```

`npm install` actualiza `package-lock.json`.

## Verificación final

Después de actualizar las dependencias y reconstruir las imágenes, volver a ejecutar Trivy:

```bash
trivy image playhub-frontend:v2.0
```

La actualización se considera verificada cuando el nuevo reporte de Trivy ya no muestra los hallazgos HIGH y CRITICAL correspondientes a las versiones anteriores.