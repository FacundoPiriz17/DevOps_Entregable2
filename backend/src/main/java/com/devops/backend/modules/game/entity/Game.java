package com.devops.backend.modules.game.entity;

/**
 * @file Game.java
 * @brief Representa un videojuego almacenado en la base de datos.
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
import jakarta.persistence.JoinColumn;
import jakarta.persistence.JoinTable;
import jakarta.persistence.ManyToMany;
import jakarta.persistence.Table;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.LinkedHashSet;
import java.util.Set;

/**
 * @brief Entidad que representa un videojuego y la información asociada a sus categorías.
 *
 */
@Entity
@Table(name = "juego")
public class Game {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "identificador")
    private Long id;

    @Column(name = "nombre", nullable = false)
    private String name;

    @Column(name = "descripcion", nullable = false)
    private String description;

    @Column(name = "precio", nullable = false, precision = 10, scale = 2)
    private BigDecimal price;

    @Column(name = "fecha_lanzamiento", nullable = false)
    private LocalDate releaseDate;

    @Column(name = "estudio", nullable = false)
    private String studio;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(name = "estado", nullable = false, columnDefinition = "estado_juego")
    private GameStatus status = GameStatus.PUBLICADO;

    @Column(name = "admin_registra", nullable = false)
    private String registeredByAdminEmail;

    @Column(name = "fecha_registro", nullable = false)
    private LocalDate registeredAt = LocalDate.now();

    @ManyToMany
    @JoinTable(name = "juego_categoria",
            joinColumns = @JoinColumn(name = "identificador_juego"),
            inverseJoinColumns = @JoinColumn(name = "identificador_categoria"))
    private Set<Category> categories = new LinkedHashSet<>();

    protected Game() {
    }

    public Game(String name, String description, BigDecimal price, LocalDate releaseDate,
                String studio, GameStatus status, String registeredByAdminEmail) {
        this.name = name;
        this.description = description;
        this.price = price;
        this.releaseDate = releaseDate;
        this.studio = studio;
        this.status = status;
        this.registeredByAdminEmail = registeredByAdminEmail;
    }

    /**
     * @brief Obtiene el identificador del videojuego.
     *
     * @return identificador del videojuego.
     */
    public Long getId() { return id; }

    /**
     * @brief Obtiene el nombre del videojuego.
     *
     * @return nombre del videojuego.
     */
    public String getName() { return name; }

    /**
     * @brief Actualiza el nombre del videojuego.
     *
     * @param name nuevo nombre del videojuego.
     * @return no devuelve ningún valor.
     */
    public void setName(String name) { this.name = name; }

    /**
     * @brief Obtiene la descripción del videojuego.
     *
     * @return descripción del videojuego.
     */
    public String getDescription() { return description; }

    /**
     * @brief Actualiza la descripción del videojuego.
     *
     * @param description nueva descripción del videojuego.
     * @return no devuelve ningún valor.
     */
    public void setDescription(String description) { this.description = description; }

    /**
     * @brief Obtiene el precio del videojuego.
     *
     * @return precio del videojuego.
     */
    public BigDecimal getPrice() { return price; }

    /**
     * @brief Actualiza el precio del videojuego.
     *
     * @param price nuevo precio del videojuego.
     * @return no devuelve ningún valor.
     */
    public void setPrice(BigDecimal price) { this.price = price; }

    /**
     * @brief Obtiene la fecha de lanzamiento del videojuego.
     *
     * @return fecha de lanzamiento del videojuego.
     */
    public LocalDate getReleaseDate() { return releaseDate; }

    /**
     * @brief Actualiza la fecha de lanzamiento del videojuego.
     *
     * @param releaseDate nueva fecha de lanzamiento del videojuego.
     * @return no devuelve ningún valor.
     */
    public void setReleaseDate(LocalDate releaseDate) { this.releaseDate = releaseDate; }

    /**
     * @brief Obtiene el estudio desarrollador del videojuego.
     *
     * @return nombre del estudio desarrollador.
     */
    public String getStudio() { return studio; }

    /**
     * @brief Actualiza el estudio desarrollador del videojuego.
     *
     * @param studio nuevo nombre del estudio desarrollador.
     * @return no devuelve ningún valor.
     */
    public void setStudio(String studio) { this.studio = studio; }

    /**
     * @brief Obtiene el estado actual del videojuego.
     *
     * @return estado del videojuego.
     */
    public GameStatus getStatus() { return status; }

    /**
     * @brief Actualiza el estado del videojuego.
     *
     * @param status nuevo estado del videojuego.
     * @return no devuelve ningún valor.
     */
    public void setStatus(GameStatus status) { this.status = status; }

    /**
     * @brief Obtiene el correo electrónico del administrador que registró el videojuego.
     *
     * @return correo electrónico del administrador que registró el videojuego.
     */
    public String getRegisteredByAdminEmail() { return registeredByAdminEmail; }

    /**
     * @brief Obtiene la fecha en la que se registró el videojuego.
     *
     * @return fecha de registro del videojuego.
     */
    public LocalDate getRegisteredAt() { return registeredAt; }

    /**
     * @brief Obtiene las categorías asociadas al videojuego.
     *
     * @return conjunto de categorías asociadas al videojuego.
     */
    public Set<Category> getCategories() { return categories; }

    /**
     * @brief Reemplaza las categorías asociadas al videojuego.
     *
     * @param categories conjunto de nuevas categorías asociadas al videojuego.
     * @return no devuelve ningún valor.
     */
    public void replaceCategories(Set<Category> categories) {
        this.categories.clear();
        this.categories.addAll(categories);
    }
}