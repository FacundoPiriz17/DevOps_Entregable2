package com.devops.backend.modules.game.service;

/**
 * @file GameService.java
 * @brief Gestiona las operaciones relacionadas con los videojuegos y sus categorías e imágenes.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.common.exception.ApiException;
import com.devops.backend.modules.game.dto.GameImageResponse;
import com.devops.backend.modules.game.dto.GameRequest;
import com.devops.backend.modules.game.dto.GameResponse;
import com.devops.backend.modules.game.entity.Category;
import com.devops.backend.modules.game.entity.Game;
import com.devops.backend.modules.game.entity.GameImage;
import com.devops.backend.modules.game.entity.GameStatus;
import com.devops.backend.modules.game.entity.ImageAsset;
import com.devops.backend.modules.game.repository.CategoryRepository;
import com.devops.backend.modules.game.repository.GameImageRepository;
import com.devops.backend.modules.game.repository.GameRepository;
import com.devops.backend.modules.game.repository.ImageAssetRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * @brief Proporciona la lógica necesaria para consultar, crear, actualizar y desactivar videojuegos.
 *
 */
@Service
public class GameService {

    private final GameRepository gameRepository;
    private final CategoryRepository categoryRepository;
    private final GameImageRepository gameImageRepository;
    private final ImageAssetRepository imageAssetRepository;

    public GameService(GameRepository gameRepository,
                       CategoryRepository categoryRepository,
                       GameImageRepository gameImageRepository,
                       ImageAssetRepository imageAssetRepository) {
        this.gameRepository = gameRepository;
        this.categoryRepository = categoryRepository;
        this.gameImageRepository = gameImageRepository;
        this.imageAssetRepository = imageAssetRepository;
    }

    /**
     * @brief Obtiene todos los videojuegos registrados junto con sus categorías e imágenes.
     *
     * @return lista de videojuegos registrados.
     */
    @Transactional(readOnly = true)
    public List<GameResponse> listAll() {
        return gameRepository.findAll().stream().map(this::toResponse).toList();
    }

    /**
     * @brief Obtiene un videojuego mediante su identificador.
     *
     * @param id identificador del videojuego que se desea consultar.
     * @return información del videojuego solicitado.
     * @throws ApiException si el videojuego no existe.
     */
    @Transactional(readOnly = true)
    public GameResponse getById(Long id) {
        return toResponse(findGameOrThrow(id));
    }

    /**
     * @brief Crea un nuevo videojuego con las categorías indicadas.
     *
     * @param request datos necesarios para crear el videojuego.
     * @param adminEmail correo electrónico del administrador que registra el videojuego.
     * @return información del videojuego creado.
     * @throws ApiException si una o más categorías indicadas no existen.
     */
    @Transactional
    public GameResponse create(GameRequest request, String adminEmail) {
        Game game = new Game(request.name().trim(), request.description().trim(), request.price(),
                request.releaseDate(), request.studio().trim(), GameStatus.fromValue(request.status()), adminEmail);
        game.replaceCategories(resolveCategories(request.categoryIds()));
        return toResponse(gameRepository.save(game));
    }

    /**
     * @brief Actualiza la información de un videojuego existente.
     *
     * @param id identificador del videojuego que se desea actualizar.
     * @param request nuevos datos del videojuego.
     * @return información actualizada del videojuego.
     * @throws ApiException si el videojuego no existe o una o más categorías indicadas no existen.
     */
    @Transactional
    public GameResponse update(Long id, GameRequest request) {
        Game game = findGameOrThrow(id);
        game.setName(request.name().trim());
        game.setDescription(request.description().trim());
        game.setPrice(request.price());
        game.setReleaseDate(request.releaseDate());
        game.setStudio(request.studio().trim());
        game.setStatus(GameStatus.fromValue(request.status()));
        game.replaceCategories(resolveCategories(request.categoryIds()));
        return toResponse(game);
    }

    /**
     * @brief Desactiva un videojuego estableciendo su estado como retirado.
     *
     * @param id identificador del videojuego que se desea desactivar.
     * @return información del videojuego después de su desactivación.
     * @throws ApiException si el videojuego no existe o ya se encuentra retirado.
     */
    @Transactional
    public GameResponse deactivate(Long id) {
        Game game = findGameOrThrow(id);
        if (game.getStatus() == GameStatus.RETIRADO) {
            throw ApiException.conflict("GAME_ALREADY_RETIRED", "Game is already retired");
        }
        game.setStatus(GameStatus.RETIRADO);
        return toResponse(game);
    }

    /**
     * @brief Busca un videojuego mediante su identificador o genera un error si no existe.
     *
     * @param id identificador del videojuego que se desea buscar.
     * @return entidad del videojuego encontrado.
     * @throws ApiException si el videojuego no existe.
     */
    @Transactional(readOnly = true)
    public Game findGameOrThrow(Long id) {
        return gameRepository.findById(id)
                .orElseThrow(() -> ApiException.notFound("GAME_NOT_FOUND", "Game does not exist"));
    }

    /**
     * @brief Obtiene las categorías correspondientes a los identificadores proporcionados.
     *
     * @param categoryIds identificadores de las categorías que se desean asociar.
     * @return conjunto de categorías encontradas.
     * @throws ApiException si una o más categorías indicadas no existen.
     */
    private Set<Category> resolveCategories(Set<Long> categoryIds) {
        if (categoryIds == null || categoryIds.isEmpty()) return Set.of();
        List<Category> categories = categoryRepository.findAllById(categoryIds);
        if (categories.size() != categoryIds.size()) {
            throw ApiException.badRequest("CATEGORY_NOT_FOUND", "One or more categories do not exist");
        }
        return new LinkedHashSet<>(categories);
    }

    /**
     * @brief Construye la respuesta de un videojuego incluyendo sus imágenes asociadas.
     *
     * @param game videojuego del que se construirá la respuesta.
     * @return respuesta con la información del videojuego, sus categorías e imágenes.
     */
    private GameResponse toResponse(Game game) {
        List<GameImage> links = gameImageRepository.findByIdGameId(game.getId());
        Map<Long, ImageAsset> imagesById = imageAssetRepository
                .findAllById(links.stream().map(link -> link.getId().getImageId()).toList())
                .stream().collect(Collectors.toMap(ImageAsset::getId, Function.identity()));
        List<GameImageResponse> images = links.stream()
                .filter(link -> imagesById.containsKey(link.getId().getImageId()))
                .map(link -> GameImageResponse.from(link, imagesById.get(link.getId().getImageId())))
                .toList();
        return GameResponse.from(game, images);
    }
}
