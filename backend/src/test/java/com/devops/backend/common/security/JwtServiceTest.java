package com.devops.backend.common.security;

import com.devops.backend.modules.user.entity.Role;
import com.devops.backend.modules.user.entity.User;
import io.jsonwebtoken.Jwts;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class JwtServiceTest {

    private static final String SECRET = "a-secret-key-long-enough-for-hmac-signing-tests-123456789";

    @Test
    void generateToken_usesEmailAsSubjectAndIncludesRole() {
        JwtService jwtService = new JwtService(SECRET, 120);
        User user = new User("Julia", "julia@example.com", "Uruguay");

        String token = jwtService.generateToken(user, Role.ADMIN);
        var claims = Jwts.parser().verifyWith(jwtService.getSigningKey()).build()
                .parseSignedClaims(token).getPayload();

        assertThat(claims.getSubject()).isEqualTo("julia@example.com");
        assertThat(claims.get("email")).isEqualTo("julia@example.com");
        assertThat(claims.get("role")).isEqualTo("ADMIN");
        assertThat(claims.getExpiration()).isAfter(claims.getIssuedAt());
    }
}
