package com.devops.backend.modules.wishlist.service;

import com.devops.backend.common.exception.ApiException;
import com.devops.backend.modules.game.entity.Game;
import com.devops.backend.modules.game.entity.GameStatus;
import com.devops.backend.modules.game.repository.GameRepository;
import com.devops.backend.modules.library.repository.LibraryEntryRepository;
import com.devops.backend.modules.wishlist.entity.WishlistItem;
import com.devops.backend.modules.wishlist.repository.WishlistItemRepository;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class WishlistServiceTest {
    private final WishlistItemRepository wishlist = mock(WishlistItemRepository.class);
    private final LibraryEntryRepository library = mock(LibraryEntryRepository.class);
    private final GameRepository games = mock(GameRepository.class);
    private final WishlistService service = new WishlistService(wishlist, library, games);

    @Test
    void add_availableGameCreatesWishlistItem() {
        when(games.findById(10L)).thenReturn(Optional.of(game(GameStatus.PREVENTA)));
        when(wishlist.save(any(WishlistItem.class))).thenAnswer(inv -> inv.getArgument(0));
        assertThat(service.add("user@test", 10L).status()).isEqualTo("preventa");
        verify(wishlist).save(any(WishlistItem.class));
    }

    @Test
    void add_retiredGameReturnsConflict() {
        when(games.findById(10L)).thenReturn(Optional.of(game(GameStatus.RETIRADO)));
        assertThatThrownBy(() -> service.add("user@test", 10L)).isInstanceOf(ApiException.class);
    }

    private static Game game(GameStatus status) {
        return new Game("GTA VI", "Open world", new BigDecimal("79.99"), LocalDate.of(2026, 11, 19),
                "Rockstar", status, "admin@test");
    }
}
