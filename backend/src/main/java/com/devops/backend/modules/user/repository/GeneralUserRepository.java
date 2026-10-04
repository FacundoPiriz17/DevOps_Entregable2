package com.devops.backend.modules.user.repository;

/**
 * @file GeneralUserRepository.java
 * @brief Proporciona operaciones de acceso y persistencia para los usuarios generales.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.modules.user.entity.GeneralUser;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * @brief Repositorio para gestionar las operaciones de persistencia de la entidad GeneralUser.
 *
 */
public interface GeneralUserRepository extends JpaRepository<GeneralUser, String> {
}
