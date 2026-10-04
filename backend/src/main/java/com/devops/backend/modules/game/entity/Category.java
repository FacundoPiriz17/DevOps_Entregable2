package com.devops.backend.modules.game.entity;

/**
 * @file Category.java
 * @brief Representa una categoría de videojuego almacenada en la base de datos.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

/**
 * @brief Entidad que representa una categoría asociada a uno o varios videojuegos.
 *
 */
@Entity
@Table(name = "categoria")
public class Category {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "identificador")
    private Long id;

    @Column(name = "nombre", nullable = false)
    private String name;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(name = "tipo", nullable = false, columnDefinition = "tipo_categoria")
    private CategoryType type;

    protected Category() {
    }

    public Category(String name, CategoryType type) {
        this.name = name;
        this.type = type;
    }

    /**
     * @brief Obtiene el identificador de la categoría.
     *
     * @return identificador de la categoría.
     */
    public Long getId() { return id; }

    /**
     * @brief Obtiene el nombre de la categoría.
     *
     * @return nombre de la categoría.
     */
    public String getName() { return name; }

    /**
     * @brief Obtiene el tipo de la categoría.
     *
     * @return tipo de la categoría.
     */
    public CategoryType getType() { return type; }
}