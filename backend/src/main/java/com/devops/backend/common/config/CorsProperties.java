/**
 * @file CorsProperties.java
 * @brief Contiene la configuración de los orígenes permitidos para CORS.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

package com.devops.backend.common.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.List;

@ConfigurationProperties(prefix = "app.cors")
public class CorsProperties {

    private List<String> allowedOrigins = List.of("http://localhost:5745");

    /**
     * @brief Obtiene la lista de orígenes permitidos para las peticiones CORS.
     *
     * @return lista de orígenes permitidos.
     */
    public List<String> getAllowedOrigins() {
        return allowedOrigins;
    }

    /**
     * @brief Actualiza la lista de orígenes permitidos para las peticiones CORS.
     *
     * @param allowedOrigins lista de nuevos orígenes permitidos.
     * @return no devuelve ningún valor.
     */
    public void setAllowedOrigins(List<String> allowedOrigins) {
        this.allowedOrigins = List.copyOf(allowedOrigins);
    }
}