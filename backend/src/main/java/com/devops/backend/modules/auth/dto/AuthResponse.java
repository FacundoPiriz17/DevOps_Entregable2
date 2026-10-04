package com.devops.backend.modules.auth.dto;

/**
 * @file AuthResponse.java
 * @brief Representa la información de autenticación devuelta al usuario.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.fasterxml.jackson.annotation.JsonIgnore;
import io.swagger.v3.oas.annotations.media.Schema;

/**
 * @brief Contiene los datos del usuario autenticado y su token de acceso.
 *
 */
public record AuthResponse(
        @JsonIgnore @Schema(hidden = true) String token,
        String name,
        String email,
        String country,
        String role) {
}