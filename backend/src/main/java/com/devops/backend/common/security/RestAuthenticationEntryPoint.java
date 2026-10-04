/**
 * @file RestAuthenticationEntryPoint.java
 * @brief Gestiona las respuestas REST cuando una solicitud requiere autenticación o presenta un token inválido.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

package com.devops.backend.common.security;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

import java.io.IOException;

@Component
public class RestAuthenticationEntryPoint implements AuthenticationEntryPoint {

    private final SecurityErrorResponseWriter errorWriter;

    public RestAuthenticationEntryPoint(SecurityErrorResponseWriter errorWriter) {
        this.errorWriter = errorWriter;
    }

    /**
     * @brief Genera una respuesta HTTP 401 cuando la autenticación es requerida o el token Bearer no es válido.
     *
     * @param request solicitud HTTP que requiere autenticación.
     * @param response respuesta HTTP en la que se escribe el error.
     * @param authenticationException excepción producida durante el proceso de autenticación.
     * @return no devuelve ningún valor.
     */
    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response,
                         AuthenticationException authenticationException) throws IOException {
        response.setHeader(HttpHeaders.WWW_AUTHENTICATE, "Bearer");
        errorWriter.write(
                response,
                HttpStatus.UNAUTHORIZED,
                "UNAUTHORIZED",
                "Autenticación requerida o token Bearer inválido.");
    }
}