package com.devops.backend.modules.user.controller;

/**
 * @file UserController.java
 * @brief Gestiona las operaciones del usuario autenticado.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.common.config.OpenApiConfig;
import com.devops.backend.common.security.CurrentUser;
import com.devops.backend.modules.user.dto.UserBasicResponse;
import com.devops.backend.modules.user.service.UserService;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * @brief Expone los endpoints para consultar la información del usuario autenticado.
 *
 */
@RestController
@RequestMapping("/api/users")
@Tag(name = "Users", description = "Operaciones del usuario autenticado")
@SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
public class UserController {

    private final UserService userService;
    private final CurrentUser currentUser;

    public UserController(UserService userService, CurrentUser currentUser) {
        this.userService = userService;
        this.currentUser = currentUser;
    }

    /**
     * @brief Obtiene la información básica del usuario autenticado.
     *
     * @param auth token de autenticación del usuario actual.
     * @return información básica del usuario autenticado.
     */
    @GetMapping("/me")
    public UserBasicResponse getCurrentUser(JwtAuthenticationToken auth) {
        return userService.getCurrentUser(currentUser.emailFrom(auth));
    }
}
