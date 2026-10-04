package com.devops.backend.modules.library.service;

import com.devops.backend.common.exception.ApiException;
import com.devops.backend.modules.game.entity.Game;
import com.devops.backend.modules.game.entity.GameStatus;
import com.devops.backend.modules.game.repository.GameRepository;
import com.devops.backend.modules.library.entity.LibraryEntry;
import com.devops.backend.modules.library.repository.LibraryEntryRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class LibraryServiceTest {
    @Mock LibraryEntryRepository repository;
    @Mock GameRepository gameRepository;

    private LibraryService service() { return new LibraryService(repository, gameRepository); }

    @Test
    void add_publishedGameCreatesPurchase() {
        Game game = game(GameStatus.PUBLICADO);
        when(gameRepository.findById(10L)).thenReturn(Optional.of(game));
        when(repository.existsByIdUserEmailAndIdGameId("user@test", 10L)).thenReturn(false);
        when(repository.save(any(LibraryEntry.class))).thenAnswer(inv -> inv.getArgument(0));

        var response = service().addToLibrary("user@test", 10L);
        assertThat(response.name()).isEqualTo("Hades");
        assertThat(response.favorite()).isFalse();
    }

    @Test
    void add_pausedGameReturnsConflict() {
        when(gameRepository.findById(10L)).thenReturn(Optional.of(game(GameStatus.PAUSADO)));
        assertThatThrownBy(() -> service().addToLibrary("user@test", 10L))
                .isInstanceOf(ApiException.class).hasMessageContaining("not available");
    }

    @Test
    void add_duplicateReturnsConflict() {
        when(gameRepository.findById(10L)).thenReturn(Optional.of(game(GameStatus.PUBLICADO)));
        when(repository.existsByIdUserEmailAndIdGameId("user@test", 10L)).thenReturn(true);
        assertThatThrownBy(() -> service().addToLibrary("user@test", 10L))
                .isInstanceOf(ApiException.class);
    }

    @Test
    void list_mapsEntriesToGames() {
        LibraryEntry entry = new LibraryEntry("user@test", 10L);
        Game game = game(GameStatus.PUBLICADO);
        ReflectionTestUtils.setField(game, "id", 10L);
        when(repository.findByIdUserEmail("user@test")).thenReturn(List.of(entry));
        when(gameRepository.findAllById(List.of(10L))).thenReturn(List.of(game));
        assertThat(service().listLibrary("user@test")).hasSize(1);
    }

    @Test
    void setFavorite_updatesExistingEntry() {
        LibraryEntry entry = new LibraryEntry("user@test", 10L);
        when(repository.findByIdUserEmailAndIdGameId("user@test", 10L)).thenReturn(Optional.of(entry));
        when(gameRepository.findById(10L)).thenReturn(Optional.of(game(GameStatus.PUBLICADO)));
        assertThat(service().setFavorite("user@test", 10L, true).favorite()).isTrue();
    }

    private static Game game(GameStatus status) {
        return new Game("Hades", "Roguelike", new BigDecimal("24.99"), LocalDate.of(2020, 9, 17),
                "Supergiant Games", status, "admin@test");
    }
}
