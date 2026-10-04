package com.devops.backend.web;

import com.devops.backend.common.exception.GlobalExceptionHandler;
import com.devops.backend.common.security.CurrentUser;
import com.devops.backend.common.security.RestAccessDeniedHandler;
import com.devops.backend.common.security.RestAuthenticationEntryPoint;
import com.devops.backend.common.security.SecurityConfig;
import com.devops.backend.common.security.SecurityErrorResponseWriter;
import com.devops.backend.modules.auth.controller.AuthController;
import com.devops.backend.modules.auth.dto.AuthResponse;
import com.devops.backend.modules.auth.dto.LoginRequest;
import com.devops.backend.modules.auth.dto.RegisterRequest;
import com.devops.backend.modules.auth.service.AuthService;
import com.devops.backend.modules.cart.controller.CartController;
import com.devops.backend.modules.cart.dto.CartItemResponse;
import com.devops.backend.modules.cart.service.CartService;
import com.devops.backend.modules.game.controller.AdminCategoryController;
import com.devops.backend.modules.game.controller.AdminGameController;
import com.devops.backend.modules.game.controller.AdminGameImageController;
import com.devops.backend.modules.game.controller.CategoryController;
import com.devops.backend.modules.game.controller.GameController;
import com.devops.backend.modules.game.dto.CategoryRequest;
import com.devops.backend.modules.game.dto.CategoryResponse;
import com.devops.backend.modules.game.dto.GameImageRequest;
import com.devops.backend.modules.game.dto.GameImageResponse;
import com.devops.backend.modules.game.dto.GameRequest;
import com.devops.backend.modules.game.dto.GameResponse;
import com.devops.backend.modules.game.service.CategoryService;
import com.devops.backend.modules.game.service.GameImageService;
import com.devops.backend.modules.game.service.GameService;
import com.devops.backend.modules.library.controller.LibraryController;
import com.devops.backend.modules.library.dto.LibraryEntryResponse;
import com.devops.backend.modules.library.service.LibraryService;
import com.devops.backend.modules.user.controller.UserAdminController;
import com.devops.backend.modules.user.controller.UserController;
import com.devops.backend.modules.user.dto.UserBasicResponse;
import com.devops.backend.modules.user.service.UserAdminService;
import com.devops.backend.modules.user.service.UserService;
import com.devops.backend.modules.wishlist.controller.WishlistController;
import com.devops.backend.modules.wishlist.dto.WishlistItemResponse;
import com.devops.backend.modules.wishlist.service.WishlistService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.RequestPostProcessor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Set;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = {
        AuthController.class, GameController.class, AdminGameController.class,
        CategoryController.class, AdminCategoryController.class, AdminGameImageController.class,
        LibraryController.class, CartController.class, WishlistController.class,
        UserController.class, UserAdminController.class
})
@Import({SecurityConfig.class, CurrentUser.class, GlobalExceptionHandler.class,
        SecurityErrorResponseWriter.class, RestAuthenticationEntryPoint.class, RestAccessDeniedHandler.class})
class ApiControllerTest {
    private static final String USER = "julia@example.com";
    private static final String ADMIN = "admin@playhub.test";
    private static final LocalDate DATE = LocalDate.of(2026, 8, 20);

    @Autowired MockMvc mockMvc;
    @MockitoBean AuthService authService;
    @MockitoBean GameService gameService;
    @MockitoBean CategoryService categoryService;
    @MockitoBean GameImageService gameImageService;
    @MockitoBean LibraryService libraryService;
    @MockitoBean CartService cartService;
    @MockitoBean WishlistService wishlistService;
    @MockitoBean UserService userService;
    @MockitoBean UserAdminService userAdminService;
    @MockitoBean JwtDecoder jwtDecoder;

    @Test
    void register_isPublicAndRequiresCountryFromNewProfile() throws Exception {
        RegisterRequest request = new RegisterRequest("Julia", USER, "Uruguay", "Password123");
        when(authService.register(request))
                .thenReturn(new AuthResponse("token", "Julia", USER, "Uruguay", "USER"));

        mockMvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON).content("""
                {"name":"Julia","email":"julia@example.com","country":"Uruguay","password":"Password123"}
                """))
                .andExpect(status().isCreated())
                .andExpect(header().string(HttpHeaders.SET_COOKIE,
                        org.hamcrest.Matchers.allOf(
                                org.hamcrest.Matchers.containsString("playhub_session=token"),
                                org.hamcrest.Matchers.containsString("HttpOnly"),
                                org.hamcrest.Matchers.containsString("Secure"),
                                org.hamcrest.Matchers.containsString("SameSite=Strict"))))
                .andExpect(jsonPath("$.token").doesNotExist())
                .andExpect(jsonPath("$.email").value(USER))
                .andExpect(jsonPath("$.country").value("Uruguay"));
        verify(authService).register(request);
    }

    @Test
    void register_invalidBodyReturnsStructuredValidationError() throws Exception {
        mockMvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
        verify(authService, never()).register(any());
    }

    @Test
    void login_badCredentialsReturnsStructured401() throws Exception {
        when(authService.login(any(LoginRequest.class))).thenThrow(new BadCredentialsException("bad"));
        mockMvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content("""
                {"email":"julia@example.com","password":"wrong-password"}
                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"));
    }

    @Test
    void protectedCatalog_withoutTokenReturnsStructured401() throws Exception {
        mockMvc.perform(get("/api/games"))
                .andExpect(status().isUnauthorized())
                .andExpect(header().string(HttpHeaders.WWW_AUTHENTICATE, "Bearer"))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    void catalog_returnsExpandedGameDto() throws Exception {
        when(gameService.listAll()).thenReturn(List.of(game()));
        mockMvc.perform(get("/api/games").with(userJwt()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].price").value(79.99))
                .andExpect(jsonPath("$[0].status").value("preventa"))
                .andExpect(jsonPath("$[0].categories[0].type").value("genero"))
                .andExpect(jsonPath("$[0].images[0].type").value("portada"));
    }

    @Test
    void regularUser_cannotUseAdminEndpoints() throws Exception {
        mockMvc.perform(get("/api/admin/users").with(userJwt()))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("ACCESS_DENIED"));
    }

    @Test
    void admin_canCreateExpandedGameUsingEmailSubject() throws Exception {
        GameRequest request = gameRequest();
        when(gameService.create(request, ADMIN)).thenReturn(game());
        mockMvc.perform(post("/api/admin/games").with(adminJwt())
                        .contentType(MediaType.APPLICATION_JSON).content("""
                        {"name":"GTA VI","description":"Open world","price":79.99,
                         "releaseDate":"2026-11-19","studio":"Rockstar","status":"preventa",
                         "categoryIds":[1]}
                        """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.registeredBy").value(ADMIN));
        verify(gameService).create(request, ADMIN);
    }

    @Test
    void admin_canCreateCategoryAndImage() throws Exception {
        CategoryRequest category = new CategoryRequest("RPG", "genero");
        when(categoryService.create(category)).thenReturn(new CategoryResponse(1L, "RPG", "genero"));
        mockMvc.perform(post("/api/admin/categories").with(adminJwt())
                        .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"RPG\",\"type\":\"genero\"}"))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.type").value("genero"));

        GameImageRequest image = new GameImageRequest("https://img.test/cover.jpg", "Cover", "portada");
        when(gameImageService.add(10L, image))
                .thenReturn(new GameImageResponse(5L, image.url(), image.alternativeText(), image.type()));
        mockMvc.perform(post("/api/admin/games/10/images").with(adminJwt())
                        .contentType(MediaType.APPLICATION_JSON).content("""
                        {"url":"https://img.test/cover.jpg","alternativeText":"Cover","type":"portada"}
                        """))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.id").value(5));
    }

    @Test
    void user_canAddToLibraryAndMarkFavorite() throws Exception {
        when(libraryService.addToLibrary(USER, 10L)).thenReturn(library());
        mockMvc.perform(post("/api/library/games/10").with(userJwt()))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.gameId").value(10));

        when(libraryService.setFavorite(USER, 10L, true)).thenReturn(favoriteLibrary());
        mockMvc.perform(patch("/api/library/games/10/favorite").with(userJwt())
                        .contentType(MediaType.APPLICATION_JSON).content("{\"favorite\":true}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.favorite").value(true));
    }

    @Test
    void user_canUseCartAndWishlist() throws Exception {
        when(cartService.add(USER, 10L))
                .thenReturn(new CartItemResponse(10L, "GTA VI", new BigDecimal("79.99"), "preventa"));
        mockMvc.perform(post("/api/cart/games/10").with(userJwt()))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.price").value(79.99));

        when(wishlistService.add(USER, 10L))
                .thenReturn(new WishlistItemResponse(10L, "GTA VI", new BigDecimal("79.99"), "preventa", DATE));
        mockMvc.perform(post("/api/wishlist/games/10").with(userJwt()))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.addedAt").value("2026-08-20"));
    }

    @Test
    void admin_cannotUseGeneralUserCollections() throws Exception {
        mockMvc.perform(get("/api/cart").with(adminJwt()))
                .andExpect(status().isForbidden()).andExpect(jsonPath("$.code").value("ACCESS_DENIED"));
    }

    @Test
    void identityEndpointsUseEmailPathAndJwtSubject() throws Exception {
        when(userService.getCurrentUser(USER)).thenReturn(user());
        mockMvc.perform(get("/api/users/me").with(userJwt()))
                .andExpect(status().isOk()).andExpect(jsonPath("$.country").value("Uruguay"));

        when(userAdminService.getUser(USER)).thenReturn(user());
        mockMvc.perform(get("/api/admin/users/julia@example.com").with(adminJwt()))
                .andExpect(status().isOk()).andExpect(jsonPath("$.email").value(USER));
    }

    @Test
    void corsPreflight_allowsConfiguredFrontendOrigin() throws Exception {
        mockMvc.perform(options("/api/games")
                        .header(HttpHeaders.ORIGIN, "http://localhost:3000")
                        .header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, "GET"))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, "http://localhost:3000"));
    }

    private static RequestPostProcessor userJwt() {
        return jwt().jwt(token -> token.subject(USER).claim("role", "USER"))
                .authorities(new SimpleGrantedAuthority("ROLE_USER"));
    }

    private static RequestPostProcessor adminJwt() {
        return jwt().jwt(token -> token.subject(ADMIN).claim("role", "ADMIN"))
                .authorities(new SimpleGrantedAuthority("ROLE_ADMIN"));
    }

    private static GameRequest gameRequest() {
        return new GameRequest("GTA VI", "Open world", new BigDecimal("79.99"),
                LocalDate.of(2026, 11, 19), "Rockstar", "preventa", Set.of(1L));
    }

    private static GameResponse game() {
        return new GameResponse(10L, "GTA VI", "Open world", new BigDecimal("79.99"),
                LocalDate.of(2026, 11, 19), "Rockstar", "preventa", true, ADMIN, DATE,
                List.of(new CategoryResponse(1L, "RPG", "genero")),
                List.of(new GameImageResponse(5L, "https://img.test/cover.jpg", "Cover", "portada")));
    }

    private static LibraryEntryResponse library() {
        return new LibraryEntryResponse(10L, "GTA VI", "Open world", new BigDecimal("79.99"),
                "Rockstar", DATE, false);
    }

    private static LibraryEntryResponse favoriteLibrary() {
        return new LibraryEntryResponse(10L, "GTA VI", "Open world", new BigDecimal("79.99"),
                "Rockstar", DATE, true);
    }

    private static UserBasicResponse user() {
        return new UserBasicResponse("Julia", USER, "Uruguay", "USER", true, DATE);
    }
}
