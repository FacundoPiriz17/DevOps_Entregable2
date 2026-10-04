package com.devops.backend.modules.game.dto;

/**
 * @file CategoryResponse.java
 * @brief Representa la información de una categoría de videojuego.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.modules.game.entity.Category;

/**
 * @brief Contiene los datos de una categoría y su tipo.
 *
 */
public record CategoryResponse(Long id, String name, String type) {

    /**
     * @brief Crea una respuesta de categoría a partir de una entidad Category.
     *
     * @param category categoría de la que se obtendrán los datos.
     * @return respuesta con la información de la categoría.
     */
    public static CategoryResponse from(Category category) {

        return new CategoryResponse(category.getId(), category.getName(), category.getType().value());

    }

}