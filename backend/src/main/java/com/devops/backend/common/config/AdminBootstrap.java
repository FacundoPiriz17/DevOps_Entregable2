/**
 * @file AdminBootstrap.java
 * @brief Inicializa el administrador principal de la aplicación.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

package com.devops.backend.common.config;

import com.devops.backend.common.util.EmailNormalizer;
import com.devops.backend.modules.auth.entity.Login;
import com.devops.backend.modules.auth.repository.LoginRepository;
import com.devops.backend.modules.user.entity.Administrator;
import com.devops.backend.modules.user.entity.User;
import com.devops.backend.modules.user.repository.AdministratorRepository;
import com.devops.backend.modules.user.repository.UserRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * @brief Crea el administrador inicial si todavía no existe.
 *
 */
@Component
public class AdminBootstrap implements CommandLineRunner {

    private final UserRepository userRepository;
    private final LoginRepository loginRepository;
    private final AdministratorRepository administratorRepository;
    private final PasswordEncoder passwordEncoder;
    private final String adminEmail;
    private final String adminPassword;
    private final String adminCountry;

    public AdminBootstrap(UserRepository userRepository,
                          LoginRepository loginRepository,
                          AdministratorRepository administratorRepository,
                          PasswordEncoder passwordEncoder,
                          @Value("${admin.bootstrap.email:admin@devops.local}") String adminEmail,
                          @Value("${admin.bootstrap.password:ChangeMe123!}") String adminPassword,
                          @Value("${admin.bootstrap.country:Uruguay}") String adminCountry) {
        this.userRepository = userRepository;
        this.loginRepository = loginRepository;
        this.administratorRepository = administratorRepository;
        this.passwordEncoder = passwordEncoder;
        this.adminEmail = EmailNormalizer.normalize(adminEmail);
        this.adminPassword = adminPassword;
        this.adminCountry = adminCountry;
    }

    
    /**
     * @brief Inicializa el administrador principal si todavía no existe.
     * 
     * @param args argumentos recibidos al iniciar la aplicación.
     * @return no devuelve ningún valor.
     */
    @Override
    @Transactional
    public void run(String... args) {
        if (userRepository.existsById(adminEmail)) return;
        userRepository.save(new User("Admin", adminEmail, adminCountry));
        loginRepository.save(new Login(adminEmail, passwordEncoder.encode(adminPassword)));
        administratorRepository.save(new Administrator(adminEmail));
    }
}
