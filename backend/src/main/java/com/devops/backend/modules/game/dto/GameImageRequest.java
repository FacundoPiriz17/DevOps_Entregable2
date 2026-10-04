package com.devops.backend.modules.game.dto;

/**
 * @file GameImageRequest.java
 * @brief Representa los datos necesarios para añadir una imagen a un videojuego.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/**
 * @brief Contiene la URL, texto alternativo y tipo de una imagen de videojuego.
 *
 */
public record GameImageRequest(

        @NotBlank String url,

        String alternativeText,

        @NotBlank @Pattern(regexp = "portada|banner|galeria") String type) {

}