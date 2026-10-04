package com.devops.backend.modules.cart.entity;

/**
 * @file CartItem.java
 * @brief Representa un juego asociado al carrito de compras de un usuario.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

/**
 * @brief Entidad que relaciona un usuario con un juego dentro del carrito.
 *
 */
@Entity
@Table(name = "carrito")
public class CartItem {
    @EmbeddedId
    private CartItemId id;

    protected CartItem() {
    }

    public CartItem(String userEmail, Long gameId) {
        this.id = new CartItemId(gameId, userEmail);
    }

    /**
     * @brief Obtiene el identificador compuesto del elemento del carrito.
     *
     * @return identificador compuesto del elemento del carrito.
     */
    public CartItemId getId() { return id; }
}