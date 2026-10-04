package com.devops.backend.modules.game.entity;

/**
 * @file GameImage.java
 * @brief Representa la relación entre un videojuego y una imagen.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

/**
 * @brief Entidad que relaciona un videojuego con una imagen y define el tipo de imagen asociado.
 *
 */
@Entity
@Table(name = "juego_imagen")
public class GameImage {

    @EmbeddedId
    private GameImageId id;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(name = "tipo", nullable = false, columnDefinition = "tipo_imagen")
    private ImageType type;

    protected GameImage() {
    }

    public GameImage(Long gameId, Long imageId, ImageType type) {
        this.id = new GameImageId(gameId, imageId);
        this.type = type;
    }

    /**
     * @brief Obtiene el identificador compuesto de la relación entre el videojuego y la imagen.
     *
     * @return identificador compuesto de la relación.
     */
    public GameImageId getId() { return id; }

    /**
     * @brief Obtiene el tipo de imagen asociado al videojuego.
     *
     * @return tipo de imagen asociado.
     */
    public ImageType getType() { return type; }
}