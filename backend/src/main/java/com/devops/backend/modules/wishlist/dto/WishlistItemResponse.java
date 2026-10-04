package com.devops.backend.modules.wishlist.dto;

/**
 * @file WishlistItemResponse.java
 * @brief Representa la información de un videojuego incluido en la lista de deseados.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.modules.game.entity.Game;
import com.devops.backend.modules.wishlist.entity.WishlistItem;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * @brief Contiene los datos principales de un videojuego incluido en la lista de deseados.
 *
 */
public record WishlistItemResponse(
        Long gameId, String name, BigDecimal price, String status, LocalDate addedAt) {

    /**
     * @brief Crea una respuesta de la lista de deseados a partir del elemento y videojuego asociados.
     *
     * @param item elemento de la lista de deseados que contiene la fecha de incorporación.
     * @param game videojuego del que se obtendrán los datos principales.
     * @return respuesta con la información del videojuego y la fecha en que fue añadido.
     */
    public static WishlistItemResponse from(WishlistItem item, Game game) {
        return new WishlistItemResponse(game.getId(), game.getName(), game.getPrice(),
                game.getStatus().value(), item.getAddedAt());
    }
}
