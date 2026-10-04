/**
 * @file RestAccessDeniedHandler.java
 * @brief Gestiona las respuestas REST cuando un usuario no tiene permisos para acceder a un recurso.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

package com.devops.backend.common.security;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;

import java.io.IOException;

@Component
public class RestAccessDeniedHandler implements AccessDeniedHandler {

    private final SecurityErrorResponseWriter errorWriter;

    public RestAccessDeniedHandler(SecurityErrorResponseWriter errorWriter) {
        this.errorWriter = errorWriter;
    }

    /**
     * @brief Genera una respuesta HTTP 403 cuando el usuario no tiene permisos para realizar la acción solicitada.
     *
     * @param request solicitud HTTP que generó el acceso denegado.
     * @param response respuesta HTTP en la que se escribe el error.
     * @param accessDeniedException excepción producida por el acceso denegado.
     * @return no devuelve ningún valor.
     */
    @Override
    public void handle(HttpServletRequest request, HttpServletResponse response,
                       AccessDeniedException accessDeniedException) throws IOException {
        errorWriter.write(
                response,
                HttpStatus.FORBIDDEN,
                "ACCESS_DENIED",
                "No tiene permisos para acceder a este recurso.");
    }
}