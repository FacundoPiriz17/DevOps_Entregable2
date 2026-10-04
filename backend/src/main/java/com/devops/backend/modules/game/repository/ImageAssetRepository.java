package com.devops.backend.modules.game.repository;

/**
 * @file ImageAssetRepository.java
 * @brief Proporciona operaciones de acceso y persistencia para las imágenes de los videojuegos.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.modules.game.entity.ImageAsset;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * @brief Repositorio para gestionar las operaciones de persistencia de la entidad ImageAsset.
 *
 */
public interface ImageAssetRepository extends JpaRepository<ImageAsset, Long> {
}