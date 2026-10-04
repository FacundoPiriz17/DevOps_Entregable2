# Convenciones de documentación {#documentation_guide}

La documentación del proyecto debe permitir comprender decisiones, responsabilidades, contratos y restricciones sin repetir innecesariamente lo que ya expresa el código.

El objetivo no es documentar cada línea.

## Principio general

Debe documentarse principalmente el **por qué** y el **contrato** de un componente.

Debe evitarse utilizar comentarios para describir literalmente el código.

Por ejemplo, este comentario aporta poco valor:

```java
// Obtiene el usuario
User user = repository.findById(id);
```

En cambio, resulta útil explicar una restricción que no sea evidente:

```java
// Solo los usuarios activos pueden incorporar juegos a su biblioteca.
```

## Java

Las clases públicas y los métodos con comportamiento relevante pueden documentarse mediante Javadoc compatible con Doxygen.

Ejemplo:

```java
/**
 * Añade un videojuego disponible a la biblioteca del usuario.
 *
 * @param userId identificador del usuario
 * @param gameId identificador del videojuego
 * @return entrada creada en la biblioteca
 * @throws ApiException si el videojuego no existe o ya pertenece
 *                      a la biblioteca del usuario
 */
```

## Qué conviene documentar en Java

Se recomienda documentar:

- clases con responsabilidades importantes;
- interfaces;
- servicios;
- reglas de negocio;
- métodos públicos cuyo comportamiento no sea evidente;
- parámetros con restricciones;
- excepciones esperadas;
- decisiones de arquitectura;
- comportamientos relacionados con seguridad.

No es necesario documentar automáticamente:

- getters;
- setters;
- constructores triviales;
- métodos cuyo comportamiento sea evidente;
- código generado.

## DTO

Cuando un DTO represente un contrato importante de la API, su documentación debería indicar el propósito de sus campos cuando no sea suficientemente evidente por su nombre.

Las restricciones de validación deberían expresarse mediante las anotaciones correspondientes siempre que sea posible.

La documentación complementa esas restricciones, pero no debe reemplazarlas.

## JavaScript

Los componentes y funciones reutilizables pueden utilizar comentarios compatibles con JSDoc.

Ejemplo:

```javascript
/**
 * Renderiza información resumida de un videojuego.
 *
 * @param {Object} props propiedades del componente
 * @param {string} props.name nombre visible del videojuego
 * @returns {JSX.Element} componente renderizado
 */
```

## Qué conviene documentar en JavaScript

Se recomienda documentar especialmente:

- componentes reutilizables;
- hooks;
- clientes HTTP;
- funciones utilitarias;
- funciones con efectos secundarios;
- funciones con parámetros o retornos poco evidentes.

Los componentes de presentación simples no requieren comentarios extensos si su responsabilidad resulta evidente.

## Documentación Markdown

Los archivos ubicados en:

```text
docs
```

deben utilizarse para información que no pertenece naturalmente a una única clase.

Por ejemplo:

- arquitectura;
- decisiones técnicas;
- convenciones;
- relaciones entre componentes;
- explicación de mecanismos transversales;
- limitaciones conocidas.

No deberían utilizarse para copiar el contenido completo de Swagger, del README o del código fuente.

## Swagger y Doxygen

Swagger/OpenAPI y Doxygen tienen responsabilidades diferentes.

### Swagger/OpenAPI

Documenta el contrato externo de la API:

```text
Cliente <--> API
```

Incluye:

- endpoints;
- métodos HTTP;
- parámetros;
- cuerpos;
- esquemas;
- códigos de respuesta;
- autenticación.

### Doxygen

Documenta principalmente la implementación interna:

```text
Controller -> Service -> Repository -> Entity
```

Incluye:

- clases;
- funciones;
- módulos;
- relaciones;
- comentarios de implementación;
- documentación arquitectónica incluida en `docs`.

No debe duplicarse innecesariamente la misma información en ambas herramientas.

## Base de datos

El modelo entidad-relación puede utilizarse como apoyo visual para comprender el dominio.

Sin embargo, las migraciones ubicadas en:

```text
backend/src/main/resources/db/migration
```

deben considerarse la referencia ejecutable del esquema utilizado por la aplicación.

Cuando exista una diferencia entre un diagrama histórico y las migraciones vigentes, deberán actualizarse los diagramas correspondientes.

## Información sensible

Nunca deben incluirse en comentarios o documentación valores reales de:

- contraseñas;
- JWT secrets;
- tokens;
- credenciales de base de datos;
- claves privadas;
- secretos de servicios externos.

En los ejemplos deben utilizarse valores ficticios.

Por ejemplo:

```text
JWT_SECRET=<your-secret>
DB_PASSWORD=<your-password>
```

## Verificación

Antes de integrar cambios relacionados con documentación debe comprobarse que la generación de Doxygen finalice correctamente.

También es recomendable revisar que:

- no existan referencias rotas;
- los identificadores `@ref` correspondan a secciones existentes;
- no se incluyan archivos generados;
- no se expongan secretos;
- los comentarios continúen representando el comportamiento real del código.
