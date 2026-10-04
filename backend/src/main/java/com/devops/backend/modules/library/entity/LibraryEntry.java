package com.devops.backend.modules.library.entity;

/**
 * @file LibraryEntry.java
 * @brief Representa un videojuego adquirido y almacenado en la biblioteca de un usuario.
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
 * @brief Entidad que relaciona un usuario con un videojuego adquirido y su estado de favorito.
 *
 */
@Entity
@Table(name = "biblioteca")
public class LibraryEntry {

    @EmbeddedId
    private LibraryEntryId id;

    @Column(name = "fecha_compra", nullable = false)
    private LocalDate purchasedAt = LocalDate.now();

    @Column(name = "es_favorito", nullable = false)
    private boolean favorite;

    protected LibraryEntry() {
    }

    public LibraryEntry(String userEmail, Long gameId) {
        this.id = new LibraryEntryId(gameId, userEmail);
    }

    /**
     * @brief Obtiene el identificador compuesto de la entrada de biblioteca.
     *
     * @return identificador compuesto de la entrada de biblioteca.
     */
    public LibraryEntryId getId() { return id; }

    /**
     * @brief Obtiene la fecha en la que se adquirió el videojuego.
     *
     * @return fecha de compra del videojuego.
     */
    public LocalDate getPurchasedAt() { return purchasedAt; }

    /**
     * @brief Comprueba si el videojuego está marcado como favorito.
     *
     * @return true si el videojuego está marcado como favorito; false en caso contrario.
     */
    public boolean isFavorite() { return favorite; }

    /**
     * @brief Actualiza el estado de favorito del videojuego.
     *
     * @param favorite nuevo estado de favorito del videojuego.
     * @return no devuelve ningún valor.
     */
    public void setFavorite(boolean favorite) { this.favorite = favorite; }
}
