package com.devops.backend.modules.game.controller;

/**
 * @file CategoryController.java
 * @brief Gestiona la consulta de las categorías de videojuegos.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.common.config.OpenApiConfig;
import com.devops.backend.modules.game.dto.CategoryResponse;
import com.devops.backend.modules.game.service.CategoryService;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * @brief Expone los endpoints para consultar las categorías disponibles de videojuegos.
 *
 */
@RestController
@RequestMapping("/api/categories")
@Tag(name = "Categories", description = "Consulta de géneros y etiquetas")
@SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
public class CategoryController {
    private final CategoryService categoryService;

    public CategoryController(CategoryService categoryService) { this.categoryService = categoryService; }

    /**
     * @brief Obtiene todas las categorías de videojuegos disponibles.
     *
     * @return lista de categorías de videojuegos.
     */
    @GetMapping
    public List<CategoryResponse> listAll() { return categoryService.listAll(); }
}