package com.devops.backend.modules.auth.service;

/**
 * @file AuthService.java
 * @brief Gestiona el registro, autenticación y generación de respuestas de autenticación de los usuarios.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.common.exception.ApiException;
import com.devops.backend.common.security.JwtService;
import com.devops.backend.common.util.EmailNormalizer;
import com.devops.backend.modules.auth.dto.AuthResponse;
import com.devops.backend.modules.auth.dto.LoginRequest;
import com.devops.backend.modules.auth.dto.RegisterRequest;
import com.devops.backend.modules.auth.entity.Login;
import com.devops.backend.modules.auth.repository.LoginRepository;
import com.devops.backend.modules.user.entity.GeneralUser;
import com.devops.backend.modules.user.entity.Role;
import com.devops.backend.modules.user.entity.User;
import com.devops.backend.modules.user.repository.GeneralUserRepository;
import com.devops.backend.modules.user.repository.UserRepository;
import com.devops.backend.modules.user.service.UserRoleService;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * @brief Proporciona la lógica necesaria para registrar y autenticar usuarios.
 *
 */
@Service
public class AuthService {

    private final UserRepository userRepository;
    private final LoginRepository loginRepository;
    private final GeneralUserRepository generalUserRepository;
    private final UserRoleService userRoleService;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    public AuthService(UserRepository userRepository,
                       LoginRepository loginRepository,
                       GeneralUserRepository generalUserRepository,
                       UserRoleService userRoleService,
                       PasswordEncoder passwordEncoder,
                       JwtService jwtService) {
        this.userRepository = userRepository;
        this.loginRepository = loginRepository;
        this.generalUserRepository = generalUserRepository;
        this.userRoleService = userRoleService;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
    }

    /**
     * @brief Registra un nuevo usuario y almacena sus credenciales de forma segura.
     *
     * @param request datos necesarios para registrar el nuevo usuario.
     * @return respuesta con la información del usuario registrado y su autenticación.
     * @throws ApiException si el correo electrónico ya está registrado.
     */
    @Transactional
    public AuthResponse register(RegisterRequest request) {
        String email = normalizeEmail(request.email());
        if (userRepository.existsById(email)) {
            throw ApiException.conflict("EMAIL_ALREADY_USED", "Email is already in use");
        }

        User user = userRepository.save(new User(request.name().trim(), email, request.country().trim()));
        loginRepository.save(new Login(email, passwordEncoder.encode(request.password())));
        generalUserRepository.save(new GeneralUser(email));
        return toAuthResponse(user, Role.USER);
    }

    /**
     * @brief Autentica un usuario mediante su correo electrónico y contraseña.
     *
     * @param request datos necesarios para iniciar sesión.
     * @return respuesta con la información del usuario autenticado y su token.
     * @throws ApiException si la cuenta del usuario está desactivada o no se puede determinar su rol.
     */
    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest request) {
        String email = normalizeEmail(request.email());
        User user = userRepository.findById(email)
                .orElseThrow(() -> new BadCredentialsException("Invalid email or password"));
        Login login = loginRepository.findById(email)
                .orElseThrow(() -> new BadCredentialsException("Invalid email or password"));

        if (!passwordEncoder.matches(request.password(), login.getPasswordHash())) {
            throw new BadCredentialsException("Invalid email or password");
        }
        if (!user.isActive()) {
            throw ApiException.forbidden("ACCOUNT_INACTIVE", "This account has been deactivated");
        }
        return toAuthResponse(user, userRoleService.roleOf(email));
    }

    /**
     * @brief Genera la respuesta de autenticación con los datos del usuario y su token JWT.
     *
     * @param user usuario autenticado del que se obtendrán los datos.
     * @param role rol asignado al usuario que se incluirá en el token.
     * @return respuesta de autenticación con la información del usuario y su token JWT.
     */
    private AuthResponse toAuthResponse(User user, Role role) {
        String token = jwtService.generateToken(user, role);
        return new AuthResponse(token, user.getName(), user.getEmail(), user.getCountry(), role.name());
    }

    /**
     * @brief Normaliza un correo electrónico eliminando espacios y convirtiéndolo a minúsculas.
     *
     * @param email correo electrónico que será normalizado.
     * @return correo electrónico normalizado.
     */
    private String normalizeEmail(String email) {
        return EmailNormalizer.normalize(email);
    }
}
