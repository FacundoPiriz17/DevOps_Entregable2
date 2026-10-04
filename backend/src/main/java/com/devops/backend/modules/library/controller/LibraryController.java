package com.devops.backend.modules.library.controller;

/**
 * @file LibraryController.java
 * @brief Gestiona las operaciones relacionadas con la biblioteca personal de los usuarios.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.common.config.OpenApiConfig;
import com.devops.backend.common.security.CurrentUser;
import com.devops.backend.modules.library.dto.LibraryEntryResponse;
import com.devops.backend.modules.library.dto.FavoriteRequest;
import com.devops.backend.modules.library.service.LibraryService;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * @brief Expone los endpoints para gestionar la biblioteca personal y los juegos favoritos del usuario.
 *
 */
@RestController
@RequestMapping("/api/library")
@Tag(name = "Library", description = "Gestión de la biblioteca personal")
@SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
public class LibraryController {

    private final LibraryService libraryService;
    private final CurrentUser currentUser;

    public LibraryController(LibraryService libraryService, CurrentUser currentUser) {
        this.libraryService = libraryService;
        this.currentUser = currentUser;
    }

    /**
     * @brief Añade un videojuego a la biblioteca del usuario autenticado.
     *
     * @param gameId identificador del videojuego que se desea añadir.
     * @param auth token de autenticación del usuario actual.
     * @return respuesta HTTP 201 con la información del juego añadido a la biblioteca.
     */
    @PostMapping("/games/{gameId}")
    public ResponseEntity<LibraryEntryResponse> addGame(@PathVariable Long gameId, JwtAuthenticationToken auth) {
        LibraryEntryResponse response = libraryService.addToLibrary(currentUser.emailFrom(auth), gameId);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    /**
     * @brief Obtiene todos los videojuegos de la biblioteca del usuario autenticado.
     *
     * @param auth token de autenticación del usuario actual.
     * @return lista de videojuegos pertenecientes a la biblioteca del usuario.
     */
    @GetMapping
    public List<LibraryEntryResponse> listLibrary(JwtAuthenticationToken auth) {
        return libraryService.listLibrary(currentUser.emailFrom(auth));
    }

    /**
     * @brief Actualiza el estado de favorito de un videojuego de la biblioteca.
     *
     * @param gameId identificador del videojuego cuyo estado de favorito se desea actualizar.
     * @param request datos que indican si el videojuego debe marcarse como favorito.
     * @param auth token de autenticación del usuario actual.
     * @return información del videojuego con su nuevo estado de favorito.
     */
    @PatchMapping("/games/{gameId}/favorite")
    public LibraryEntryResponse setFavorite(@PathVariable Long gameId,
                                            @Valid @RequestBody FavoriteRequest request,
                                            JwtAuthenticationToken auth) {
        return libraryService.setFavorite(currentUser.emailFrom(auth), gameId, request.favorite());
    }
}