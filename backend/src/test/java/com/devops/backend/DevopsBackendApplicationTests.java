package com.devops.backend;

import com.devops.backend.modules.cart.entity.CartItem;
import com.devops.backend.modules.cart.repository.CartItemRepository;
import com.devops.backend.modules.game.entity.Category;
import com.devops.backend.modules.game.entity.CategoryType;
import com.devops.backend.modules.game.entity.Game;
import com.devops.backend.modules.game.entity.GameImage;
import com.devops.backend.modules.game.entity.GameStatus;
import com.devops.backend.modules.game.entity.ImageAsset;
import com.devops.backend.modules.game.entity.ImageType;
import com.devops.backend.modules.game.repository.CategoryRepository;
import com.devops.backend.modules.game.repository.GameImageRepository;
import com.devops.backend.modules.game.repository.GameRepository;
import com.devops.backend.modules.game.repository.ImageAssetRepository;
import com.devops.backend.modules.library.entity.LibraryEntry;
import com.devops.backend.modules.library.repository.LibraryEntryRepository;
import com.devops.backend.modules.user.entity.GeneralUser;
import com.devops.backend.modules.user.entity.User;
import com.devops.backend.modules.user.repository.GeneralUserRepository;
import com.devops.backend.modules.user.repository.UserRepository;
import com.devops.backend.modules.wishlist.entity.WishlistItem;
import com.devops.backend.modules.wishlist.repository.WishlistItemRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.jdbc.core.JdbcTemplate;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

@Testcontainers
@SpringBootTest
class DevopsBackendApplicationTests {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:17-alpine")
            .withDatabaseName("playhub_test")
            .withUsername("playhub")
            .withPassword("playhub");

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired private UserRepository userRepository;
    @Autowired private GeneralUserRepository generalUserRepository;
    @Autowired private CategoryRepository categoryRepository;
    @Autowired private GameRepository gameRepository;
    @Autowired private ImageAssetRepository imageAssetRepository;
    @Autowired private GameImageRepository gameImageRepository;
    @Autowired private LibraryEntryRepository libraryEntryRepository;
    @Autowired private CartItemRepository cartItemRepository;
    @Autowired private WishlistItemRepository wishlistItemRepository;

    @Test
    void contextLoads() {
    }

    @Test
    void flywayCreatesTheSchemaAndCompleteArtwork() {
        Long migrations = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM flyway_schema_history WHERE version IN ('1', '2', '3') AND success = TRUE",
                Long.class);
        Long domainTables = jdbcTemplate.queryForObject("""
                SELECT COUNT(*) FROM information_schema.tables
                WHERE table_schema = 'public'
                  AND table_name IN ('usuario', 'login', 'general', 'administrador', 'juego', 'imagen',
                                     'juego_imagen', 'categoria', 'juego_categoria', 'biblioteca',
                                     'carrito', 'deseados')
                """, Long.class);
        Long enumTypes = jdbcTemplate.queryForObject("""
                SELECT COUNT(*) FROM pg_type
                WHERE typname IN ('estado_juego', 'tipo_imagen', 'tipo_categoria')
                """, Long.class);
        Long demoGames = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM juego", Long.class);
        Long gamesWithCompleteArtwork = jdbcTemplate.queryForObject("""
                SELECT COUNT(*)
                FROM (
                    SELECT j.identificador
                    FROM juego j
                    JOIN juego_imagen ji ON ji.identificador_juego = j.identificador
                    WHERE ji.tipo IN ('portada', 'banner')
                    GROUP BY j.identificador
                    HAVING COUNT(DISTINCT ji.tipo) = 2
                ) complete_artwork
                """, Long.class);

        assertThat(migrations).isEqualTo(3L);
        assertThat(domainTables).isEqualTo(12L);
        assertThat(enumTypes).isEqualTo(3L);
        assertThat(demoGames).isEqualTo(12L);
        assertThat(gamesWithCompleteArtwork).isEqualTo(12L);
    }

    @Test
    @Transactional
    void repositoriesPersistEnumsRelationshipsAndCompositeKeys() {
        String email = "integration@playhub.test";
        userRepository.save(new User("Integration", email, "Uruguay"));
        generalUserRepository.save(new GeneralUser(email));

        Category category = categoryRepository.save(new Category("Integración", CategoryType.ETIQUETA));
        Game game = new Game("Integration Game", "Repository validation", new BigDecimal("19.99"),
                LocalDate.of(2026, 1, 1), "PlayHub", GameStatus.PREVENTA, "admin@devops.local");
        game.replaceCategories(Set.of(category));
        game = gameRepository.saveAndFlush(game);

        ImageAsset image = imageAssetRepository.saveAndFlush(new ImageAsset("https://img.test/game.jpg", "Cover"));
        gameImageRepository.saveAndFlush(new GameImage(game.getId(), image.getId(), ImageType.PORTADA));
        libraryEntryRepository.saveAndFlush(new LibraryEntry(email, game.getId()));
        cartItemRepository.saveAndFlush(new CartItem(email, game.getId()));
        wishlistItemRepository.saveAndFlush(new WishlistItem(email, game.getId()));

        assertThat(gameRepository.findById(game.getId())).get()
                .extracting(Game::getStatus).isEqualTo(GameStatus.PREVENTA);
        assertThat(gameImageRepository.findByIdGameId(game.getId())).singleElement()
                .extracting(GameImage::getType).isEqualTo(ImageType.PORTADA);
        assertThat(libraryEntryRepository.existsByIdUserEmailAndIdGameId(email, game.getId())).isTrue();
        assertThat(cartItemRepository.existsByIdUserEmailAndIdGameId(email, game.getId())).isTrue();
        assertThat(wishlistItemRepository.existsByIdUserEmailAndIdGameId(email, game.getId())).isTrue();
    }
}
