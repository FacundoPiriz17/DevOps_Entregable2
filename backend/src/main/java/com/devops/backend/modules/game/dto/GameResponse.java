package com.devops.backend.modules.game.dto;

/**
 * @file GameResponse.java
 * @brief Representa la información completa de un videojuego.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.modules.game.entity.Game;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Comparator;
import java.util.List;

/**
 * @brief Contiene los datos principales de un videojuego, sus categorías e imágenes.
 *
 */
public record GameResponse(
        Long id,
        String name,
        String description,
        BigDecimal price,
        LocalDate releaseDate,
        String studio,
        String status,
        boolean available,
        String registeredBy,
        LocalDate registeredAt,
        List<CategoryResponse> categories,
        List<GameImageResponse> images) {

    /**
     * @brief Crea una respuesta de videojuego a partir de su entidad y sus imágenes.
     *
     * @param game videojuego del que se obtendrán los datos.
     * @param images lista de imágenes asociadas al videojuego.
     * @return respuesta con la información completa del videojuego.
     */
    public static GameResponse from(Game game, List<GameImageResponse> images) {
        List<CategoryResponse> categories = game.getCategories().stream()
                .map(CategoryResponse::from)
                .sorted(Comparator.comparing(CategoryResponse::id))
                .toList();
        return new GameResponse(game.getId(), game.getName(), game.getDescription(), game.getPrice(),
                game.getReleaseDate(), game.getStudio(), game.getStatus().value(),
                game.getStatus().isPurchasable(), game.getRegisteredByAdminEmail(), game.getRegisteredAt(),
                categories, images);
    }
}