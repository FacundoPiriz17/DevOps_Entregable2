package com.devops.backend.modules.cart.entity;

/**
 * @file CartItemId.java
 * @brief Representa el identificador compuesto de un elemento del carrito.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;

import java.io.Serializable;
import java.util.Objects;

/**
 * @brief Identifica de forma única un elemento del carrito mediante el juego y el usuario.
 *
 */
@Embeddable
public class CartItemId implements Serializable {
    @Column(name = "identificador_juego")
    private Long gameId;
    @Column(name = "email_general")
    private String userEmail;

    protected CartItemId() {
    }

    public CartItemId(Long gameId, String userEmail) {
        this.gameId = gameId;
        this.userEmail = userEmail;
    }

    /**
     * @brief Obtiene el identificador del juego asociado al carrito.
     *
     * @return identificador del juego.
     */
    public Long getGameId() { return gameId; }

    /**
     * @brief Obtiene el correo electrónico del usuario propietario del carrito.
     *
     * @return correo electrónico del usuario.
     */
    public String getUserEmail() { return userEmail; }

    /**
     * @brief Compara este identificador con otro objeto para determinar si representan el mismo elemento.
     *
     * @param other objeto que se comparará con este identificador.
     * @return true si ambos identificadores contienen el mismo juego y usuario; false en caso contrario.
     */
    @Override
    public boolean equals(Object other) {
        if (this == other) return true;
        if (!(other instanceof CartItemId that)) return false;
        return Objects.equals(gameId, that.gameId) && Objects.equals(userEmail, that.userEmail);
    }

    /**
     * @brief Calcula el código hash del identificador compuesto.
     *
     * @return código hash calculado a partir del juego y el usuario.
     */
    @Override
    public int hashCode() { return Objects.hash(gameId, userEmail); }
}