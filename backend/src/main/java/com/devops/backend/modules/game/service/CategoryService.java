package com.devops.backend.modules.game.service;

/**
 * @file CategoryService.java
 * @brief Gestiona las operaciones relacionadas con las categorías de videojuegos.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.common.exception.ApiException;
import com.devops.backend.modules.game.dto.CategoryRequest;
import com.devops.backend.modules.game.dto.CategoryResponse;
import com.devops.backend.modules.game.entity.Category;
import com.devops.backend.modules.game.entity.CategoryType;
import com.devops.backend.modules.game.repository.CategoryRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * @brief Proporciona la lógica necesaria para consultar, crear y eliminar categorías.
 *
 */
@Service
public class CategoryService {

    private final CategoryRepository categoryRepository;

    public CategoryService(CategoryRepository categoryRepository) {
        this.categoryRepository = categoryRepository;
    }

    /**
     * @brief Obtiene todas las categorías registradas.
     *
     * @return lista de categorías disponibles.
     */
    @Transactional(readOnly = true)
    public List<CategoryResponse> listAll() {
        return categoryRepository.findAll().stream().map(CategoryResponse::from).toList();
    }

    /**
     * @brief Crea una nueva categoría comprobando que no exista otra igual.
     *
     * @param request datos necesarios para crear la categoría.
     * @return respuesta con la información de la categoría creada.
     * @throws ApiException si ya existe una categoría con el mismo nombre y tipo.
     */
    @Transactional
    public CategoryResponse create(CategoryRequest request) {
        CategoryType type = CategoryType.fromValue(request.type());
        String name = request.name().trim();
        if (categoryRepository.existsByNameIgnoreCaseAndType(name, type)) {
            throw ApiException.conflict("CATEGORY_ALREADY_EXISTS", "Category already exists");
        }
        return CategoryResponse.from(categoryRepository.save(new Category(name, type)));
    }

    /**
     * @brief Elimina una categoría existente.
     *
     * @param id identificador de la categoría que se desea eliminar.
     * @return no devuelve ningún valor.
     * @throws ApiException si la categoría no existe.
     */
    @Transactional
    public void delete(Long id) {
        if (!categoryRepository.existsById(id)) {
            throw ApiException.notFound("CATEGORY_NOT_FOUND", "Category does not exist");
        }
        categoryRepository.deleteById(id);
    }
}
