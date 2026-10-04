/**
 * @file SecurityErrorResponseWriter.java
 * @brief Genera respuestas JSON para informar errores de seguridad en las solicitudes HTTP.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

package com.devops.backend.common.security;

import com.devops.backend.common.exception.ApiError;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import tools.jackson.databind.json.JsonMapper;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

@Component
public class SecurityErrorResponseWriter {

    private final JsonMapper jsonMapper;

    public SecurityErrorResponseWriter(JsonMapper jsonMapper) {
        this.jsonMapper = jsonMapper;
    }

    /**
     * @brief Escribe una respuesta JSON con la información del error y su estado HTTP correspondiente.
     *
     * @param response respuesta HTTP en la que se escribe el error.
     * @param status estado HTTP que tendrá la respuesta.
     * @param code código identificador del error.
     * @param message mensaje descriptivo del error.
     * @return no devuelve ningún valor.
     */
    public void write(HttpServletResponse response, HttpStatus status, String code, String message)
            throws IOException {
        response.setStatus(status.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        jsonMapper.writeValue(response.getOutputStream(), ApiError.of(status.value(), code, message));
    }
}