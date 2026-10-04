package com.devops.backend.modules.user.dto;

/**
 * @file UserBasicResponse.java
 * @brief Representa la información básica de un usuario.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.modules.user.entity.Role;
import com.devops.backend.modules.user.entity.User;

import java.time.LocalDate;

/**
 * @brief Contiene los datos principales de un usuario, su rol y estado de actividad.
 *
 */
public record UserBasicResponse(
        String name,
        String email,
        String country,
        String role,
        boolean active,
        LocalDate registeredAt) {

    /**
     * @brief Crea una respuesta de usuario a partir de sus entidades de usuario y rol.
     *
     * @param user usuario del que se obtendrán los datos principales.
     * @param role rol asignado al usuario.
     * @return respuesta con la información básica del usuario.
     */
    public static UserBasicResponse from(User user, Role role) {
        return new UserBasicResponse(user.getName(), user.getEmail(), user.getCountry(), role.name(),
                user.isActive(), user.getRegisteredAt());
    }
}
