# language: es
Característica: Registro e inicio de sesión de usuarios
  Como visitante interesado en la tienda
  Quiero registrarme e iniciar sesión
  Para acceder al catálogo y a mi biblioteca personal

  Escenario: Registrar una nueva cuenta de usuario
    Dado que un visitante quiere registrarse con los siguientes datos:
      | Nombre     | Julia Fernández     |
      | Email      | julia@example.com   |
      | Contraseña | ContraseñaSegura123 |
    Cuando completa el registro
    Entonces se crea su cuenta de usuario
    Y puede iniciar sesión con esas credenciales

  Escenario: Intentar registrarse con un email ya utilizado
    Dado que ya existe una cuenta registrada con el email "julia@example.com"
    Cuando un visitante intenta registrarse con ese mismo email
    Entonces el sistema rechaza el registro
    Y informa que el email ya está en uso

  Escenario: Iniciar sesión con credenciales válidas
    Dado que un usuario tiene una cuenta activa
    Cuando inicia sesión con su email y contraseña correctos
    Entonces accede a su cuenta
    Y puede ver su biblioteca personal

  Escenario: Intentar iniciar sesión con credenciales inválidas
    Dado que un usuario tiene una cuenta activa
    Cuando intenta iniciar sesión con una contraseña incorrecta
    Entonces el sistema rechaza el inicio de sesión
    Y no se concede acceso a la cuenta
