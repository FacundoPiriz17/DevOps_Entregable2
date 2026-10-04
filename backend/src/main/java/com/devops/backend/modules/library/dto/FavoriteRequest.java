package com.devops.backend.modules.library.dto;

/**
 * @file FavoriteRequest.java
 * @brief Representa los datos necesarios para actualizar el estado de favorito de un videojuego.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import jakarta.validation.constraints.NotNull;

/**
 * @brief Contiene el estado que indica si un videojuego debe marcarse como favorito.
 *
 */
public record FavoriteRequest(@NotNull Boolean favorite) {
}
