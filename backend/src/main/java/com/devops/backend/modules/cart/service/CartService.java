package com.devops.backend.modules.cart.service;

/**
 * @file CartService.java
 * @brief Gestiona las operaciones relacionadas con el carrito de compras de los usuarios.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.common.exception.ApiException;
import com.devops.backend.modules.cart.dto.CartItemResponse;
import com.devops.backend.modules.cart.entity.CartItem;
import com.devops.backend.modules.cart.entity.CartItemId;
import com.devops.backend.modules.cart.repository.CartItemRepository;
import com.devops.backend.modules.game.entity.Game;
import com.devops.backend.modules.game.repository.GameRepository;
import com.devops.backend.modules.library.dto.LibraryEntryResponse;
import com.devops.backend.modules.library.repository.LibraryEntryRepository;
import com.devops.backend.modules.library.service.LibraryService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * @brief Proporciona la lógica necesaria para añadir, consultar, eliminar y comprar juegos del carrito.
 *
 */
@Service
public class CartService {
    private final CartItemRepository cartItemRepository;
    private final GameRepository gameRepository;
    private final LibraryEntryRepository libraryEntryRepository;
    private final LibraryService libraryService;

    public CartService(CartItemRepository cartItemRepository,
                       GameRepository gameRepository,
                       LibraryEntryRepository libraryEntryRepository,
                       LibraryService libraryService) {
        this.cartItemRepository = cartItemRepository;
        this.gameRepository = gameRepository;
        this.libraryEntryRepository = libraryEntryRepository;
        this.libraryService = libraryService;
    }

    /**
     * @brief Añade un juego disponible para compra al carrito del usuario.
     *
     * @param userEmail correo electrónico del usuario propietario del carrito.
     * @param gameId identificador del juego que se desea añadir.
     * @return información del juego añadido al carrito.
     * @throws ApiException si el juego no existe, no está disponible para compra,
     *                      ya está en la biblioteca o ya está en el carrito.
     */
    @Transactional
    public CartItemResponse add(String userEmail, Long gameId) {
        Game game = requirePurchasableGame(gameId);
        if (libraryEntryRepository.existsByIdUserEmailAndIdGameId(userEmail, gameId)) {
            throw ApiException.conflict("ALREADY_IN_LIBRARY", "Game is already in the user's library");
        }
        if (cartItemRepository.existsByIdUserEmailAndIdGameId(userEmail, gameId)) {
            throw ApiException.conflict("ALREADY_IN_CART", "Game is already in the cart");
        }
        cartItemRepository.save(new CartItem(userEmail, gameId));
        return CartItemResponse.from(game);
    }

    /**
     * @brief Obtiene todos los juegos que se encuentran en el carrito del usuario.
     *
     * @param userEmail correo electrónico del usuario propietario del carrito.
     * @return lista de juegos incluidos en el carrito.
     */
    @Transactional(readOnly = true)
    public List<CartItemResponse> list(String userEmail) {
        List<CartItem> items = cartItemRepository.findByIdUserEmail(userEmail);
        Map<Long, Game> games = gameRepository.findAllById(
                        items.stream().map(item -> item.getId().getGameId()).toList())
                .stream().collect(Collectors.toMap(Game::getId, Function.identity()));
        return items.stream().map(item -> games.get(item.getId().getGameId()))
                .filter(java.util.Objects::nonNull).map(CartItemResponse::from).toList();
    }

    /**
     * @brief Elimina un juego del carrito del usuario.
     *
     * @param userEmail correo electrónico del usuario propietario del carrito.
     * @param gameId identificador del juego que se desea eliminar.
     * @return no devuelve ningún valor.
     * @throws ApiException si el juego no se encuentra en el carrito.
     */
    @Transactional
    public void remove(String userEmail, Long gameId) {
        CartItemId id = new CartItemId(gameId, userEmail);
        if (!cartItemRepository.existsById(id)) {
            throw ApiException.notFound("CART_ITEM_NOT_FOUND", "Game is not in the cart");
        }
        cartItemRepository.deleteById(id);
    }

    /**
     * @brief Procesa la compra de todos los juegos incluidos en el carrito y los añade a la biblioteca del usuario.
     *
     * @param userEmail correo electrónico del usuario que realiza la compra.
     * @return lista de juegos adquiridos e incorporados a la biblioteca.
     * @throws ApiException si el carrito está vacío o alguno de los juegos no puede añadirse a la biblioteca.
     */
    @Transactional
    public List<LibraryEntryResponse> checkout(String userEmail) {
        List<CartItem> items = cartItemRepository.findByIdUserEmail(userEmail);
        if (items.isEmpty()) throw ApiException.badRequest("EMPTY_CART", "The cart is empty");
        List<LibraryEntryResponse> purchased = items.stream()
                .map(item -> libraryService.addToLibrary(userEmail, item.getId().getGameId()))
                .toList();
        cartItemRepository.deleteAll(items);
        return purchased;
    }

    /**
     * @brief Busca un juego y comprueba que esté disponible para su compra.
     *
     * @param gameId identificador del juego que se desea comprobar.
     * @return juego disponible para la compra.
     * @throws ApiException si el juego no existe o no está disponible para su compra.
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
