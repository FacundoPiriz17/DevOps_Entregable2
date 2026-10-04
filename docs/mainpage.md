# PlayHub {#mainpage}

PlayHub es una aplicación web académica orientada a la gestión y distribución de videojuegos.

El sistema está compuesto por:

- un **backend REST** desarrollado con Spring Boot;
- un **frontend web** desarrollado con Next.js;
- una base de datos **PostgreSQL**;
- autenticación y autorización mediante **JWT**;
- migraciones versionadas de base de datos;
- herramientas de documentación automática para facilitar el mantenimiento del proyecto.

## Arquitectura general

La aplicación se divide principalmente en tres componentes:

```text
Usuario
   |
   v
Frontend - Next.js
   |
   | HTTP / REST
   v
Backend - Spring Boot
   |
   | JPA
   v
PostgreSQL
```

El frontend es responsable de presentar la interfaz de usuario y consumir la API.

El backend concentra:

- reglas de negocio;
- autenticación y autorización;
- validaciones;
- acceso a datos;
- exposición de endpoints REST.

PostgreSQL almacena de forma persistente la información correspondiente a usuarios, videojuegos y demás entidades del dominio.

## Documentación de la API

El contrato HTTP de la aplicación se documenta mediante OpenAPI y puede consultarse desde Swagger UI cuando el backend está en ejecución:

```text
http://localhost:8080/swagger-ui.html
```

Swagger constituye la referencia principal para:

- endpoints disponibles;
- métodos HTTP;
- parámetros;
- cuerpos de las solicitudes;
- códigos de respuesta;
- esquemas de datos;
- endpoints protegidos mediante Bearer JWT.

La documentación generada con Doxygen complementa esta información mostrando la estructura interna del proyecto, clases, módulos, funciones y relaciones entre componentes.

## Contenido de esta documentación

La documentación se organiza en las siguientes secciones:

- @ref backend_overview "Arquitectura del backend"
- @ref frontend_overview "Arquitectura del frontend"
- @ref documentation_guide "Convenciones de documentación"

## Estructura documentada

Doxygen analiza principalmente las siguientes ubicaciones:

```text
backend/src/main/java
frontend/src
docs
```

### Backend

Se documentan:

- paquetes;
- clases;
- interfaces;
- enumeraciones;
- controladores;
- servicios;
- repositorios;
- entidades;
- DTO;
- configuración transversal.

### Frontend

Se documentan los módulos JavaScript relevantes ubicados dentro de:

```text
frontend/src
```

incluyendo componentes y funciones reutilizables cuando corresponda.

## Salida generada

La documentación HTML generada por Doxygen se almacena en:

```text
docs/generated/html
```

Este directorio contiene archivos generados automáticamente y no debe mantenerse manualmente.

Siempre que sea posible, la salida generada debe excluirse del control de versiones y regenerarse a partir del código fuente y de los archivos ubicados en `docs`.
