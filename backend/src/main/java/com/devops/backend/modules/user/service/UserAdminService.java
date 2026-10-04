package com.devops.backend.modules.user.service;

/**
 * @file UserAdminService.java
 * @brief Gestiona las operaciones administrativas relacionadas con los usuarios.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.common.exception.ApiException;
import com.devops.backend.common.util.EmailNormalizer;
import com.devops.backend.modules.user.dto.UserBasicResponse;
import com.devops.backend.modules.user.entity.User;
import com.devops.backend.modules.user.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * @brief Proporciona la lógica necesaria para consultar y desactivar usuarios.
 *
 */
@Service
public class UserAdminService {

    private final UserRepository userRepository;
    private final UserRoleService userRoleService;

    public UserAdminService(UserRepository userRepository, UserRoleService userRoleService) {
        this.userRepository = userRepository;
        this.userRoleService = userRoleService;
    }

    /**
     * @brief Obtiene la información básica de todos los usuarios registrados.
     *
     * @return lista de usuarios con su información básica y rol correspondiente.
     */
    @Transactional(readOnly = true)
    public List<UserBasicResponse> getUsers() {
        return userRepository.findAll().stream()
                .map(user -> UserBasicResponse.from(user, userRoleService.roleOf(user.getEmail())))
                .toList();
    }

    /**
     * @brief Obtiene la información básica de un usuario mediante su correo electrónico.
     *
     * @param email correo electrónico del usuario que se desea consultar.
     * @return información básica del usuario solicitado.
     * @throws ApiException si el usuario no existe.
     */
    @Transactional(readOnly = true)
    public UserBasicResponse getUser(String email) {
        String normalizedEmail = EmailNormalizer.normalize(email);
        User user = findUserOrThrow(normalizedEmail);
        return UserBasicResponse.from(user, userRoleService.roleOf(normalizedEmail));
    }

    /**
     * @brief Desactiva un usuario mediante una baja lógica.
     *
     * @param email correo electrónico del usuario que se desea desactivar.
     * @return información del usuario después de su desactivación.
     * @throws ApiException si el usuario no existe.
     */
    @Transactional
    public UserBasicResponse deactivate(String email) {
        String normalizedEmail = EmailNormalizer.normalize(email);
        User user = findUserOrThrow(normalizedEmail);
        user.setActive(false);
        return UserBasicResponse.from(user, userRoleService.roleOf(normalizedEmail));
    }

    /**
     * @brief Busca un usuario mediante su correo electrónico o genera un error si no existe.
     *
     * @param email correo electrónico del usuario que se desea buscar.
     * @return usuario encontrado.
     * @throws ApiException si el usuario no existe.
     */
    private User findUserOrThrow(String email) {
        return userRepository.findById(email)
                .orElseThrow(() -> ApiException.notFound("USER_NOT_FOUND", "User does not exist"));
    }
}
