package com.devops.backend.modules.library.service;

/**
 * @file LibraryService.java
 * @brief Gestiona las operaciones relacionadas con la biblioteca personal de los usuarios.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.common.exception.ApiException;
import com.devops.backend.modules.game.entity.Game;
import com.devops.backend.modules.game.repository.GameRepository;
import com.devops.backend.modules.library.dto.LibraryEntryResponse;
import com.devops.backend.modules.library.entity.LibraryEntry;
import com.devops.backend.modules.library.repository.LibraryEntryRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * @brief Proporciona la lógica necesaria para gestionar la biblioteca y los juegos favoritos de los usuarios.
 *
 */
@Service
public class LibraryService {

    private final LibraryEntryRepository libraryEntryRepository;
    private final GameRepository gameRepository;

    public LibraryService(LibraryEntryRepository libraryEntryRepository, GameRepository gameRepository) {
        this.libraryEntryRepository = libraryEntryRepository;
        this.gameRepository = gameRepository;
    }

    /**
     * @brief Añade un videojuego disponible para compra a la biblioteca del usuario.
     *
     * @param userEmail correo electrónico del usuario propietario de la biblioteca.
     * @param gameId identificador del videojuego que se desea añadir.
     * @return información del videojuego añadido a la biblioteca.
     * @throws ApiException si el videojuego no existe, no está disponible para compra
     *                      o ya se encuentra en la biblioteca.
     */
    @Transactional
    public LibraryEntryResponse addToLibrary(String userEmail, Long gameId) {
        Game game = requirePurchasableGame(gameId);
        if (libraryEntryRepository.existsByIdUserEmailAndIdGameId(userEmail, gameId)) {
            throw ApiException.conflict("ALREADY_IN_LIBRARY", "Game is already in the user's library");
        }
        LibraryEntry entry = libraryEntryRepository.save(new LibraryEntry(userEmail, gameId));
        return LibraryEntryResponse.from(entry, game);
    }

    /**
     * @brief Obtiene todos los videojuegos de la biblioteca de un usuario.
     *
     * @param userEmail correo electrónico del usuario propietario de la biblioteca.
     * @return lista de videojuegos pertenecientes a la biblioteca del usuario.
     */
    @Transactional(readOnly = true)
    public List<LibraryEntryResponse> listLibrary(String userEmail) {
        List<LibraryEntry> entries = libraryEntryRepository.findByIdUserEmail(userEmail);
        Map<Long, Game> gamesById = gameRepository.findAllById(
                        entries.stream().map(entry -> entry.getId().getGameId()).toList())
                .stream().collect(Collectors.toMap(Game::getId, Function.identity()));
        return entries.stream()
                .filter(entry -> gamesById.containsKey(entry.getId().getGameId()))
                .map(entry -> LibraryEntryResponse.from(entry, gamesById.get(entry.getId().getGameId())))
                .toList();
    }

    /**
     * @brief Actualiza el estado de favorito de un videojuego de la biblioteca.
     *
     * @param userEmail correo electrónico del usuario propietario de la biblioteca.
     * @param gameId identificador del videojuego cuyo estado se desea actualizar.
     * @param favorite nuevo estado de favorito del videojuego.
     * @return información del videojuego con su nuevo estado de favorito.
     * @throws ApiException si el videojuego no pertenece a la biblioteca o no existe.
     */
    @Transactional
    public LibraryEntryResponse setFavorite(String userEmail, Long gameId, boolean favorite) {
        LibraryEntry entry = requireLibraryEntry(userEmail, gameId);
        entry.setFavorite(favorite);
        Game game = gameRepository.findById(gameId)
                .orElseThrow(() -> ApiException.notFound("GAME_NOT_FOUND", "Game does not exist"));
        return LibraryEntryResponse.from(entry, game);
    }

    /**
     * @brief Busca una entrada de biblioteca perteneciente a un usuario y videojuego.
     *
     * @param userEmail correo electrónico del usuario propietario de la biblioteca.
     * @param gameId identificador del videojuego que se desea buscar.
     * @return entrada de biblioteca correspondiente al usuario y videojuego.
     * @throws ApiException si el videojuego no pertenece a la biblioteca del usuario.
     */
    @Transactional(readOnly = true)
    public LibraryEntry requireLibraryEntry(String userEmail, Long gameId) {
        return libraryEntryRepository.findByIdUserEmailAndIdGameId(userEmail, gameId)
                .orElseThrow(() -> ApiException.forbidden(
                        "GAME_NOT_IN_LIBRARY", "Game is not available in your library"));
    }

    /**
     * @brief Busca un videojuego y comprueba que esté disponible para su compra.
     *
     * @param gameId identificador del videojuego que se desea comprobar.
     * @return videojuego disponible para la compra.
     * @throws ApiException si el videojuego no existe o no está disponible para su compra.
     */
    private Game requirePurchasableGame(Long gameId) {
        Game game = gameRepository.findById(gameId)
                .orElseThrow(() -> ApiException.notFound("GAME_NOT_FOUND", "Game does not exist"));
        if (!game.getStatus().isPurchasable()) {
            throw ApiException.conflict("GAME_NOT_AVAILABLE", "Game is not available for purchase");
        }
        return game;
    }
}
