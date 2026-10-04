/**
 * @file OpenApiConfig.java
 * @brief Configura la documentación y seguridad de la API REST con OpenAPI y Swagger.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

package com.devops.backend.common.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    public static final String BEARER_AUTH = "bearerAuth";

    /**
     * @brief Configura la información de la API y el esquema de autenticación con JWT.
     *
     * @return configuración de OpenAPI con la información de la API y el esquema de seguridad JWT.
     */
    @Bean
    public OpenAPI playHubOpenApi() {
        return new OpenAPI()
                .info(new Info()
                        .title("PlayHub API")
                        .description("API REST de PlayHub para catálogo, usuarios, biblioteca, carrito y deseados")
                        .version("v1"))
                .components(new Components()
                        .addSecuritySchemes(BEARER_AUTH, new SecurityScheme()
                                .type(SecurityScheme.Type.HTTP)
                                .scheme("bearer")
                                .bearerFormat("JWT")));
    }
}