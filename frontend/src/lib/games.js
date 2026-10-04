const priceFormatter = new Intl.NumberFormat("es-UY", {
  style: "currency",
  currency: "USD",
  minimumFractionDigits: 2,
});

/**
 * Formatea un valor numérico como precio en dólares estadounidenses.
 * @param {number|string} value valor numérico que se desea formatear
 * @returns {string} precio formateado
 */
export const formatPrice = (value) => priceFormatter.format(Number(value || 0));

/**
 * Formatea una fecha en español con el formato utilizado por la aplicación.
 * @param {string} value fecha en formato ISO
 * @returns {string} fecha formateada o mensaje indicando que no existe fecha
 */
export const formatDate = (value) => {
  if (!value) return "Sin fecha";
  return format(parseISO(value), "d 'de' MMMM 'de' yyyy", { locale: es });
};

/**
 * Obtiene la URL de la imagen preferida de un videojuego.
 * @param {Object} game información del videojuego
 * @param {string} [preferredType="portada"] tipo de imagen preferida
 * @returns {string|null} URL de la imagen encontrada
 */
export const gameImage = (game, preferredType = "portada") => {
  const images = game?.images || [];
  return images.find((image) => image.type === preferredType)?.url || images[0]?.url || null;
};

/**
 * Obtiene el texto alternativo de la imagen preferida de un videojuego.
 * @param {Object} game información del videojuego
 * @param {string} [preferredType="portada"] tipo de imagen preferida
 * @returns {string} texto alternativo de la imagen
 */
export const gameImageAlt = (game, preferredType = "portada") => {
  const images = game?.images || [];
  return images.find((image) => image.type === preferredType)?.alternativeText
    || images[0]?.alternativeText
    || `Imagen de ${game?.name || "videojuego"}`;
};

/**
 * Selecciona una cantidad aleatoria de videojuegos sin modificar la colección original.
 * @param {Array<Object>} games lista de videojuegos disponibles
 * @param {number} [amount=5] cantidad máxima de videojuegos a seleccionar
 * @returns {Array<Object>} videojuegos seleccionados aleatoriamente
 */
export const pickRandomGames = (games, amount = 5) => {
  const shuffled = [...games];

  for (let index = shuffled.length - 1; index > 0; index -= 1) {
    const values = new Uint32Array(1);
    globalThis.crypto.getRandomValues(values);
    const target = values[0] % (index + 1);
    [shuffled[index], shuffled[target]] = [shuffled[target], shuffled[index]];
  }

  return shuffled.slice(0, amount);
};

/**
 * Combina las entradas de una colección con los datos completos de sus videojuegos.
 * @param {Array<Object>} entries entradas que contienen identificadores de videojuegos
 * @param {Array<Object>} games lista de videojuegos disponibles
 * @returns {Array<Object>} entradas combinadas con la información de los videojuegos
 */
export const mergeGames = (entries, games) => entries.map((entry) => ({
  ...games.find((game) => game.id === entry.gameId),
  ...entry,
  id: entry.gameId,
}));
import { format, parseISO } from "date-fns";
import { es } from "date-fns/locale";
