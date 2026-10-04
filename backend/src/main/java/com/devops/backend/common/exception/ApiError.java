/**
 * @file ApiError.java
 * @brief Define la estructura de los errores de la API y proporciona un método para crearlos.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

package com.devops.backend.common.exception;

import java.time.Instant;

public record ApiError(Instant timestamp, int status, String code, String message) {

    /**
     * @brief Crea una instancia de ApiError con la fecha y hora actuales.
     *
     * @param status estado HTTP asociado al error.
     * @param code código identificador del error.
     * @param message mensaje descriptivo del error.
     * @return instancia de ApiError creada con la información proporcionada.
     */
    public static ApiError of(int status, String code, String message) {
        return new ApiError(Instant.now(), status, code, message);
    }
}
