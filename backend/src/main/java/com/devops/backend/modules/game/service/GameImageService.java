package com.devops.backend.modules.game.service;

/**
 * @file GameImageService.java
 * @brief Gestiona las operaciones relacionadas con las imágenes de los videojuegos.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.common.exception.ApiException;
import com.devops.backend.modules.game.dto.GameImageRequest;
import com.devops.backend.modules.game.dto.GameImageResponse;
import com.devops.backend.modules.game.entity.Game;
import com.devops.backend.modules.game.entity.GameImage;
import com.devops.backend.modules.game.entity.GameImageId;
import com.devops.backend.modules.game.entity.ImageAsset;
import com.devops.backend.modules.game.entity.ImageType;
import com.devops.backend.modules.game.repository.GameImageRepository;
import com.devops.backend.modules.game.repository.ImageAssetRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * @brief Proporciona la lógica necesaria para añadir y eliminar imágenes de videojuegos.
 *
 */
@Service
public class GameImageService {

    private final GameService gameService;
    private final ImageAssetRepository imageAssetRepository;
    private final GameImageRepository gameImageRepository;

    public GameImageService(GameService gameService,
                            ImageAssetRepository imageAssetRepository,
                            GameImageRepository gameImageRepository) {
        this.gameService = gameService;
        this.imageAssetRepository = imageAssetRepository;
        this.gameImageRepository = gameImageRepository;
    }

    /**
     * @brief Añade una imagen a un videojuego y crea su relación correspondiente.
     *
     * @param gameId identificador del videojuego al que se asociará la imagen.
     * @param request datos necesarios para crear la imagen.
     * @return respuesta con la información de la imagen añadida al videojuego.
     * @throws ApiException si el videojuego no existe.
     */
    @Transactional
    public GameImageResponse add(Long gameId, GameImageRequest request) {
        Game game = gameService.findGameOrThrow(gameId);
        ImageAsset image = imageAssetRepository.save(
                new ImageAsset(request.url().trim(), normalizeAlternativeText(request.alternativeText())));
        GameImage link = gameImageRepository.save(
                new GameImage(game.getId(), image.getId(), ImageType.fromValue(request.type())));
        return GameImageResponse.from(link, image);
    }

    /**
     * @brief Elimina una imagen de un videojuego y elimina el recurso si ya no está asociado.
     *
     * @param gameId identificador del videojuego al que pertenece la imagen.
     * @param imageId identificador de la imagen que se desea eliminar.
     * @return no devuelve ningún valor.
     * @throws ApiException si la imagen no está asociada al videojuego.
     */
    @Transactional
    public void remove(Long gameId, Long imageId) {
        GameImageId id = new GameImageId(gameId, imageId);
        if (!gameImageRepository.existsById(id)) {
            throw ApiException.notFound("GAME_IMAGE_NOT_FOUND", "Image is not associated with this game");
        }
        gameImageRepository.deleteById(id);
        gameImageRepository.flush();
        if (!gameImageRepository.existsByIdImageId(imageId)) imageAssetRepository.deleteById(imageId);
    }

    /**
     * @brief Normaliza el texto alternativo de una imagen.
     *
     * @param value texto alternativo que se desea normalizar.
     * @return texto alternativo sin espacios innecesarios o null si está vacío.
     */
    private String normalizeAlternativeText(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }
}
