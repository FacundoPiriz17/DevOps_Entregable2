package com.devops.backend.modules.user.entity;

/**
 * @file User.java
 * @brief Representa un usuario de la aplicación almacenado en la base de datos.
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

import java.time.LocalDate;

/**
 * @brief Entidad que representa la información principal y el estado de un usuario.
 *
 */
@Entity
@Table(name = "usuario")
public class User {

    @Id
    @Column(name = "email", nullable = false)
    private String email;

    @Column(name = "nombre", nullable = false)
    private String name;

    @Column(name = "pais", nullable = false)
    private String country;

    @Column(name = "activo", nullable = false)
    private boolean active = true;

    @Column(name = "fecha_registro", nullable = false)
    private LocalDate registeredAt = LocalDate.now();

    protected User() {
    }

    public User(String name, String email, String country) {
        this.name = name;
        this.email = email;
        this.country = country;
    }

    /**
     * @brief Obtiene el correo electrónico del usuario.
     *
     * @return correo electrónico del usuario.
     */
    public String getEmail() { return email; }

    /**
     * @brief Obtiene el nombre del usuario.
     *
     * @return nombre del usuario.
     */
    public String getName() { return name; }

    /**
     * @brief Obtiene el país del usuario.
     *
     * @return país del usuario.
     */
    public String getCountry() { return country; }

    /**
     * @brief Comprueba si el usuario está activo.
     *
     * @return true si el usuario está activo; false en caso contrario.
     */
    public boolean isActive() { return active; }

    /**
     * @brief Actualiza el estado de actividad del usuario.
     *
     * @param active nuevo estado de actividad del usuario.
     * @return no devuelve ningún valor.
     */
    public void setActive(boolean active) { this.active = active; }

    /**
     * @brief Obtiene la fecha de registro del usuario.
     *
     * @return fecha de registro del usuario.
     */
    public LocalDate getRegisteredAt() { return registeredAt; }
}
