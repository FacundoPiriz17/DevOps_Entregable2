# language: es
Característica: Gestión del catálogo de videojuegos
  Como administrador
  Quiero registrar, consultar, modificar y dar de baja videojuegos
  Para mantener el catálogo de la tienda actualizado y confiable

  Antecedentes:
    Dado que el administrador ha iniciado sesión con permisos de administrador

  Escenario: Registrar un nuevo videojuego en el catálogo
    Dado que el administrador quiere registrar un videojuego con los siguientes datos:
      | Nombre      | Death Stranding      |
      | Género      | Aventura             |
      | Descripción | Un juego de entregas |
    Cuando registra el videojuego
    Entonces el videojuego queda disponible en el catálogo
    Y los usuarios pueden consultarlo

  Escenario: Consultar el catálogo completo de videojuegos
    Dado que existen videojuegos activos e inactivos en el catálogo
    Cuando el administrador consulta el catálogo
    Entonces se muestra el listado completo de videojuegos
    Y se indica el estado de cada uno (activo o inactivo)

  Escenario: Modificar la información de un videojuego existente
    Dado que existe un videojuego registrado en el catálogo
    Cuando el administrador actualiza su información
    Entonces el catálogo refleja los datos actualizados

  Escenario: Intentar modificar un videojuego inexistente
    Dado que no existe un videojuego con el identificador indicado
    Cuando el administrador intenta modificar ese videojuego
    Entonces el sistema informa que el videojuego no existe
    Y no se realiza ningún cambio

  Escenario: Dar de baja un videojuego del catálogo
    Dado que existe un videojuego activo en el catálogo
    Cuando el administrador da de baja el videojuego
    Entonces el videojuego queda marcado como inactivo
    Y su información sigue siendo visible en el catálogo
    Y el videojuego deja de estar disponible para agregarse a una biblioteca

  Escenario: Intentar dar de baja un videojuego que ya está inactivo
    Dado que existe un videojuego que ya se encuentra inactivo
    Cuando el administrador intenta darlo de baja nuevamente
    Entonces el sistema informa que el videojuego ya está inactivo
    Y no se realiza ningún cambio
