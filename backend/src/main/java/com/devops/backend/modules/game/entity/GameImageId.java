package com.devops.backend.modules.game.entity;

/**
 * @file GameImageId.java
 * @brief Representa el identificador compuesto de la relación entre un videojuego y una imagen.
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
 * @brief Identifica de forma única la relación entre un videojuego y una imagen.
 *
 */
@Embeddable
public class GameImageId implements Serializable {

    @Column(name = "identificador_juego")
    private Long gameId;

    @Column(name = "id_imagen")
    private Long imageId;

    protected GameImageId() {
    }

    public GameImageId(Long gameId, Long imageId) {
        this.gameId = gameId;
        this.imageId = imageId;
    }

    /**
     * @brief Obtiene el identificador del videojuego.
     *
     * @return identificador del videojuego.
     */
    public Long getGameId() { return gameId; }

    /**
     * @brief Obtiene el identificador de la imagen.
     *
     * @return identificador de la imagen.
     */
    public Long getImageId() { return imageId; }

    /**
     * @brief Compara este identificador con otro objeto para determinar si representan la misma relación.
     *
     * @param other objeto que se comparará con este identificador.
     * @return true si ambos identificadores contienen el mismo videojuego e imagen; false en caso contrario.
     */
    @Override
    public boolean equals(Object other) {
        if (this == other) return true;
        if (!(other instanceof GameImageId that)) return false;
        return Objects.equals(gameId, that.gameId) && Objects.equals(imageId, that.imageId);
    }

    /**
     * @brief Calcula el código hash del identificador compuesto.
     *
     * @return código hash calculado a partir del videojuego y la imagen.
     */
    @Override
    public int hashCode() { return Objects.hash(gameId, imageId); }
}