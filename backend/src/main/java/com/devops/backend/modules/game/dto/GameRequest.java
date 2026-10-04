package com.devops.backend.modules.game.dto;

/**
 * @file GameRequest.java
 * @brief Representa los datos necesarios para crear o actualizar un videojuego.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Set;

/**
 * @brief Contiene la información principal y las categorías asociadas a un videojuego.
 *
 */
public record GameRequest(
        @NotBlank String name,
        @NotBlank String description,
        @NotNull @DecimalMin("0.00") @Digits(integer = 8, fraction = 2) BigDecimal price,
        @NotNull LocalDate releaseDate,
        @NotBlank String studio,
        @NotBlank @Pattern(regexp = "publicado|pausado|preventa|retirado") String status,
        Set<Long> categoryIds) {
}