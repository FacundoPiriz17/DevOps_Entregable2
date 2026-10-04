package com.devops.backend.modules.user.repository;

/**
 * @file UserRepository.java
 * @brief Proporciona operaciones de acceso y persistencia para los usuarios de la aplicación.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.modules.user.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * @brief Repositorio para gestionar las operaciones de persistencia de la entidad User.
 *
 */
public interface UserRepository extends JpaRepository<User, String> {
}
