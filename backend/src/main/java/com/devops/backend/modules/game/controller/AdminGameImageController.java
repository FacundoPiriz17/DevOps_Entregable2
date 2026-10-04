package com.devops.backend.modules.game.controller;

/**
 * @file AdminGameImageController.java
 * @brief Gestiona las operaciones administrativas relacionadas con las imágenes de los videojuegos.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.common.config.OpenApiConfig;
import com.devops.backend.modules.game.dto.GameImageRequest;
import com.devops.backend.modules.game.dto.GameImageResponse;
import com.devops.backend.modules.game.service.GameImageService;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * @brief Expone los endpoints administrativos para añadir y eliminar imágenes de videojuegos.
 *
 */
@RestController
@RequestMapping("/api/admin/games/{gameId}/images")
@Tag(name = "Game image administration", description = "Gestión de imágenes asociadas a videojuegos")
@SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
public class AdminGameImageController {
    private final GameImageService gameImageService;

    public AdminGameImageController(GameImageService gameImageService) { this.gameImageService = gameImageService; }

    /**
     * @brief Añade una nueva imagen a un videojuego.
     *
     * @param gameId identificador del videojuego al que se asociará la imagen.
     * @param request datos necesarios para crear la imagen.
     * @return respuesta HTTP 201 con la información de la imagen añadida.
     */
    @PostMapping
    public ResponseEntity<GameImageResponse> add(@PathVariable Long gameId,
                                                  @Valid @RequestBody GameImageRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(gameImageService.add(gameId, request));
    }

    /**
     * @brief Elimina una imagen asociada a un videojuego.
     *
     * @param gameId identificador del videojuego al que pertenece la imagen.
     * @param imageId identificador de la imagen que se desea eliminar.
     * @return respuesta HTTP 204 sin contenido.
     */
    @DeleteMapping("/{imageId}")
    public ResponseEntity<Void> remove(@PathVariable Long gameId, @PathVariable Long imageId) {
        gameImageService.remove(gameId, imageId);
        return ResponseEntity.noContent().build();
    }
}