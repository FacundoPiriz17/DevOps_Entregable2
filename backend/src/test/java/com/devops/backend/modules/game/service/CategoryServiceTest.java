package com.devops.backend.modules.game.service;

import com.devops.backend.common.exception.ApiException;
import com.devops.backend.modules.game.dto.CategoryRequest;
import com.devops.backend.modules.game.entity.Category;
import com.devops.backend.modules.game.entity.CategoryType;
import com.devops.backend.modules.game.repository.CategoryRepository;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class CategoryServiceTest {
    private final CategoryRepository repository = mock(CategoryRepository.class);
    private final CategoryService service = new CategoryService(repository);

    @Test
    void create_mapsSpanishEnumType() {
        when(repository.save(any(Category.class))).thenAnswer(inv -> inv.getArgument(0));
        assertThat(service.create(new CategoryRequest("RPG", "genero")).type()).isEqualTo("genero");
    }

    @Test
    void create_duplicateReturnsConflict() {
        when(repository.existsByNameIgnoreCaseAndType("RPG", CategoryType.GENERO)).thenReturn(true);
        assertThatThrownBy(() -> service.create(new CategoryRequest("RPG", "genero")))
                .isInstanceOf(ApiException.class);
    }
}
