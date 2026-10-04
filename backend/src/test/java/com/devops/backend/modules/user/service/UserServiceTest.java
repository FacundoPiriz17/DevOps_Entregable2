package com.devops.backend.modules.user.service;

import com.devops.backend.common.exception.ApiException;
import com.devops.backend.modules.user.entity.Role;
import com.devops.backend.modules.user.entity.User;
import com.devops.backend.modules.user.repository.UserRepository;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class UserServiceTest {
    private final UserRepository repository = mock(UserRepository.class);
    private final UserRoleService roles = mock(UserRoleService.class);
    private final UserService service = new UserService(repository, roles);

    @Test
    void currentUser_usesEmailIdentityAndIncludesCountry() {
        User user = new User("Julia", "julia@example.com", "Uruguay");
        when(repository.findById("julia@example.com")).thenReturn(Optional.of(user));
        when(roles.roleOf("julia@example.com")).thenReturn(Role.USER);
        var response = service.getCurrentUser("julia@example.com");
        assertThat(response.country()).isEqualTo("Uruguay");
        assertThat(response.role()).isEqualTo("USER");
    }

    @Test
    void currentUser_unknownEmailReturnsNotFound() {
        when(repository.findById("missing@test")).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.getCurrentUser("missing@test")).isInstanceOf(ApiException.class);
    }
}
