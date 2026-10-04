package com.devops.backend.modules.user.service;

/**
 * @file UserRoleService.java
 * @brief Gestiona la obtención del rol asociado a las cuentas de usuario.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.common.exception.ApiException;
import com.devops.backend.modules.user.entity.Role;
import com.devops.backend.modules.user.repository.AdministratorRepository;
import com.devops.backend.modules.user.repository.GeneralUserRepository;
import org.springframework.stereotype.Service;

/**
 * @brief Proporciona la lógica necesaria para determinar el rol de una cuenta de usuario.
 *
 */
@Service
public class UserRoleService {

    private final AdministratorRepository administratorRepository;
    private final GeneralUserRepository generalUserRepository;

    public UserRoleService(AdministratorRepository administratorRepository,
                           GeneralUserRepository generalUserRepository) {
        this.administratorRepository = administratorRepository;
        this.generalUserRepository = generalUserRepository;
    }

    /**
     * @brief Obtiene el rol asignado a una cuenta mediante su correo electrónico.
     *
     * @param email correo electrónico de la cuenta cuyo rol se desea obtener.
     * @return rol asignado a la cuenta.
     * @throws ApiException si la cuenta no tiene un rol asignado.
     */
    public Role roleOf(String email) {
        if (administratorRepository.existsById(email)) return Role.ADMIN;
        if (generalUserRepository.existsById(email)) return Role.USER;
        throw ApiException.forbidden("ACCOUNT_ROLE_MISSING", "The account does not have an assigned role");
    }
}
