/**
 * @file ApiException.java
 * @brief Define una excepción personalizada para manejar errores de la API con su estado HTTP y código.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

package com.devops.backend.common.exception;

import org.springframework.http.HttpStatus;

public class ApiException extends RuntimeException {

    private final HttpStatus status;
    private final String code;

    public ApiException(HttpStatus status, String code, String message) {
        super(message);
        this.status = status;
        this.code = code;
    }

    /**
     * @brief Crea una excepción indicando que el recurso solicitado no fue encontrado.
     *
     * @param code código identificador del error.
     * @param message mensaje descriptivo del error.
     * @return excepción ApiException con estado HTTP 404.
     */
    public static ApiException notFound(String code, String message) {
        return new ApiException(HttpStatus.NOT_FOUND, code, message);
    }

    /**
     * @brief Crea una excepción indicando un conflicto en la solicitud.
     *
     * @param code código identificador del error.
     * @param message mensaje descriptivo del error.
     * @return excepción ApiException con estado HTTP 409.
     */
    public static ApiException conflict(String code, String message) {
        return new ApiException(HttpStatus.CONFLICT, code, message);
    }

    /**
     * @brief Crea una excepción indicando que la solicitud contiene datos inválidos.
     *
     * @param code código identificador del error.
     * @param message mensaje descriptivo del error.
     * @return excepción ApiException con estado HTTP 400.
     */
    public static ApiException badRequest(String code, String message) {
        return new ApiException(HttpStatus.BAD_REQUEST, code, message);
    }

    /**
     * @brief Crea una excepción indicando que la solicitud no está autenticada.
     *
     * @param code código identificador del error.
     * @param message mensaje descriptivo del error.
     * @return excepción ApiException con estado HTTP 401.
     */
    public static ApiException unauthorized(String code, String message) {
        return new ApiException(HttpStatus.UNAUTHORIZED, code, message);
    }

    /**
     * @brief Crea una excepción indicando que el usuario no tiene permisos suficientes.
     *
     * @param code código identificador del error.
     * @param message mensaje descriptivo del error.
     * @return excepción ApiException con estado HTTP 403.
     */
    public static ApiException forbidden(String code, String message) {
        return new ApiException(HttpStatus.FORBIDDEN, code, message);
    }

    /**
     * @brief Obtiene el estado HTTP asociado a la excepción.
     *
     * @return estado HTTP de la excepción.
     */
    public HttpStatus getStatus() {
        return status;
    }

    /**
     * @brief Obtiene el código asociado a la excepción.
     *
     * @return código identificador del error.
     */
    public String getCode() {
        return code;
    }
}