/**
 * @file CurrentUser.java
 * @brief Proporciona utilidades para obtener información del usuario autenticado actualmente.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

package com.devops.backend.common.security;

import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Component;

@Component
public class CurrentUser {

    /**
     * @brief Obtiene el correo electrónico del usuario autenticado en base al token JWT.
     *
     * @param authentication token de autenticación del usuario actual.
     * @return correo electrónico del usuario autenticado.
     */
    public String emailFrom(JwtAuthenticationToken authentication) {
        return authentication.getToken().getSubject();
    }
}