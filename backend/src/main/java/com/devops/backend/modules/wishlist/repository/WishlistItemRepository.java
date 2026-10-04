package com.devops.backend.modules.wishlist.repository;

/**
 * @file WishlistItemRepository.java
 * @brief Proporciona operaciones de acceso y persistencia para los elementos de la lista de deseados.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.modules.wishlist.entity.WishlistItem;
import com.devops.backend.modules.wishlist.entity.WishlistItemId;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

/**
 * @brief Repositorio para gestionar las operaciones de persistencia de los elementos de la lista de deseados.
 *
 */
public interface WishlistItemRepository extends JpaRepository<WishlistItem, WishlistItemId> {

    /**
     * @brief Obtiene los elementos de la lista de deseados pertenecientes a un usuario.
     *
     * @param userEmail correo electrónico del usuario propietario de la lista de deseados.
     * @return lista de elementos asociados a la lista de deseados del usuario.
     */
    List<WishlistItem> findByIdUserEmail(String userEmail);

    /**
     * @brief Comprueba si un videojuego ya se encuentra en la lista de deseados de un usuario.
     *
     * @param userEmail correo electrónico del usuario propietario de la lista de deseados.
     * @param gameId identificador del videojuego que se desea comprobar.
     * @return true si el videojuego ya está en la lista de deseados; false en caso contrario.
     */
    boolean existsByIdUserEmailAndIdGameId(String userEmail, Long gameId);
}
