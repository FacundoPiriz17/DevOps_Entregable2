package com.devops.backend.modules.user.controller;

/**
 * @file UserAdminController.java
 * @brief Gestiona las operaciones administrativas relacionadas con los usuarios.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.common.config.OpenApiConfig;
import com.devops.backend.modules.user.dto.UserBasicResponse;
import com.devops.backend.modules.user.service.UserAdminService;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * @brief Expone los endpoints administrativos para consultar y desactivar usuarios.
 *
 */
@RestController
@RequestMapping("/api/admin/users")
@Tag(name = "User administration", description = "Consulta y baja lÃ³gica de usuarios")
@SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
public class UserAdminController {

    private final UserAdminService userAdminService;

    public UserAdminController(UserAdminService userAdminService) {
        this.userAdminService = userAdminService;
    }

    /**
     * @brief Obtiene la lista de usuarios registrados en la aplicación.
     *
     * @return lista de usuarios con su información básica.
     */
    @GetMapping
    public List<UserBasicResponse> getUsers() {
        return userAdminService.getUsers();
    }

    /**
     * @brief Obtiene la información básica de un usuario mediante su correo electrónico.
     *
     * @param email correo electrónico del usuario que se desea consultar.
     * @return información básica del usuario solicitado.
     */
    @GetMapping("/{email}")
    public UserBasicResponse getUser(@PathVariable String email) {
        return userAdminService.getUser(email);
    }

    /**
     * @brief Desactiva un usuario mediante una baja lógica.
     *
     * @param email correo electrónico del usuario que se desea desactivar.
     * @return información del usuario después de su desactivación.
     */
    @PatchMapping("/{email}/deactivate")
    public UserBasicResponse deactivate(@PathVariable String email) {
        return userAdminService.deactivate(email);
    }
}
