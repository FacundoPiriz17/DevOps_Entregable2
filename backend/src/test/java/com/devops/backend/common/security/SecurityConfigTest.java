package com.devops.backend.common.security;

import com.devops.backend.common.config.CorsProperties;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import tools.jackson.databind.json.JsonMapper;

import java.util.List;
import jakarta.servlet.http.Cookie;

import static org.assertj.core.api.Assertions.assertThat;

class SecurityConfigTest {

    @Test
    void corsConfiguration_allowsConfiguredOriginsAndApiHeaders() {
        CorsProperties properties = new CorsProperties();
        properties.setAllowedOrigins(List.of("http://localhost:3000", "https://store.example.com"));

        UrlBasedCorsConfigurationSource source = new SecurityConfig().corsConfigurationSource(properties);
        CorsConfiguration configuration = source.getCorsConfiguration(
                new MockHttpServletRequest("OPTIONS", "/api/games"));

        assertThat(configuration).isNotNull();
        assertThat(configuration.getAllowedOrigins())
                .containsExactly("http://localhost:3000", "https://store.example.com");
        assertThat(configuration.getAllowedMethods())
                .contains("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS");
        assertThat(configuration.getAllowedHeaders())
                .contains("Authorization", "Content-Type", "Accept");
        assertThat(configuration.getAllowCredentials()).isTrue();
    }

    @Test
    void bearerTokenResolver_acceptsHeaderAndHttpOnlyCookieTransport() {
        JwtCookieBearerTokenResolver resolver = new JwtCookieBearerTokenResolver();
        MockHttpServletRequest cookieRequest = new MockHttpServletRequest("GET", "/api/games");
        cookieRequest.setCookies(new Cookie(JwtCookieBearerTokenResolver.COOKIE_NAME, "cookie-token"));
        assertThat(resolver.resolve(cookieRequest)).isEqualTo("cookie-token");

        MockHttpServletRequest headerRequest = new MockHttpServletRequest("GET", "/api/games");
        headerRequest.addHeader(HttpHeaders.AUTHORIZATION, "Bearer header-token");
        assertThat(resolver.resolve(headerRequest)).isEqualTo("header-token");
    }

    @Test
    void authenticationEntryPoint_returnsStructuredJson401() throws Exception {
        MockHttpServletResponse response = new MockHttpServletResponse();
        SecurityErrorResponseWriter writer = new SecurityErrorResponseWriter(testJsonMapper());
        RestAuthenticationEntryPoint entryPoint = new RestAuthenticationEntryPoint(writer);

        entryPoint.commence(
                new MockHttpServletRequest("GET", "/api/games"),
                response,
                new BadCredentialsException("Invalid token"));

        assertThat(response.getStatus()).isEqualTo(HttpStatus.UNAUTHORIZED.value());
        assertThat(response.getHeader(HttpHeaders.WWW_AUTHENTICATE)).isEqualTo("Bearer");
        assertThat(response.getContentType()).startsWith("application/json");
        assertThat(response.getContentAsString()).contains("\"code\":\"UNAUTHORIZED\"");
        assertThat(response.getContentAsString()).contains("\"status\":401");
    }

    @Test
    void accessDeniedHandler_returnsStructuredJson403() throws Exception {
        MockHttpServletResponse response = new MockHttpServletResponse();
        SecurityErrorResponseWriter writer = new SecurityErrorResponseWriter(testJsonMapper());
        RestAccessDeniedHandler handler = new RestAccessDeniedHandler(writer);

        handler.handle(
                new MockHttpServletRequest("GET", "/api/admin/users/1"),
                response,
                new AccessDeniedException("Forbidden"));

        assertThat(response.getStatus()).isEqualTo(HttpStatus.FORBIDDEN.value());
        assertThat(response.getContentType()).startsWith("application/json");
        assertThat(response.getContentAsString()).contains("\"code\":\"ACCESS_DENIED\"");
        assertThat(response.getContentAsString()).contains("\"status\":403");
    }

    private static JsonMapper testJsonMapper() {
        return JsonMapper.builder().findAndAddModules().build();
    }
}
