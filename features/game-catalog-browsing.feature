# language: es
Característica: Exploración del catálogo de videojuegos
  Como usuario registrado
  Quiero navegar el catálogo y consultar el detalle de un videojuego
  Para decidir qué juegos agregar a mi biblioteca

  Antecedentes:
    Dado que el usuario ha iniciado sesión

  Escenario: Consultar el catálogo de videojuegos disponibles
    Dado que existen videojuegos activos e inactivos en la tienda
    Cuando el usuario consulta el catálogo
    Entonces se muestran todos los videojuegos, incluidos los inactivos
    Y los videojuegos inactivos se marcan como no disponibles

  Escenario: Consultar el detalle de un videojuego
    Dado que existe un videojuego activo en el catálogo
    Cuando el usuario consulta su detalle
    Entonces se muestra la información completa del videojuego

  Escenario: Un videojuego dado de baja se muestra como no disponible
    Dado que existe un videojuego marcado como inactivo
    Cuando el usuario consulta el catálogo
    Entonces el videojuego aparece en el listado
    Pero no puede agregarse a la biblioteca
