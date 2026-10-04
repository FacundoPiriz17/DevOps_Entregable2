package com.devops.backend.modules.cart.repository;

/**
 * @file CartItemRepository.java
 * @brief Proporciona operaciones de acceso y persistencia para los elementos del carrito.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.modules.cart.entity.CartItem;
import com.devops.backend.modules.cart.entity.CartItemId;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

/**
 * @brief Repositorio para gestionar los elementos almacenados en los carritos de los usuarios.
 *
 */
public interface CartItemRepository extends JpaRepository<CartItem, CartItemId> {

    /**
     * @brief Obtiene los elementos del carrito pertenecientes a un usuario.
     *
     * @param userEmail correo electrónico del usuario propietario del carrito.
     * @return lista de elementos asociados al carrito del usuario.
     */
    List<CartItem> findByIdUserEmail(String userEmail);

    /**
     * @brief Comprueba si un juego ya se encuentra en el carrito de un usuario.
     *
     * @param userEmail correo electrónico del usuario propietario del carrito.
     * @param gameId identificador del juego que se desea comprobar.
     * @return true si el juego ya está en el carrito; false en caso contrario.
     */
    boolean existsByIdUserEmailAndIdGameId(String userEmail, Long gameId);
}