package com.devops.backend.modules.game.controller;

/**
 * @file AdminGameController.java
 * @brief Gestiona las operaciones administrativas relacionadas con los videojuegos.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.common.config.OpenApiConfig;
import com.devops.backend.common.security.CurrentUser;
import com.devops.backend.modules.game.dto.GameRequest;
import com.devops.backend.modules.game.dto.GameResponse;
import com.devops.backend.modules.game.service.GameService;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * @brief Expone los endpoints administrativos para crear, modificar y desactivar videojuegos.
 *
 */
@RestController
@RequestMapping("/api/admin/games")
@Tag(name = "Game administration", description = "Alta, modificación y baja lógica de videojuegos")
@SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
public class AdminGameController {

    private final GameService gameService;
    private final CurrentUser currentUser;

    public AdminGameController(GameService gameService, CurrentUser currentUser) {
        this.gameService = gameService;
        this.currentUser = currentUser;
    }

    /**
     * @brief Crea un nuevo videojuego asociado al administrador autenticado.
     *
     * @param request datos necesarios para crear el videojuego.
     * @param auth token de autenticación del administrador actual.
     * @return respuesta HTTP 201 con la información del videojuego creado.
     */
    @PostMapping
    public ResponseEntity<GameResponse> create(@Valid @RequestBody GameRequest request, JwtAuthenticationToken auth) {
        GameResponse created = gameService.create(request, currentUser.emailFrom(auth));
        return ResponseEntity.status(HttpStatus.CREATED).body(created);
    }

    /**
     * @brief Actualiza la información de un videojuego existente.
     *
     * @param id identificador del videojuego que se desea modificar.
     * @param request nuevos datos del videojuego.
     * @return información actualizada del videojuego.
     */
    @PutMapping("/{id}")
    public GameResponse update(@PathVariable Long id, @Valid @RequestBody GameRequest request) {
        return gameService.update(id, request);
    }

    /**
     * @brief Desactiva un videojuego mediante una baja lógica.
     *
     * @param id identificador del videojuego que se desea desactivar.
     * @return información del videojuego después de su desactivación.
     */
    @PatchMapping("/{id}/deactivate")
    public GameResponse deactivate(@PathVariable Long id) {
        return gameService.deactivate(id);
    }
}