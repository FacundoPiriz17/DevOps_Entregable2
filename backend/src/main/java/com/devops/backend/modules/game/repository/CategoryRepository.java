package com.devops.backend.modules.game.repository;

/**
 * @file CategoryRepository.java
 * @brief Proporciona operaciones de acceso y persistencia para las categorías de videojuegos.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.modules.game.entity.Category;
import com.devops.backend.modules.game.entity.CategoryType;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * @brief Repositorio para gestionar las operaciones de persistencia de la entidad Category.
 *
 */
public interface CategoryRepository extends JpaRepository<Category, Long> {

    /**
     * @brief Comprueba si existe una categoría con el nombre y tipo indicados.
     *
     * @param name nombre de la categoría que se desea comprobar.
     * @param type tipo de categoría que se desea comprobar.
     * @return true si existe una categoría con el nombre y tipo indicados; false en caso contrario.
     */
    boolean existsByNameIgnoreCaseAndType(String name, CategoryType type);
}