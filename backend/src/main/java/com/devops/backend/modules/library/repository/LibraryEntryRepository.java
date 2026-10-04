package com.devops.backend.modules.library.repository;

/**
 * @file LibraryEntryRepository.java
 * @brief Proporciona operaciones de acceso y persistencia para las entradas de la biblioteca de los usuarios.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

import com.devops.backend.modules.library.entity.LibraryEntry;
import com.devops.backend.modules.library.entity.LibraryEntryId;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

/**
 * @brief Repositorio para gestionar las operaciones de persistencia de las entradas de la biblioteca.
 *
 */
public interface LibraryEntryRepository extends JpaRepository<LibraryEntry, LibraryEntryId> {

    /**
     * @brief Obtiene todas las entradas de biblioteca pertenecientes a un usuario.
     *
     * @param userEmail correo electrónico del usuario propietario de la biblioteca.
     * @return lista de entradas de biblioteca asociadas al usuario.
     */
    List<LibraryEntry> findByIdUserEmail(String userEmail);

    /**
     * @brief Busca la entrada de biblioteca correspondiente a un usuario y videojuego.
     *
     * @param userEmail correo electrónico del usuario propietario de la biblioteca.
     * @param gameId identificador del videojuego que se desea buscar.
     * @return entrada de biblioteca encontrada, si existe.
     */
    Optional<LibraryEntry> findByIdUserEmailAndIdGameId(String userEmail, Long gameId);

    /**
     * @brief Comprueba si un videojuego ya pertenece a la biblioteca de un usuario.
     *
     * @param userEmail correo electrónico del usuario propietario de la biblioteca.
     * @param gameId identificador del videojuego que se desea comprobar.
     * @return true si el videojuego ya pertenece a la biblioteca; false en caso contrario.
     */
    boolean existsByIdUserEmailAndIdGameId(String userEmail, Long gameId);
}
