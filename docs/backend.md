# Arquitectura del backend {#backend_overview}

El backend de PlayHub está desarrollado con **Spring Boot** y concentra la lógica de negocio, seguridad, persistencia y exposición de la API REST.

El código fuente principal se encuentra en:

```text
backend/src/main/java/com/devops/backend
```

La aplicación sigue una organización modular que separa las responsabilidades transversales de las funcionalidades específicas del dominio.

## Organización general

La estructura principal puede representarse de la siguiente manera:

```text
com.devops.backend
│
├── common
│   ├── config
│   ├── exception
│   └── security
│
├── modules
│   └── ...
│
└── DevopsBackendApplication
```

El paquete `common` contiene infraestructura reutilizada por múltiples módulos, mientras que `modules` agrupa las funcionalidades propias de la aplicación.

## Capas principales

Dentro de cada módulo pueden existir diferentes capas según las necesidades de la funcionalidad.

### Controller

Los controladores representan la interfaz HTTP del backend.

Sus responsabilidades principales son:

- recibir solicitudes;
- validar datos de entrada;
- delegar la ejecución a los servicios;
- devolver las respuestas HTTP correspondientes.

Los controladores no deberían contener lógica de negocio compleja.

```text
HTTP Request
     |
     v
 Controller
```

### Service

Los servicios implementan los casos de uso y las reglas de negocio de la aplicación.

Entre sus responsabilidades pueden encontrarse:

- validaciones de negocio;
- coordinación entre repositorios;
- transformación de entidades;
- control de operaciones;
- aplicación de restricciones del dominio.

```text
Controller
    |
    v
 Service
```

### Repository

Los repositorios encapsulan el acceso a la persistencia utilizando Spring Data JPA.

Su objetivo es evitar que los servicios dependan directamente de detalles relacionados con SQL o con la implementación concreta de la base de datos.

```text
Service
   |
   v
Repository
   |
   v
PostgreSQL
```

### Entity

Las entidades representan el estado persistente del dominio y permiten mapear los datos almacenados en PostgreSQL mediante JPA.

Estas clases deben representar el modelo persistente y no utilizarse automáticamente como contratos públicos de la API.

### DTO

Los DTO, o *Data Transfer Objects*, definen los datos intercambiados entre el cliente y el backend.

Su utilización permite separar:

```text
Modelo persistente
       !=
Contrato HTTP
```

Esto reduce el acoplamiento entre la base de datos y la API.

## Componentes transversales

El paquete `common` contiene funcionalidades compartidas por distintos módulos.

### `common.config`

Contiene configuraciones generales del backend.

Puede incluir, entre otras:

- configuración de OpenAPI;
- beans compartidos;
- configuraciones relacionadas con la infraestructura.

### `common.security`

Centraliza los componentes relacionados con autenticación y autorización.

El backend utiliza Spring Security y autenticación basada en JWT.

El flujo general es:

```text
Usuario
   |
   | credenciales
   v
Endpoint de autenticación
   |
   | JWT
   v
Cliente
   |
   | Authorization: Bearer <token>
   v
Spring Security
   |
   v
Recurso protegido
```

Las responsabilidades de esta capa incluyen:

- validación de JWT;
- identificación del usuario autenticado;
- conversión de roles o autoridades;
- autorización de endpoints;
- manejo de respuestas ante accesos no autenticados o no autorizados.

Las contraseñas nunca deben almacenarse en texto plano.

### `common.exception`

Concentra el manejo común de errores de la API.

Su función es convertir excepciones de la aplicación en respuestas HTTP consistentes, evitando que cada controlador implemente manualmente su propio tratamiento de errores.

Un error debería producir una respuesta predecible para el cliente, incluyendo únicamente la información necesaria para interpretar el problema.

## API REST

El backend expone una API REST consumida por el frontend.

La documentación del contrato HTTP se genera mediante OpenAPI.

Con el backend ejecutándose, Swagger UI puede consultarse en:

```text
http://localhost:8080/swagger-ui.html
```

Swagger/OpenAPI debe considerarse la referencia principal para conocer:

- rutas disponibles;
- métodos HTTP;
- parámetros;
- cuerpos de solicitud;
- esquemas;
- códigos de respuesta;
- requerimientos de autenticación.

Doxygen tiene un propósito diferente: documentar la **estructura e implementación interna** del código.

## Persistencia

PlayHub utiliza PostgreSQL como sistema de persistencia.

Spring Data JPA permite que las entidades del dominio sean almacenadas y recuperadas mediante repositorios.

Las modificaciones estructurales de la base de datos se gestionan mediante migraciones ubicadas en:

```text
backend/src/main/resources/db/migration
```

Las migraciones versionadas deben considerarse la fuente de verdad del esquema utilizado por la aplicación.

No se recomienda modificar manualmente una base de datos desplegada para incorporar cambios estructurales.

En su lugar, cualquier cambio debe quedar representado por una nueva migración.

Por ejemplo:

```text
V1__initial_schema.sql
V2__new_feature.sql
V3__schema_change.sql
```

Esto permite reconstruir una base de datos desde cero y mantener el historial de evolución del esquema.

## Flujo típico de una solicitud

Una operación habitual del backend sigue aproximadamente este recorrido:

```text
Cliente
   |
   v
Controller
   |
   v
Service
   |
   v
Repository
   |
   v
PostgreSQL
```

La respuesta sigue el recorrido inverso:

```text
PostgreSQL
   |
   v
Repository
   |
   v
Service
   |
   v
DTO
   |
   v
Controller
   |
   v
Cliente
```

Esta separación facilita:

- mantenimiento;
- pruebas;
- reutilización;
- evolución independiente de cada capa.

## Principios de mantenimiento

La documentación debe explicar especialmente decisiones y restricciones que no sean evidentes simplemente leyendo el código.
