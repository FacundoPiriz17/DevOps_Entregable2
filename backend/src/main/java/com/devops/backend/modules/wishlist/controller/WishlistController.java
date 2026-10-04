package com.devops.backend.modules.wishlist.controller;

/**
 * @file WishlistController.java
 * @brief Gestiona las operaciones relacionadas con la lista de videojuegos deseados del usuario.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.common.config.OpenApiConfig;
import com.devops.backend.common.security.CurrentUser;
import com.devops.backend.modules.wishlist.dto.WishlistItemResponse;
import com.devops.backend.modules.wishlist.service.WishlistService;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * @brief Expone los endpoints para consultar, añadir y eliminar videojuegos de la lista de deseados.
 *
 */
@RestController
@RequestMapping("/api/wishlist")
@Tag(name = "Wishlist", description = "Gestión de la lista personal de deseados")
@SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
public class WishlistController {
    private final WishlistService wishlistService;
    private final CurrentUser currentUser;
    public WishlistController(WishlistService wishlistService, CurrentUser currentUser) {
        this.wishlistService = wishlistService;
        this.currentUser = currentUser;
    }

    /**
     * @brief Obtiene los videojuegos que actualmente se encuentran en la lista de deseados del usuario.
     *
     * @param auth token de autenticación del usuario actual.
     * @return lista de videojuegos incluidos en la lista de deseados.
     */
    @GetMapping
    public List<WishlistItemResponse> list(JwtAuthenticationToken auth) {
        return wishlistService.list(currentUser.emailFrom(auth));
    }

    /**
     * @brief Añade un videojuego a la lista de deseados del usuario autenticado.
     *
     * @param gameId identificador del videojuego que se añadirá a la lista de deseados.
     * @param auth token de autenticación del usuario actual.
     * @return respuesta HTTP 201 con la información del videojuego añadido.
     */
    @PostMapping("/games/{gameId}")
    public ResponseEntity<WishlistItemResponse> add(@PathVariable Long gameId, JwtAuthenticationToken auth) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(wishlistService.add(currentUser.emailFrom(auth), gameId));
    }

    /**
     * @brief Elimina un videojuego de la lista de deseados del usuario autenticado.
     *
     * @param gameId identificador del videojuego que se eliminará de la lista de deseados.
     * @param auth token de autenticación del usuario actual.
     * @return respuesta HTTP 204 sin contenido.
     */
    @DeleteMapping("/games/{gameId}")
    public ResponseEntity<Void> remove(@PathVariable Long gameId, JwtAuthenticationToken auth) {
        wishlistService.remove(currentUser.emailFrom(auth), gameId);
        return ResponseEntity.noContent().build();
    }
}
