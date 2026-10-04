package com.devops.backend.modules.game.dto;

/**
 * @file GameImageResponse.java
 * @brief Representa la información de una imagen asociada a un videojuego.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.modules.game.entity.GameImage;
import com.devops.backend.modules.game.entity.ImageAsset;

/**
 * @brief Contiene los datos principales de una imagen de videojuego.
 *
 */
public record GameImageResponse(Long id, String url, String alternativeText, String type) {

    /**
     * @brief Crea una respuesta de imagen a partir de sus entidades asociadas.
     *
     * @param link relación entre el videojuego y la imagen.
     * @param image recurso de imagen del que se obtendrán los datos.
     * @return respuesta con la información de la imagen y su tipo.
     */
    public static GameImageResponse from(GameImage link, ImageAsset image) {

        return new GameImageResponse(image.getId(), image.getUrl(), image.getAlternativeText(),

                link.getType().value());

    }

}