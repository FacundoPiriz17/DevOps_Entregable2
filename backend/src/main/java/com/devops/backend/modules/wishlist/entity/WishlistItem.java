package com.devops.backend.modules.wishlist.entity;

/**
 * @file WishlistItem.java
 * @brief Representa un videojuego incluido en la lista de deseados de un usuario.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */
import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

import java.time.LocalDate;

/**
 * @brief Entidad que relaciona un usuario con un videojuego incluido en su lista de deseados.
 *
 */
@Entity
@Table(name = "deseados")
public class WishlistItem {
    @EmbeddedId
    private WishlistItemId id;
    @Column(name = "fecha_agregado", nullable = false)
    private LocalDate addedAt = LocalDate.now();

    protected WishlistItem() {
    }

    public WishlistItem(String userEmail, Long gameId) {
        this.id = new WishlistItemId(gameId, userEmail);
    }

    /**
     * @brief Obtiene el identificador compuesto del elemento de la lista de deseados.
     *
     * @return identificador compuesto del elemento.
     */
    public WishlistItemId getId() { return id; }

    /**
     * @brief Obtiene la fecha en la que el videojuego fue añadido a la lista de deseados.
     *
     * @return fecha en la que se añadió el videojuego.
     */
    public LocalDate getAddedAt() { return addedAt; }
}
