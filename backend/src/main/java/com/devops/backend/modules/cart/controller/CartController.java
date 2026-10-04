package com.devops.backend.modules.cart.controller;

/**
 * @file CartController.java
 * @brief Gestiona las operaciones relacionadas con el carrito de compras del usuario.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.common.config.OpenApiConfig;
import com.devops.backend.common.security.CurrentUser;
import com.devops.backend.modules.cart.dto.CartItemResponse;
import com.devops.backend.modules.cart.service.CartService;
import com.devops.backend.modules.library.dto.LibraryEntryResponse;
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
 * @brief Expone los endpoints para consultar, modificar y comprar los juegos del carrito.
 *
 */
@RestController
@RequestMapping("/api/cart")
@Tag(name = "Cart", description = "Gestión del carrito y compra de sus juegos")
@SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
public class CartController {
    private final CartService cartService;
    private final CurrentUser currentUser;

    public CartController(CartService cartService, CurrentUser currentUser) {
        this.cartService = cartService;
        this.currentUser = currentUser;
    }

    /**
     * @brief Obtiene los juegos que actualmente se encuentran en el carrito del usuario.
     *
     * @param auth token de autenticación del usuario actual.
     * @return lista de juegos añadidos al carrito.
     */
    @GetMapping
    public List<CartItemResponse> list(JwtAuthenticationToken auth) {
        return cartService.list(currentUser.emailFrom(auth));
    }

    /**
     * @brief Añade un juego al carrito del usuario autenticado.
     *
     * @param gameId identificador del juego que se añadirá al carrito.
     * @param auth token de autenticación del usuario actual.
     * @return respuesta HTTP 201 con la información del juego añadido al carrito.
     */
    @PostMapping("/games/{gameId}")
    public ResponseEntity<CartItemResponse> add(@PathVariable Long gameId, JwtAuthenticationToken auth) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(cartService.add(currentUser.emailFrom(auth), gameId));
    }

    /**
     * @brief Elimina un juego del carrito del usuario autenticado.
     *
     * @param gameId identificador del juego que se eliminará del carrito.
     * @param auth token de autenticación del usuario actual.
     * @return respuesta HTTP 204 sin contenido.
     */
    @DeleteMapping("/games/{gameId}")
    public ResponseEntity<Void> remove(@PathVariable Long gameId, JwtAuthenticationToken auth) {
        cartService.remove(currentUser.emailFrom(auth), gameId);
        return ResponseEntity.noContent().build();
    }

    /**
     * @brief Procesa la compra de los juegos incluidos en el carrito.
     *
     * @param auth token de autenticación del usuario actual.
     * @return lista de juegos incorporados a la biblioteca del usuario tras la compra.
     */
    @PostMapping("/checkout")
    public List<LibraryEntryResponse> checkout(JwtAuthenticationToken auth) {
        return cartService.checkout(currentUser.emailFrom(auth));
    }
}