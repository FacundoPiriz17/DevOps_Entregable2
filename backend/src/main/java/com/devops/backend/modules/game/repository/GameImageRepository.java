package com.devops.backend.modules.game.repository;

/**
 * @file GameImageRepository.java
 * @brief Proporciona operaciones de acceso y persistencia para las imágenes asociadas a videojuegos.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.modules.game.entity.GameImage;
import com.devops.backend.modules.game.entity.GameImageId;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

/**
 * @brief Repositorio para gestionar las operaciones de persistencia de la entidad GameImage.
 *
 */
public interface GameImageRepository extends JpaRepository<GameImage, GameImageId> {

    /**
     * @brief Obtiene las imágenes asociadas a un videojuego.
     *
     * @param gameId identificador del videojuego.
     * @return lista de imágenes asociadas al videojuego.
     */
    List<GameImage> findByIdGameId(Long gameId);

    /**
     * @brief Comprueba si una imagen está asociada a algún videojuego.
     *
     * @param imageId identificador de la imagen que se desea comprobar.
     * @return true si la imagen está asociada a algún videojuego; false en caso contrario.
     */
    boolean existsByIdImageId(Long imageId);
}