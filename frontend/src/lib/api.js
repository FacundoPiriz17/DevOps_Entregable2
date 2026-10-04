const API_URL = (process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080").replace(/\/$/, "");

const defaultMessages = {
  0: "No se pudo conectar con el backend. Comprobá que esté levantado.",
  400: "La solicitud contiene datos inválidos.",
  401: "Tu sesión venció o las credenciales no son correctas.",
  403: "No tenés permisos para realizar esta acción.",
  404: "No se encontró el recurso solicitado.",
  409: "La operación entra en conflicto con el estado actual.",
  500: "Ocurrió un error inesperado en el servidor.",
};

const translatedCodes = {
  INVALID_CREDENTIALS: "El correo o la contraseña no son correctos.",
  ACCESS_DENIED: "No tenés permisos para realizar esta acción.",
  EMAIL_ALREADY_USED: "Ya existe una cuenta con ese correo.",
  ACCOUNT_INACTIVE: "Esta cuenta fue desactivada.",
  ALREADY_IN_CART: "Este juego ya está en tu carrito.",
  ALREADY_IN_LIBRARY: "Este juego ya forma parte de tu biblioteca.",
  ALREADY_IN_WISHLIST: "Este juego ya está en tu lista de deseados.",
  GAME_NOT_AVAILABLE: "Este juego no está disponible para comprar.",
  GAME_RETIRED: "Los juegos retirados no pueden agregarse a deseados.",
  EMPTY_CART: "El carrito está vacío.",
};

/**
 * Representa un error producido por una respuesta de la API.
 * @param {number} status código de estado HTTP de la respuesta
 * @param {string} code código específico del error
 * @param {string} message mensaje original del error
 * @param {Object|null} [payload=null] contenido completo de la respuesta
 * @returns {ApiError} instancia del error de API
 */
export class ApiError extends Error {
  constructor(status, code, message, payload = null) {
    super(translatedCodes[code] || message || defaultMessages[status] || `Error ${status}`);
    this.name = "ApiError";
    this.status = status;
    this.code = code;
    this.payload = payload;
  }
}
/**
 * Ejecuta una solicitud HTTP contra el backend de la aplicación.
 * @param {string} path ruta del recurso solicitado
 * @param {Object} [options={}] opciones de configuración de la solicitud
 * @param {string} [options.method="GET"] método HTTP utilizado
 * @param {Object} [options.body] datos enviados en el cuerpo de la solicitud
 * @param {boolean} [options.notifyUnauthorized=true] indica si debe notificarse una sesión no autorizada
 * @returns {Promise<Object|null>} promesa con los datos de la respuesta o null
 * @throws {ApiError} si la solicitud falla o el backend devuelve un error
 */
async function request(path, { method = "GET", body, notifyUnauthorized = true } = {}) {
  const headers = { Accept: "application/json" };

  if (body !== undefined) headers["Content-Type"] = "application/json";

  let response;

  try {
    response = await fetch(`${API_URL}${path}`, {
      method,
      headers,
      credentials: "include",
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    throw new ApiError(0, "NETWORK_ERROR", defaultMessages[0]);
  }

  if (response.status === 401 && notifyUnauthorized && typeof window !== "undefined") {
    window.dispatchEvent(new Event("playhub:unauthorized"));
  }

  if (!response.ok) {
    let payload = null;
    try {
      payload = await response.json();
    } catch {
      payload = null;
    }

    throw new ApiError(
      response.status,
      payload?.code,
      payload?.message || defaultMessages[response.status],
      payload,
    );
  }

  if (response.status === 204) return null;
  const text = await response.text();
  return text ? JSON.parse(text) : null;
}

export const api = {
  auth: {
    /**
     * Inicia sesión con las credenciales proporcionadas.
     * @param {Object} credentials credenciales de acceso
     * @returns {Promise<Object|null>} promesa con la respuesta de autenticación
     * @throws {ApiError} si las credenciales no son válidas o la solicitud falla
     */
    login: (credentials) => request("/api/auth/login", { method: "POST", body: credentials, notifyUnauthorized: false }),

    /**
     * Registra una nueva cuenta de usuario.
     * @param {Object} data datos de registro de la cuenta
     * @returns {Promise<Object|null>} promesa con la respuesta del registro
     * @throws {ApiError} si los datos son inválidos o la solicitud falla
     */
    register: (data) => request("/api/auth/register", { method: "POST", body: data, notifyUnauthorized: false }),
    
    /**
     * Cierra la sesión del usuario actual.
     * @returns {Promise<Object|null>} promesa con la respuesta del cierre de sesión
     * @throws {ApiError} si la solicitud falla
     */
    logout: () => request("/api/auth/logout", { method: "POST", notifyUnauthorized: false }),
  },
  users: {
    /**
     * Obtiene los datos del usuario autenticado.
     * @param {Object} [options={}] opciones de configuración de la solicitud
     * @param {boolean} [options.notifyUnauthorized=true] indica si debe notificarse una sesión no autorizada
     * @returns {Promise<Object|null>} promesa con los datos del usuario
     * @throws {ApiError} si el usuario no está autenticado o la solicitud falla
     */
    me: ({ notifyUnauthorized = true } = {}) => request("/api/users/me", { notifyUnauthorized }),
  },
  games: {
    /**
     * Obtiene la lista de videojuegos.
     * @returns {Promise<Object|null>} promesa con los videojuegos disponibles
     * @throws {ApiError} si la solicitud falla
     */
    list: () => request("/api/games"),

    /**
     * Obtiene un videojuego por su identificador.
     * @param {string|number} id identificador del videojuego
     * @returns {Promise<Object|null>} promesa con los datos del videojuego
     * @throws {ApiError} si el videojuego no existe o la solicitud falla
     */
    get: (id) => request(`/api/games/${id}`),
  },
  categories: {
    /**
     * Obtiene la lista de categorías.
     * @returns {Promise<Object|null>} promesa con las categorías disponibles
     * @throws {ApiError} si la solicitud falla
     */
    list: () => request("/api/categories"),
  },
  cart: {
    /**
     * Obtiene el contenido del carrito del usuario.
     * @returns {Promise<Object|null>} promesa con los elementos del carrito
     * @throws {ApiError} si la solicitud falla
     */
    list: () => request("/api/cart"),

    /**
     * Añade un videojuego al carrito.
     * @param {string|number} gameId identificador del videojuego
     * @returns {Promise<Object|null>} promesa con el elemento agregado
     * @throws {ApiError} si el videojuego no puede agregarse o la solicitud falla
     */
    add: (gameId) => request(`/api/cart/games/${gameId}`, { method: "POST" }),

    /**
     * Elimina un videojuego del carrito.
     * @param {string|number} gameId identificador del videojuego
     * @returns {Promise<Object|null>} promesa con la respuesta de la operación
     * @throws {ApiError} si el videojuego no puede eliminarse o la solicitud falla
     */
    remove: (gameId) => request(`/api/cart/games/${gameId}`, { method: "DELETE" }),

    /**
     * Confirma la compra de los videojuegos del carrito.
     * @returns {Promise<Object|null>} promesa con los elementos comprados
     * @throws {ApiError} si el carrito no puede procesarse o la solicitud falla
     */
    checkout: () => request("/api/cart/checkout", { method: "POST" }),
  },
  library: {
    /**
     * Obtiene la biblioteca del usuario.
     * @returns {Promise<Object|null>} promesa con los videojuegos de la biblioteca
     * @throws {ApiError} si la solicitud falla
     */
    list: () => request("/api/library"),
    
    /**
     * Añade un videojuego a la biblioteca.
     * @param {string|number} gameId identificador del videojuego
     * @returns {Promise<Object|null>} promesa con el elemento agregado
     * @throws {ApiError} si el videojuego no puede agregarse o la solicitud falla
     */
    add: (gameId) => request(`/api/library/games/${gameId}`, { method: "POST" }),

    /**
     * Actualiza el estado de favorito de un videojuego de la biblioteca.
     * @param {string|number} gameId identificador del videojuego
     * @param {boolean} favorite indica si el videojuego debe marcarse como favorito
     * @returns {Promise<Object|null>} promesa con el elemento actualizado
     * @throws {ApiError} si el elemento no puede actualizarse o la solicitud falla
     */
    favorite: (gameId, favorite) => request(`/api/library/games/${gameId}/favorite`, {
      method: "PATCH",
      body: { favorite },
    }),
  },
  wishlist: {
    /**
     * Obtiene la lista de videojuegos deseados.
     * @returns {Promise<Object|null>} promesa con los elementos de la lista
     * @throws {ApiError} si la solicitud falla
     */
    list: () => request("/api/wishlist"),

    /**
     * Añade un videojuego a la lista de deseados.
     * @param {string|number} gameId identificador del videojuego
     * @returns {Promise<Object|null>} promesa con el elemento agregado
     * @throws {ApiError} si el videojuego no puede agregarse o la solicitud falla
     */
    add: (gameId) => request(`/api/wishlist/games/${gameId}`, { method: "POST" }),

    /**
     * Elimina un videojuego de la lista de deseados.
     * @param {string|number} gameId identificador del videojuego
     * @returns {Promise<Object|null>} promesa con la respuesta de la operación
     * @throws {ApiError} si el videojuego no puede eliminarse o la solicitud falla
     */
    remove: (gameId) => request(`/api/wishlist/games/${gameId}`, { method: "DELETE" }),
  },
};
