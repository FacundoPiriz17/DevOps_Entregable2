/**
 * @file GlobalExceptionHandler.java
 * @brief Gestiona de forma global las excepciones de la API y genera respuestas HTTP con información del error.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

package com.devops.backend.common.exception;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class GlobalExceptionHandler {

    /**
     * @brief Gestiona las excepciones personalizadas de la API para devolver su estado y código correspondiente.
     *
     * @param ex excepción personalizada de la API.
     * @return respuesta HTTP con la información del error.
     */
    @ExceptionHandler(ApiException.class)
    public ResponseEntity<ApiError> handleApiException(ApiException ex) {
        return ResponseEntity.status(ex.getStatus())
                .body(ApiError.of(ex.getStatus().value(), ex.getCode(), ex.getMessage()));
    }

    /**
     * @brief Gestiona los errores de credenciales inválidas durante la autenticación.
     *
     * @param ex excepción generada por credenciales inválidas.
     * @return respuesta HTTP 401 con la información del error.
     */
    @ExceptionHandler(BadCredentialsException.class)
    public ResponseEntity<ApiError> handleBadCredentials(BadCredentialsException ex) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(ApiError.of(401, "INVALID_CREDENTIALS", "Invalid email or password"));
    }

    /**
     * @brief Gestiona los errores de acceso denegado por falta de permisos.
     *
     * @param ex excepción generada cuando el usuario no tiene permisos suficientes.
     * @return respuesta HTTP 403 con la información del error.
     */
    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ApiError> handleAccessDenied(AccessDeniedException ex) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN)
                .body(ApiError.of(403, "ACCESS_DENIED", "You do not have permission to perform this action"));
    }

    /**
     * @brief Gestiona los errores de validación de los datos recibidos en las solicitudes.
     *
     * @param ex excepción generada cuando los datos de la solicitud no superan la validación.
     * @return respuesta HTTP 400 con la información del error de validación.
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiError> handleValidation(MethodArgumentNotValidException ex) {
        String message = ex.getBindingResult().getFieldErrors().stream()
                .findFirst()
                .map(fieldError -> fieldError.getField() + " " + fieldError.getDefaultMessage())
                .orElse("Invalid request");
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(ApiError.of(400, "VALIDATION_ERROR", message));
    }
}