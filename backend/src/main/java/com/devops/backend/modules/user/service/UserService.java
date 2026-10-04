package com.devops.backend.modules.user.service;

/**
 * @file UserService.java
 * @brief Gestiona las operaciones relacionadas con la información del usuario autenticado.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.common.exception.ApiException;
import com.devops.backend.modules.user.dto.UserBasicResponse;
import com.devops.backend.modules.user.entity.User;
import com.devops.backend.modules.user.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * @brief Proporciona la lógica necesaria para consultar la información del usuario autenticado.
 *
 */
@Service
public class UserService {

    private final UserRepository userRepository;
    private final UserRoleService userRoleService;

    public UserService(UserRepository userRepository, UserRoleService userRoleService) {
        this.userRepository = userRepository;
        this.userRoleService = userRoleService;
    }

    /**
     * @brief Obtiene la información básica del usuario autenticado mediante su correo electrónico.
     *
     * @param email correo electrónico del usuario que se desea consultar.
     * @return información básica del usuario autenticado.
     */
    @Transactional(readOnly = true)
    public UserBasicResponse getCurrentUser(String email) {
        User user = userRepository.findById(email)
                .orElseThrow(() -> ApiException.notFound("USER_NOT_FOUND", "User does not exist"));
        return UserBasicResponse.from(user, userRoleService.roleOf(email));
    }
}
