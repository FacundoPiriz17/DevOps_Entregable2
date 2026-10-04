package com.devops.backend.modules.game.controller;

/**
 * @file GameController.java
 * @brief Gestiona la consulta del catálogo de videojuegos.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.common.config.OpenApiConfig;
import com.devops.backend.modules.game.dto.GameResponse;
import com.devops.backend.modules.game.service.GameService;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * @brief Expone los endpoints para consultar el catálogo de videojuegos.
 *
 */
@RestController
@RequestMapping("/api/games")
@Tag(name = "Games", description = "Consulta del catálogo de videojuegos")
@SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
public class GameController {

    private final GameService gameService;

    public GameController(GameService gameService) {
        this.gameService = gameService;
    }

    /**
     * @brief Obtiene todos los videojuegos disponibles en el catálogo.
     *
     * @return lista de videojuegos del catálogo.
     */
    @GetMapping
    public List<GameResponse> listGames() {
        return gameService.listAll();
    }

    /**
     * @brief Obtiene la información de un videojuego mediante su identificador.
     *
     * @param id identificador del videojuego que se desea consultar.
     * @return información del videojuego solicitado.
     */
    @GetMapping("/{id}")
    public GameResponse getGame(@PathVariable Long id) {
        return gameService.getById(id);
    }
}