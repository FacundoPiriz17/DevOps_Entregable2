package com.devops.backend.common.util;

/**
 * @file EmailNormalizer.java
 * @brief Normaliza correos electrónicos para su uso consistente como identificador.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 *
 * @copyright Copyright (c) 2026
 */

import java.util.Locale;

/**
 * @brief Proporciona la lógica compartida para normalizar correos electrónicos.
 *
 */
public final class EmailNormalizer {

    private EmailNormalizer() {
    }

    /**
     * @brief Normaliza un correo electrónico eliminando espacios y convirtiéndolo a minúsculas.
     *
     * @param email correo electrónico que será normalizado.
     * @return correo electrónico normalizado.
     */
    public static String normalize(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }
}
