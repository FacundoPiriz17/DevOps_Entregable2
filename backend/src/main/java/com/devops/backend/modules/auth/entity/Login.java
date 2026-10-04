package com.devops.backend.modules.auth.entity;

/**
 * @file Login.java
 * @brief Representa las credenciales de acceso almacenadas para un usuario.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * @brief Entidad que almacena el correo electrónico y la contraseña cifrada de un usuario.
 *
 */
@Entity
@Table(name = "login")
public class Login {

    @Id
    @Column(name = "email", nullable = false)
    private String email;

    @Column(name = "contrasenia", nullable = false)
    private String passwordHash;

    protected Login() {
    }

    public Login(String email, String passwordHash) {
        this.email = email;
        this.passwordHash = passwordHash;
    }

    /**
     * @brief Obtiene el correo electrónico asociado a las credenciales.
     *
     * @return correo electrónico del usuario.
     */
    public String getEmail() { return email; }

    /**
     * @brief Obtiene la contraseña cifrada del usuario.
     *
     * @return contraseña cifrada almacenada.
     */
    public String getPasswordHash() { return passwordHash; }
}