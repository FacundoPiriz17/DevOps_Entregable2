# language: es
Característica: Gestión de la biblioteca personal de videojuegos
  Como usuario registrado
  Quiero agregar videojuegos a mi biblioteca personal y consultarla
  Para acceder a los juegos que me interesan

  Antecedentes:
    Dado que el usuario ha iniciado sesión

  Escenario: Agregar un videojuego disponible a la biblioteca
    Dado que existe un videojuego activo que no está en la biblioteca del usuario
    Cuando el usuario agrega el videojuego a su biblioteca
    Entonces el videojuego aparece en su biblioteca personal

  Escenario: Intentar agregar un videojuego que ya está en la biblioteca
    Dado que el videojuego ya se encuentra en la biblioteca del usuario
    Cuando el usuario intenta agregarlo nuevamente
    Entonces el sistema informa que el videojuego ya está en su biblioteca
    Y no se duplica el registro

  Escenario: Intentar agregar un videojuego dado de baja a la biblioteca
    Dado que existe un videojuego marcado como inactivo
    Cuando el usuario intenta agregarlo a su biblioteca
    Entonces el sistema rechaza la operación
    Y informa que el videojuego ya no está disponible en la tienda

  Escenario: Consultar la biblioteca personal de videojuegos
    Dado que el usuario tiene videojuegos agregados a su biblioteca
    Cuando el usuario consulta su biblioteca
    Entonces se muestra el listado completo de sus videojuegos
