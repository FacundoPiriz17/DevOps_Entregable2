/**
 * @file SecurityConfig.java
 * @brief Configura la seguridad, autenticación, autorización y políticas CORS de la aplicación.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

package com.devops.backend.common.security;

import com.devops.backend.common.config.CorsProperties;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.server.resource.web.BearerTokenResolver;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.oauth2.server.resource.authentication.JwtGrantedAuthoritiesConverter;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

@Configuration
@EnableMethodSecurity
@EnableConfigurationProperties(CorsProperties.class)
public class SecurityConfig {

    /**
     * @brief Configura el codificador utilizado para proteger las contraseñas.
     *
     * @return codificador de contraseñas basado en BCrypt.
     */
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    /**
     * @brief Configura el decodificador utilizado para validar los tokens JWT.
     *
     * @param jwtService servicio utilizado para obtener la clave de firma de los tokens.
     * @return decodificador JWT configurado con la clave de firma.
     */
    @Bean
    public JwtDecoder jwtDecoder(JwtService jwtService) {
        return NimbusJwtDecoder.withSecretKey(jwtService.getSigningKey())
                .macAlgorithm(MacAlgorithm.HS384)
                .build();
    }

    /**
     * @brief Configura la conversión de los roles incluidos en los tokens JWT a autoridades de Spring Security.
     *
     * @return convertidor de autenticación JWT configurado para procesar los roles.
     */
    @Bean
    public JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtGrantedAuthoritiesConverter authoritiesConverter = new JwtGrantedAuthoritiesConverter();
        authoritiesConverter.setAuthorityPrefix("ROLE_");
        authoritiesConverter.setAuthoritiesClaimName("role");

        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(authoritiesConverter);
        return converter;
    }

    /**
     * @brief Configura las políticas CORS permitidas para las solicitudes de la aplicación.
     *
     * @param corsProperties propiedades que contienen los orígenes permitidos para CORS.
     * @return fuente de configuración CORS aplicada a las rutas de la aplicación.
     */
    @Bean
    public UrlBasedCorsConfigurationSource corsConfigurationSource(CorsProperties corsProperties) {
        CorsConfiguration configuration = new CorsConfiguration();
        configuration.setAllowedOrigins(corsProperties.getAllowedOrigins());
        configuration.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        configuration.setAllowedHeaders(List.of("Authorization", "Content-Type", "Accept"));
        configuration.setExposedHeaders(List.of("Location"));
        configuration.setAllowCredentials(true);
        configuration.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }

    /**
     * @brief Configura el mecanismo utilizado para obtener el token Bearer de las solicitudes.
     *
     * @return resolvedor de tokens Bearer configurado para utilizar JWT.
     */
    @Bean
    public BearerTokenResolver bearerTokenResolver() {
        return new JwtCookieBearerTokenResolver();
    }

    /**
     * @brief Configura la cadena de filtros de seguridad, autenticación y autorización de la aplicación.
     *
     * @param http configuración HTTP utilizada para definir las políticas de seguridad.
     * @param converter convertidor utilizado para transformar los roles del token JWT.
     * @param bearerTokenResolver resolvedor utilizado para obtener el token Bearer.
     * @param corsConfigurationSource fuente de configuración utilizada para las políticas CORS.
     * @param authenticationEntryPoint manejador utilizado para las solicitudes que requieren autenticación.
     * @param accessDeniedHandler manejador utilizado para los accesos denegados por falta de permisos.
     * @return cadena de filtros de seguridad configurada para la aplicación.
     */
    @Bean
    public SecurityFilterChain securityFilterChain(
            HttpSecurity http,
            JwtAuthenticationConverter converter,
            BearerTokenResolver bearerTokenResolver,
            UrlBasedCorsConfigurationSource corsConfigurationSource,
            RestAuthenticationEntryPoint authenticationEntryPoint,
            RestAccessDeniedHandler accessDeniedHandler) throws Exception {
        http
                .cors(cors -> cors.configurationSource(corsConfigurationSource))
                .csrf(csrf -> csrf.disable())
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        .requestMatchers("/api/auth/**").permitAll()
                        .requestMatchers("/swagger-ui.html", "/swagger-ui/**").permitAll()
                        .requestMatchers("/v3/api-docs", "/v3/api-docs/**").permitAll()
                        .requestMatchers("/actuator/health/**").permitAll()
                        .requestMatchers("/api/admin/**").hasRole("ADMIN")
                        .requestMatchers("/api/library/**", "/api/cart/**", "/api/wishlist/**")
                        .hasRole("USER")
                        .anyRequest().authenticated())
                .exceptionHandling(exceptions -> exceptions
                        .authenticationEntryPoint(authenticationEntryPoint)
                        .accessDeniedHandler(accessDeniedHandler))
                .oauth2ResourceServer(oauth2 -> oauth2
                        .bearerTokenResolver(bearerTokenResolver)
                        .authenticationEntryPoint(authenticationEntryPoint)
                        .accessDeniedHandler(accessDeniedHandler)
                        .jwt(jwt -> jwt.jwtAuthenticationConverter(converter)));

        return http.build();
    }
}
