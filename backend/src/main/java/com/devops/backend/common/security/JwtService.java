/**
 * @file JwtService.java
 * @brief Genera y gestiona tokens JWT utilizados para la autenticación de usuarios.
 * @author Equipo de Desarrollo DevOps
 * @version 1.0
 * @date 06/09/2026
 * 
 * @copyright Copyright (c) 2026
 */

package com.devops.backend.common.security;

import com.devops.backend.modules.user.entity.Role;
import com.devops.backend.modules.user.entity.User;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import io.jsonwebtoken.security.MacAlgorithm;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Date;

@Service
public class JwtService {

    private static final MacAlgorithm SIGNATURE_ALGORITHM = Jwts.SIG.HS384;

    private final SecretKey signingKey;
    private final long expirationMinutes;

    public JwtService(@Value("${jwt.secret}") String secret,
                      @Value("${jwt.expiration-minutes}") long expirationMinutes) {
        this.signingKey = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.expirationMinutes = expirationMinutes;
    }

    /**
     * @brief Genera un token JWT con el correo electrónico y rol del usuario.
     *
     * @param user usuario para el que se genera el token.
     * @param role rol del usuario que se incluirá en el token.
     * @return token JWT generado para el usuario.
     */
    public String generateToken(User user, Role role) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(user.getEmail())
                .claim("email", user.getEmail())
                .claim("role", role.name())
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(expirationMinutes, ChronoUnit.MINUTES)))
                .signWith(signingKey, SIGNATURE_ALGORITHM)
                .compact();
    }

    /**
     * @brief Obtiene la clave utilizada para firmar los tokens JWT.
     *
     * @return clave secreta utilizada para firmar los tokens JWT.
     */
    public SecretKey getSigningKey() {
        return signingKey;
    }
}