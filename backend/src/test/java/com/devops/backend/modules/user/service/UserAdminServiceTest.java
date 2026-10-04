package com.devops.backend.modules.user.service;

import com.devops.backend.common.exception.ApiException;
import com.devops.backend.modules.user.entity.Role;
import com.devops.backend.modules.user.entity.User;
import com.devops.backend.modules.user.repository.UserRepository;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class UserAdminServiceTest {
    private final UserRepository repository = mock(UserRepository.class);
    private final UserRoleService roles = mock(UserRoleService.class);
    private final UserAdminService service = new UserAdminService(repository, roles);

    @Test
    void list_resolvesRoleFromProfileTables() {
        User user = new User("Julia", "julia@example.com", "Uruguay");
        when(repository.findAll()).thenReturn(List.of(user));
        when(roles.roleOf("julia@example.com")).thenReturn(Role.USER);
        assertThat(service.getUsers()).singleElement().extracting("role").isEqualTo("USER");
    }

    @Test
    void deactivate_usesEmailAndKeepsLogicalDeletion() {
        User user = new User("Julia", "julia@example.com", "Uruguay");
        when(repository.findById("julia@example.com")).thenReturn(Optional.of(user));
        when(roles.roleOf("julia@example.com")).thenReturn(Role.USER);
        assertThat(service.deactivate("julia@example.com").active()).isFalse();
    }

    @Test
    void get_unknownUserReturnsNotFound() {
        when(repository.findById("missing@test")).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.getUser("missing@test")).isInstanceOf(ApiException.class);
    }
}
