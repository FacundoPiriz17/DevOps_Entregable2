package com.devops.backend.modules.game.entity;

/**
 * @file GameStatus.java
 * @brief Define los estados disponibles para los videojuegos.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import jakarta.persistence.EnumeratedValue;

import java.util.Locale;

/**
 * @brief Enumera los estados de un videojuego y determina si puede ser comprado.
 *
 */
public enum GameStatus {
    PUBLICADO("publicado"),
    PAUSADO("pausado"),
    PREVENTA("preventa"),
    RETIRADO("retirado");

    @EnumeratedValue
    private final String databaseValue;

    GameStatus(String databaseValue) {
        this.databaseValue = databaseValue;
    }

    /**
     * @brief Obtiene el valor del estado utilizado en la base de datos.
     *
     * @return valor del estado del videojuego.
     */
    public String value() { return databaseValue; }

    /**
     * @brief Comprueba si el videojuego puede ser adquirido.
     *
     * @return true si el videojuego está publicado o en preventa; false en caso contrario.
     */
    public boolean isPurchasable() {
        return this == PUBLICADO || this == PREVENTA;
    }

    /**
     * @brief Convierte un valor de texto en su estado de videojuego correspondiente.
     *
     * @param value valor de texto que se desea convertir.
     * @return estado de videojuego correspondiente al valor proporcionado.
     */
    public static GameStatus fromValue(String value) {
        return valueOf(value.trim().toUpperCase(Locale.ROOT));
    }
}