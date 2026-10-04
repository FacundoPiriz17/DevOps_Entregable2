package com.devops.backend.modules.auth.service;

import com.devops.backend.common.exception.ApiException;
import com.devops.backend.common.security.JwtService;
import com.devops.backend.modules.auth.dto.LoginRequest;
import com.devops.backend.modules.auth.dto.RegisterRequest;
import com.devops.backend.modules.auth.entity.Login;
import com.devops.backend.modules.auth.repository.LoginRepository;
import com.devops.backend.modules.user.entity.GeneralUser;
import com.devops.backend.modules.user.entity.Role;
import com.devops.backend.modules.user.entity.User;
import com.devops.backend.modules.user.repository.GeneralUserRepository;
import com.devops.backend.modules.user.repository.UserRepository;
import com.devops.backend.modules.user.service.UserRoleService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {
    @Mock UserRepository userRepository;
    @Mock LoginRepository loginRepository;
    @Mock GeneralUserRepository generalUserRepository;
    @Mock UserRoleService userRoleService;
    @Mock PasswordEncoder passwordEncoder;
    @Mock JwtService jwtService;

    private AuthService service() {
        return new AuthService(userRepository, loginRepository, generalUserRepository,
                userRoleService, passwordEncoder, jwtService);
    }

    @Test
    void register_createsProfileCredentialsAndGeneralRoleAtomically() {
        RegisterRequest request = new RegisterRequest(
                "Julia", " JULIA@example.com ", "Uruguay", "Password123");
        when(userRepository.existsById("julia@example.com")).thenReturn(false);
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
        when(passwordEncoder.encode("Password123")).thenReturn("hashed");
        when(jwtService.generateToken(any(User.class), org.mockito.ArgumentMatchers.eq(Role.USER)))
                .thenReturn("token");

        var response = service().register(request);

        assertThat(response.email()).isEqualTo("julia@example.com");
        assertThat(response.country()).isEqualTo("Uruguay");
        assertThat(response.role()).isEqualTo("USER");
        verify(loginRepository).save(any(Login.class));
        verify(generalUserRepository).save(any(GeneralUser.class));
    }

    @Test
    void register_existingEmailReturnsConflict() {
        RegisterRequest request = new RegisterRequest("Julia", "julia@example.com", "Uruguay", "Password123");
        when(userRepository.existsById("julia@example.com")).thenReturn(true);
        assertThatThrownBy(() -> service().register(request)).isInstanceOf(ApiException.class);
        verify(loginRepository, never()).save(any());
    }

    @Test
    void login_readsPasswordFromLoginAndRoleFromProfileTable() {
        User user = new User("Julia", "julia@example.com", "Uruguay");
        Login login = new Login("julia@example.com", "hashed");
        when(userRepository.findById("julia@example.com")).thenReturn(Optional.of(user));
        when(loginRepository.findById("julia@example.com")).thenReturn(Optional.of(login));
        when(passwordEncoder.matches("Password123", "hashed")).thenReturn(true);
        when(userRoleService.roleOf("julia@example.com")).thenReturn(Role.USER);
        when(jwtService.generateToken(user, Role.USER)).thenReturn("token");

        assertThat(service().login(new LoginRequest("julia@example.com", "Password123")).token())
                .isEqualTo("token");
    }

    @Test
    void login_wrongPasswordReturnsBadCredentials() {
        User user = new User("Julia", "julia@example.com", "Uruguay");
        when(userRepository.findById("julia@example.com")).thenReturn(Optional.of(user));
        when(loginRepository.findById("julia@example.com"))
                .thenReturn(Optional.of(new Login("julia@example.com", "hashed")));
        when(passwordEncoder.matches("wrong", "hashed")).thenReturn(false);
        assertThatThrownBy(() -> service().login(new LoginRequest("julia@example.com", "wrong")))
                .isInstanceOf(BadCredentialsException.class);
    }

    @Test
    void login_inactiveProfileReturnsForbidden() {
        User user = new User("Julia", "julia@example.com", "Uruguay");
        user.setActive(false);
        when(userRepository.findById("julia@example.com")).thenReturn(Optional.of(user));
        when(loginRepository.findById("julia@example.com"))
                .thenReturn(Optional.of(new Login("julia@example.com", "hashed")));
        when(passwordEncoder.matches("Password123", "hashed")).thenReturn(true);
        assertThatThrownBy(() -> service().login(new LoginRequest("julia@example.com", "Password123")))
                .isInstanceOf(ApiException.class).hasMessageContaining("deactivated");
    }
}
