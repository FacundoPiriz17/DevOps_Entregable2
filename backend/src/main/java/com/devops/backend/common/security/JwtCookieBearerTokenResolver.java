/**
 * @file JwtCookieBearerTokenResolver.java
 * @brief Resuelve el token JWT de autenticación desde el encabezado HTTP o una cookie de sesión.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

package com.devops.backend.common.security;

import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.security.oauth2.server.resource.web.BearerTokenResolver;
import org.springframework.security.oauth2.server.resource.web.DefaultBearerTokenResolver;

import java.util.Arrays;

public class JwtCookieBearerTokenResolver implements BearerTokenResolver {

    public static final String COOKIE_NAME = "playhub_session";

    private final DefaultBearerTokenResolver headerResolver = new DefaultBearerTokenResolver();

    /**
     * @brief Obtiene el token JWT desde el encabezado de autorización o desde la cookie de sesión.
     *
     * @param request solicitud HTTP de la que se obtiene el token de autenticación.
     * @return token JWT encontrado en el encabezado o en la cookie, o null si no existe.
     */
    @Override
    public String resolve(HttpServletRequest request) {
        String headerToken = headerResolver.resolve(request);
        if (headerToken != null) {
            return headerToken;
        }

        Cookie[] cookies = request.getCookies();
        if (cookies == null) {
            return null;
        }

        return Arrays.stream(cookies)
                .filter(cookie -> COOKIE_NAME.equals(cookie.getName()))
                .map(Cookie::getValue)
                .filter(value -> !value.isBlank())
                .findFirst()
                .orElse(null);
    }
}