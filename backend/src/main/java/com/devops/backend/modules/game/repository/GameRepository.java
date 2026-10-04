package com.devops.backend.modules.game.repository;

/**
 * @file GameRepository.java
 * @brief Proporciona operaciones de acceso y persistencia para los videojuegos.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.modules.game.entity.Game;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * @brief Repositorio para gestionar las operaciones de persistencia de la entidad Game.
 *
 */
public interface GameRepository extends JpaRepository<Game, Long> {
}