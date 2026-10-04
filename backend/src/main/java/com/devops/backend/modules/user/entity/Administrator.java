package com.devops.backend.modules.user.entity;

/**
 * @file Administrator.java
 * @brief Representa un administrador de la aplicación almacenado en la base de datos.
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
 * @brief Entidad que representa un administrador identificado mediante su correo electrónico.
 *
 */
@Entity
@Table(name = "administrador")
public class Administrator {

    @Id
    @Column(name = "email_administrador", nullable = false)
    private String email;

    protected Administrator() {
    }

    public Administrator(String email) { this.email = email; }

    /**
     * @brief Obtiene el correo electrónico del administrador.
     *
     * @return correo electrónico del administrador.
     */
    public String getEmail() { return email; }
}
