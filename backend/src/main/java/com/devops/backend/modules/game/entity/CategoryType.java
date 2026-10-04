package com.devops.backend.modules.game.entity;

/**
 * @file CategoryType.java
 * @brief Define los tipos disponibles para las categorías de videojuegos.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import jakarta.persistence.EnumeratedValue;

import java.util.Locale;

/**
 * @brief Enumera los tipos de categoría y sus valores almacenados en la base de datos.
 *
 */
public enum CategoryType {
    GENERO("genero"),
    ETIQUETA("etiqueta");

    @EnumeratedValue
    private final String databaseValue;

    CategoryType(String databaseValue) { this.databaseValue = databaseValue; }

    /**
     * @brief Obtiene el valor de la categoría utilizado en la base de datos.
     *
     * @return valor de la categoría.
     */
    public String value() { return databaseValue; }

    /**
     * @brief Convierte un valor de texto en su tipo de categoría correspondiente.
     *
     * @param value valor de texto que se desea convertir.
     * @return tipo de categoría correspondiente al valor proporcionado.
     */
    public static CategoryType fromValue(String value) {
        return valueOf(value.trim().toUpperCase(Locale.ROOT));
    }
}