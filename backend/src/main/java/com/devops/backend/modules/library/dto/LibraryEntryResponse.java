package com.devops.backend.modules.library.dto;

/**
 * @file LibraryEntryResponse.java
 * @brief Representa la información de un videojuego incluido en la biblioteca del usuario.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.modules.game.entity.Game;
import com.devops.backend.modules.library.entity.LibraryEntry;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * @brief Contiene los datos principales de un videojuego adquirido por el usuario y su estado de favorito.
 *
 */
public record LibraryEntryResponse(
        Long gameId,
        String name,
        String description,
        BigDecimal price,
        String studio,
        LocalDate purchasedAt,
        boolean favorite) {

    /**
     * @brief Crea una respuesta de biblioteca a partir de la entrada de biblioteca y el videojuego asociado.
     *
     * @param entry entrada de biblioteca que contiene la fecha de compra y el estado de favorito.
     * @param game videojuego del que se obtendrán los datos principales.
     * @return respuesta con la información del videojuego y su estado en la biblioteca.
     */
    public static LibraryEntryResponse from(LibraryEntry entry, Game game) {
        return new LibraryEntryResponse(game.getId(), game.getName(), game.getDescription(), game.getPrice(),
                game.getStudio(), entry.getPurchasedAt(), entry.isFavorite());
    }
}
