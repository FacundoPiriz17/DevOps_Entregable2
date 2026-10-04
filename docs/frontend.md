# Arquitectura del frontend {#frontend_overview}

El frontend de PlayHub está desarrollado con **Next.js** y utiliza el **App Router**.

El código fuente principal se encuentra en:

```text
frontend/src
```

Su responsabilidad es proporcionar la interfaz utilizada por el usuario y consumir los servicios expuestos por el backend de PlayHub.

## Organización principal

La aplicación utiliza la estructura proporcionada por el App Router de Next.js.

La base del frontend se encuentra en:

```text
frontend/src/app
```

Entre los archivos principales se encuentran:

```text
app/
├── layout.js
├── page.js
└── globals.css
```

A medida que la aplicación incorpore nuevas páginas y funcionalidades, esta estructura puede ampliarse mediante rutas, componentes y módulos adicionales.

## `layout.js`

`app/layout.js` define la estructura raíz compartida por las páginas de la aplicación.

Entre sus responsabilidades pueden encontrarse:

- definición de metadatos;
- carga de fuentes;
- incorporación de estilos globales;
- definición de elementos compartidos entre páginas.

El layout raíz envuelve al resto de las páginas renderizadas por Next.js.

## `page.js`

`app/page.js` representa la página asociada a la ruta raíz:

```text
/
```

Su responsabilidad debe limitarse principalmente a la presentación y composición de componentes.

La lógica reutilizable o suficientemente compleja debería extraerse a componentes, hooks o módulos independientes.

## `globals.css`

`app/globals.css` contiene estilos globales aplicados a la aplicación.

Aunque forma parte del frontend, este archivo no necesita documentación semántica mediante Doxygen.

La documentación debe concentrarse principalmente en elementos cuyo comportamiento o contrato no resulte evidente.

## Comunicación con el backend

El frontend consume la API REST expuesta por Spring Boot.

La comunicación general sigue el siguiente flujo:

```text
Usuario
   |
   v
Next.js
   |
   | HTTP / JSON
   v
Spring Boot
   |
   v
PostgreSQL
```

El frontend no debe acceder directamente a la base de datos.

Toda operación persistente debe realizarse a través de la API.

## Autenticación

Cuando una operación requiera autenticación, el frontend debe utilizar el mecanismo definido por el backend.

Para endpoints protegidos mediante JWT, las solicitudes autenticadas utilizan el esquema Bearer:

```text
Authorization: Bearer <token>
```

El frontend no debe implementar por sí mismo reglas de autorización que deban garantizarse en el servidor.

Las restricciones aplicadas visualmente en la interfaz tienen como objetivo mejorar la experiencia de usuario, pero la autorización real debe validarse siempre en el backend.

## Componentes

A medida que la interfaz crezca, los componentes reutilizables deberían separarse de las páginas.

Por ejemplo:

```text
frontend/src/
├── app/
├── components/
├── hooks/
└── lib/
```

Esta estructura es únicamente una guía y debe utilizarse cuando esos módulos realmente sean necesarios.

No deben agregarse directorios vacíos únicamente para anticipar funcionalidades futuras.

## Clientes HTTP

Cuando varias páginas consuman el backend, es recomendable centralizar la configuración común de las solicitudes HTTP.

Esto permite evitar repetir:

- URL base;
- headers;
- serialización;
- manejo común de autenticación;
- tratamiento básico de errores.

La lógica específica de cada funcionalidad debería permanecer cerca del módulo responsable de esa funcionalidad.

## Documentación JavaScript

Los componentes y funciones reutilizables pueden documentarse mediante comentarios compatibles con JSDoc.

Por ejemplo:

```javascript
/**
 * Presenta la información resumida de un videojuego.
 *
 * @param {Object} props propiedades del componente
 * @param {string} props.name nombre visible del videojuego
 * @returns {JSX.Element} tarjeta renderizada
 */
```

No es necesario documentar cada función únicamente para aumentar la cantidad de comentarios.

La documentación es especialmente útil cuando existen:

- parámetros poco evidentes;
- restricciones;
- efectos secundarios;
- valores de retorno relevantes;
- decisiones de diseño;
- comportamiento que no pueda deducirse fácilmente del código.

## Archivos excluidos de Doxygen

Las dependencias y archivos generados automáticamente no deberían formar parte de la documentación.

Entre ellos:

```text
node_modules
.next
```

Estos directorios pueden ser reconstruidos a partir del código fuente y de las dependencias declaradas por el proyecto.

## Responsabilidad del frontend

El frontend debe encargarse principalmente de:

- presentación;
- navegación;
- interacción con el usuario;
- validaciones orientadas a experiencia de usuario;
- consumo de la API.

Las reglas críticas de negocio y seguridad deben mantenerse en el backend.
