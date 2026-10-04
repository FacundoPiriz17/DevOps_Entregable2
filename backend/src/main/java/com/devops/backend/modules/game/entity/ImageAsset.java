package com.devops.backend.modules.game.entity;

/**
 * @file ImageAsset.java
 * @brief Representa una imagen almacenada para su uso en los videojuegos.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * @brief Entidad que almacena la URL y el texto alternativo de una imagen.
 *
 */
@Entity
@Table(name = "imagen")
public class ImageAsset {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_imagen")
    private Long id;

    @Column(name = "url", nullable = false)
    private String url;

    @Column(name = "texto_alternativo")
    private String alternativeText;

    protected ImageAsset() {
    }

    public ImageAsset(String url, String alternativeText) {
        this.url = url;
        this.alternativeText = alternativeText;
    }

    /**
     * @brief Obtiene el identificador de la imagen.
     *
     * @return identificador de la imagen.
     */
    public Long getId() { return id; }

    /**
     * @brief Obtiene la URL de la imagen.
     *
     * @return URL de la imagen.
     */
    public String getUrl() { return url; }

    /**
     * @brief Obtiene el texto alternativo de la imagen.
     *
     * @return texto alternativo de la imagen.
     */
    public String getAlternativeText() { return alternativeText; }
}