package com.devops.backend.modules.auth.dto;

/**
 * @file RegisterRequest.java
 * @brief Representa los datos necesarios para registrar un nuevo usuario.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * @brief Contiene la información necesaria para crear una cuenta de usuario.
 *
 */
public record RegisterRequest(

        @NotBlank String name,

        @NotBlank @Email String email,

        @NotBlank String country,

        @NotBlank @Size(min = 8) String password) {

}