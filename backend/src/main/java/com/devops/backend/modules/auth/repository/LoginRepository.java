package com.devops.backend.modules.auth.repository;

/**
 * @file LoginRepository.java
 * @brief Proporciona operaciones de acceso y persistencia para las credenciales de los usuarios.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.modules.auth.entity.Login;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * @brief Repositorio para gestionar las operaciones de persistencia de la entidad Login.
 *
 */
public interface LoginRepository extends JpaRepository<Login, String> {

}