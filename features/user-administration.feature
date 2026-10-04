# language: es
CaracterÃ­stica: AdministraciÃ³n de usuarios
  Como administrador
  Quiero consultar informaciÃ³n bÃ¡sica de los usuarios y dar de baja cuentas cuando corresponda
  Para mantener el sistema bajo control

  Antecedentes:
    Dado que el administrador ha iniciado sesiÃ³n con permisos de administrador

  Escenario: Consultar los usuarios registrados
    Dado que existen usuarios registrados en el sistema
    Cuando el administrador consulta el listado de usuarios
    Entonces se muestran sus datos bÃ¡sicos de cuenta

  Escenario: Consultar informaciÃ³n bÃ¡sica de un usuario registrado
    Dado que existe un usuario registrado en el sistema
    Cuando el administrador consulta su informaciÃ³n
    Entonces se muestran sus datos bÃ¡sicos de cuenta

  Escenario: Dar de baja una cuenta de usuario
    Dado que existe una cuenta de usuario activa
    Cuando el administrador da de baja esa cuenta
    Entonces la cuenta queda marcada como inactiva
    Y el usuario ya no puede iniciar sesiÃ³n
    Y su biblioteca se conserva

  Escenario: Un usuario sin permisos de administrador intenta consultar informaciÃ³n de otro usuario
    Dado que un usuario no tiene permisos de administrador
    Cuando intenta consultar la informaciÃ³n de otro usuario
    Entonces el sistema deniega el acceso