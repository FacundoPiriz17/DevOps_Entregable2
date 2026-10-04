package com.devops.backend.modules.game.controller;

/**
 * @file AdminCategoryController.java
 * @brief Gestiona las operaciones administrativas relacionadas con las categorías de juegos.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.common.config.OpenApiConfig;
import com.devops.backend.modules.game.dto.CategoryRequest;
import com.devops.backend.modules.game.dto.CategoryResponse;
import com.devops.backend.modules.game.service.CategoryService;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * @brief Expone los endpoints administrativos para crear y eliminar categorías de juegos.
 *
 */
@RestController
@RequestMapping("/api/admin/categories")
@Tag(name = "Category administration", description = "Alta y eliminación de géneros y etiquetas")
@SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
public class AdminCategoryController {
    private final CategoryService categoryService;

    public AdminCategoryController(CategoryService categoryService) { this.categoryService = categoryService; }

    /**
     * @brief Crea una nueva categoría de juegos.
     *
     * @param request datos necesarios para crear la categoría.
     * @return respuesta HTTP 201 con la información de la categoría creada.
     */
    @PostMapping
    public ResponseEntity<CategoryResponse> create(@Valid @RequestBody CategoryRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(categoryService.create(request));
    }

    /**
     * @brief Elimina una categoría de juegos.
     *
     * @param id identificador de la categoría que se desea eliminar.
     * @return respuesta HTTP 204 sin contenido.
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        categoryService.delete(id);
        return ResponseEntity.noContent().build();
    }
}