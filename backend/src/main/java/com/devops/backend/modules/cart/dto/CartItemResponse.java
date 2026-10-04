package com.devops.backend.modules.cart.dto;

/**
 * @file CartItemResponse.java
 * @brief Representa la información de un juego incluido en el carrito de compras.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.modules.game.entity.Game;

import java.math.BigDecimal;

/**
 * @brief Contiene los datos principales de un juego dentro del carrito.
 *
 */
public record CartItemResponse(Long gameId, String name, BigDecimal price, String status) {

    /**
     * @brief Crea una respuesta del carrito a partir de la información de un juego.
     *
     * @param game juego del que se obtendrán los datos.
     * @return respuesta con la información del juego para el carrito.
     */
    public static CartItemResponse from(Game game) {

        return new CartItemResponse(game.getId(), game.getName(), game.getPrice(), game.getStatus().value());

    }

}