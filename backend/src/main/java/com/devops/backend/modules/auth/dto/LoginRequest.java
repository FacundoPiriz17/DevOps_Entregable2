package com.devops.backend.modules.auth.dto;

/**
 * @file LoginRequest.java
 * @brief Representa los datos necesarios para iniciar sesión.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

/**
 * @brief Contiene el correo electrónico y la contraseña utilizados para autenticar al usuario.
 *
 */
public record LoginRequest(

        @NotBlank @Email String email,

        @NotBlank String password) {

}