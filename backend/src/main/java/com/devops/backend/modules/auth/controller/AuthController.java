/**
 * @file AuthController.java
 * @brief Gestiona las operaciones de registro, inicio de sesión y cierre de sesión de los usuarios.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

package com.devops.backend.modules.auth.controller;

import com.devops.backend.common.security.JwtCookieBearerTokenResolver;
import com.devops.backend.modules.auth.dto.AuthResponse;
import com.devops.backend.modules.auth.dto.LoginRequest;
import com.devops.backend.modules.auth.dto.RegisterRequest;
import com.devops.backend.modules.auth.service.AuthService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseCookie;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Duration;

@RestController
@RequestMapping("/api/auth")
@Tag(name = "Authentication", description = "Registro e inicio de sesión")
public class AuthController {

    private final AuthService authService;
    private final Duration sessionDuration;
    private final boolean cookieSecure;

    public AuthController(
            AuthService authService,
            @Value("${jwt.expiration-minutes:120}") long expirationMinutes,
            @Value("${app.cookie.secure:true}") boolean cookieSecure) {
        this.authService = authService;
        this.sessionDuration = Duration.ofMinutes(expirationMinutes);
        this.cookieSecure = cookieSecure;
    }

    /**
     * @brief Registra un nuevo usuario y establece su sesión de autenticación.
     *
     * @param request datos necesarios para registrar el nuevo usuario.
     * @return respuesta con la información de autenticación y estado HTTP 201.
     */
    @PostMapping("/register")
    public ResponseEntity<AuthResponse> register(@Valid @RequestBody RegisterRequest request) {
        return authenticatedResponse(authService.register(request), HttpStatus.CREATED);
    }

    /**
     * @brief Autentica un usuario y establece su sesión mediante una cookie.
     *
     * @param request datos necesarios para iniciar sesión.
     * @return respuesta con la información de autenticación y estado HTTP 200.
     */
    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest request) {
        return authenticatedResponse(authService.login(request), HttpStatus.OK);
    }

    /**
     * @brief Cierra la sesión del usuario eliminando la cookie de autenticación.
     *
     * @return respuesta HTTP 204 sin contenido.
     */
    @PostMapping("/logout")
    public ResponseEntity<Void> logout() {
        ResponseCookie expiredCookie = sessionCookie("").maxAge(Duration.ZERO).build();
        return ResponseEntity.noContent()
                .header(HttpHeaders.SET_COOKIE, expiredCookie.toString())
                .build();
    }

    /**
     * @brief Construye una respuesta autenticada estableciendo la cookie de sesión.
     *
     * @param response información de autenticación que será incluida en la respuesta.
     * @param status estado HTTP que tendrá la respuesta.
     * @return respuesta HTTP con la información de autenticación y la cookie de sesión.
     */
    private ResponseEntity<AuthResponse> authenticatedResponse(AuthResponse response, HttpStatus status) {
        ResponseCookie cookie = sessionCookie(response.token()).maxAge(sessionDuration).build();
        return ResponseEntity.status(status)
                .header(HttpHeaders.SET_COOKIE, cookie.toString())
                .body(response);
    }

    /**
     * @brief Configura la cookie utilizada para almacenar el token de sesión.
     *
     * @param value valor del token JWT que se almacenará en la cookie.
     * @return constructor configurado para crear la cookie de sesión.
     */
    private ResponseCookie.ResponseCookieBuilder sessionCookie(String value) {
        return ResponseCookie.from(JwtCookieBearerTokenResolver.COOKIE_NAME, value)
                .httpOnly(true)
                .secure(cookieSecure)
                .sameSite("Strict")
                .path("/");
    }
}