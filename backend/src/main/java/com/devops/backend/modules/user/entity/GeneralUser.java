package com.devops.backend.modules.user.entity;

/**
 * @file GeneralUser.java
 * @brief Representa un usuario general de la aplicación almacenado en la base de datos.
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
 * @brief Entidad que representa un usuario general identificado mediante su correo electrónico.
 *
 */
@Entity
@Table(name = "general")
public class GeneralUser {

    @Id
    @Column(name = "email_general", nullable = false)
    private String email;

    protected GeneralUser() {
    }

    public GeneralUser(String email) { this.email = email; }

    /**
     * @brief Obtiene el correo electrónico del usuario general.
     *
     * @return correo electrónico del usuario.
     */
    public String getEmail() { return email; }
}
