package com.devops.backend.modules.game.dto;

/**
 * @file CategoryRequest.java
 * @brief Representa los datos necesarios para crear una categoría de videojuego.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/**
 * @brief Contiene el nombre y tipo de la categoría que se desea registrar.
 *
 */
public record CategoryRequest(

        @NotBlank String name,

        @NotBlank @Pattern(regexp = "genero|etiqueta") String type) {

}