package com.devops.backend.modules.game.entity;

/**
 * @file ImageType.java
 * @brief Define los tipos disponibles para las imágenes de los videojuegos.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import jakarta.persistence.EnumeratedValue;

import java.util.Locale;

/**
 * @brief Enumera los tipos de imagen y sus valores almacenados en la base de datos.
 *
 */
public enum ImageType {
    PORTADA("portada"),
    BANNER("banner"),
    GALERIA("galeria");

    @EnumeratedValue
    private final String databaseValue;

    ImageType(String databaseValue) { this.databaseValue = databaseValue; }

    /**
     * @brief Obtiene el valor del tipo de imagen utilizado en la base de datos.
     *
     * @return valor del tipo de imagen.
     */
    public String value() { return databaseValue; }

    /**
     * @brief Convierte un valor de texto en su tipo de imagen correspondiente.
     *
     * @param value valor de texto que se desea convertir.
     * @return tipo de imagen correspondiente al valor proporcionado.
     */
    public static ImageType fromValue(String value) {
        return valueOf(value.trim().toUpperCase(Locale.ROOT));
    }
}