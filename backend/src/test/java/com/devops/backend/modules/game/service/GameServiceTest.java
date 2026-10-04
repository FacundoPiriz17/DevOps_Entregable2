package com.devops.backend.modules.game.service;

import com.devops.backend.common.exception.ApiException;
import com.devops.backend.modules.game.dto.GameRequest;
import com.devops.backend.modules.game.entity.Game;
import com.devops.backend.modules.game.entity.GameStatus;
import com.devops.backend.modules.game.repository.CategoryRepository;
import com.devops.backend.modules.game.repository.GameImageRepository;
import com.devops.backend.modules.game.repository.GameRepository;
import com.devops.backend.modules.game.repository.ImageAssetRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class GameServiceTest {
    @Mock GameRepository gameRepository;
    @Mock CategoryRepository categoryRepository;
    @Mock GameImageRepository gameImageRepository;
    @Mock ImageAssetRepository imageAssetRepository;

    private GameService service() {
        return new GameService(gameRepository, categoryRepository, gameImageRepository, imageAssetRepository);
    }

    @Test
    void create_mapsAllFieldsFromNewSchema() {
        when(gameRepository.save(any(Game.class))).thenAnswer(inv -> inv.getArgument(0));

        var response = service().create(request("preventa", Set.of()), "admin@playhub.test");

        assertThat(response.name()).isEqualTo("Grand Theft Auto VI");
        assertThat(response.price()).isEqualByComparingTo("79.99");
        assertThat(response.status()).isEqualTo("preventa");
        assertThat(response.available()).isTrue();
        assertThat(response.registeredBy()).isEqualTo("admin@playhub.test");
    }

    @Test
    void update_replacesBusinessFieldsAndStatus() {
        Game game = game(GameStatus.PUBLICADO);
        when(gameRepository.findById(10L)).thenReturn(Optional.of(game));

        var response = service().update(10L, request("pausado", Set.of()));

        assertThat(response.status()).isEqualTo("pausado");
        assertThat(response.available()).isFalse();
        assertThat(game.getPrice()).isEqualByComparingTo("79.99");
    }

    @Test
    void update_unknownCategoryReturnsBadRequest() {
        when(gameRepository.findById(10L)).thenReturn(Optional.of(game(GameStatus.PUBLICADO)));
        when(categoryRepository.findAllById(Set.of(1L, 2L))).thenReturn(java.util.List.of());

        assertThatThrownBy(() -> service().update(10L, request("publicado", Set.of(1L, 2L))))
                .isInstanceOf(ApiException.class).hasMessageContaining("categories");
    }

    @Test
    void deactivate_mapsLogicalDeletionToRetirado() {
        Game game = game(GameStatus.PUBLICADO);
        when(gameRepository.findById(10L)).thenReturn(Optional.of(game));
        assertThat(service().deactivate(10L).status()).isEqualTo("retirado");
    }

    @Test
    void deactivate_alreadyRetiredReturnsConflict() {
        when(gameRepository.findById(10L)).thenReturn(Optional.of(game(GameStatus.RETIRADO)));
        assertThatThrownBy(() -> service().deactivate(10L)).isInstanceOf(ApiException.class);
    }

    @Test
    void get_unknownGameReturnsNotFound() {
        when(gameRepository.findById(99L)).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service().getById(99L)).isInstanceOf(ApiException.class);
    }

    private static GameRequest request(String status, Set<Long> categories) {
        return new GameRequest("Grand Theft Auto VI", "Mundo abierto", new BigDecimal("79.99"),
                LocalDate.of(2026, 11, 19), "Rockstar Games", status, categories);
    }

    private static Game game(GameStatus status) {
        return new Game("Game", "Description", new BigDecimal("10.00"), LocalDate.of(2025, 1, 1),
                "Studio", status, "admin@playhub.test");
    }
}
