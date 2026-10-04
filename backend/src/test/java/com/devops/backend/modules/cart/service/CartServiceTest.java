package com.devops.backend.modules.cart.service;

import com.devops.backend.common.exception.ApiException;
import com.devops.backend.modules.cart.entity.CartItem;
import com.devops.backend.modules.cart.repository.CartItemRepository;
import com.devops.backend.modules.game.entity.Game;
import com.devops.backend.modules.game.entity.GameStatus;
import com.devops.backend.modules.game.repository.GameRepository;
import com.devops.backend.modules.library.repository.LibraryEntryRepository;
import com.devops.backend.modules.library.service.LibraryService;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class CartServiceTest {
    private final CartItemRepository cart = mock(CartItemRepository.class);
    private final GameRepository games = mock(GameRepository.class);
    private final LibraryEntryRepository library = mock(LibraryEntryRepository.class);
    private final LibraryService libraryService = mock(LibraryService.class);
    private final CartService service = new CartService(cart, games, library, libraryService);

    @Test
    void add_purchasableGameCreatesCartItem() {
        when(games.findById(10L)).thenReturn(Optional.of(game(GameStatus.PUBLICADO)));
        when(cart.existsByIdUserEmailAndIdGameId("user@test", 10L)).thenReturn(false);
        assertThat(service.add("user@test", 10L).name()).isEqualTo("Hades");
        verify(cart).save(any(CartItem.class));
    }

    @Test
    void add_ownedGameReturnsConflict() {
        when(games.findById(10L)).thenReturn(Optional.of(game(GameStatus.PUBLICADO)));
        when(library.existsByIdUserEmailAndIdGameId("user@test", 10L)).thenReturn(true);
        assertThatThrownBy(() -> service.add("user@test", 10L)).isInstanceOf(ApiException.class);
    }

    @Test
    void checkout_emptyCartReturnsBadRequest() {
        when(cart.findByIdUserEmail("user@test")).thenReturn(List.of());
        assertThatThrownBy(() -> service.checkout("user@test")).isInstanceOf(ApiException.class);
    }

    private static Game game(GameStatus status) {
        return new Game("Hades", "Roguelike", new BigDecimal("24.99"), LocalDate.of(2020, 9, 17),
                "Supergiant", status, "admin@test");
    }
}
