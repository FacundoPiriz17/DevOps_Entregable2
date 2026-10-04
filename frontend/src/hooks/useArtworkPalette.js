"use client";

import { useEffect, useMemo, useState } from "react";

const palettes = [
  ["hsl(190, 94%, 58%)", "hsl(265, 92%, 62%)"],
  ["hsl(28, 96%, 58%)", "hsl(348, 92%, 60%)"],
  ["hsl(148, 88%, 57%)", "hsl(184, 92%, 52%)"],
  ["hsl(216, 94%, 61%)", "hsl(286, 88%, 62%)"],
  ["hsl(48, 96%, 59%)", "hsl(18, 94%, 57%)"],
];

const paletteCache = new Map();
const paletteRequests = new Map();

/**
 * Genera una semilla numérica determinista a partir de un valor.
 * @param {string|number} value valor utilizado para generar la semilla
 * @returns {number} semilla numérica generada
 */
function hashSeed(value) {
  return String(value || "PlayHub").split("").reduce(
    (hash, character) => ((hash * 31) + character.charCodeAt(0)) >>> 0,
    2166136261,
  );
}

/**
 * Obtiene una paleta predeterminada a partir de una semilla.
 * @param {string|number} seed semilla utilizada para seleccionar la paleta
 * @returns {Array<string>} colores de la paleta seleccionada
 */
function fallbackPalette(seed) {
  return palettes[hashSeed(seed) % palettes.length];
}

/**
 * Convierte un color RGB al espacio de color HSL.
 * @param {number} red componente roja del color 
 * @param {number} green componente verde del color
 * @param {number} blue componente azul del color
 * @returns {Object} componentes HSL del color
 */
function rgbToHsl(red, green, blue) {
  const r = red / 255;
  const g = green / 255;
  const b = blue / 255;
  const maximum = Math.max(r, g, b);
  const minimum = Math.min(r, g, b);
  const delta = maximum - minimum;
  const lightness = (maximum + minimum) / 2;

  if (!delta) return { hue: 0, saturation: 0, lightness };

  const saturation = delta / (1 - Math.abs((2 * lightness) - 1));
  let hue;
  if (maximum === r) hue = 60 * (((g - b) / delta) % 6);
  else if (maximum === g) hue = 60 * (((b - r) / delta) + 2);
  else hue = 60 * (((r - g) / delta) + 4);

  return { hue: hue < 0 ? hue + 360 : hue, saturation, lightness };
}
/**
 * Calcula la distancia mínima entre dos tonos en el círculo cromático.
 * @param {number} first primer tono
 * @param {number} second segundo tono
 * @returns {number} distancia entre ambos tonos
 */
function hueDistance(first, second) {
  const difference = Math.abs(first - second);
  return Math.min(difference, 360 - difference);
}

/**
 * Extrae una paleta de colores representativa a partir de una imagen.
 * @param {HTMLImageElement} image imagen utilizada para obtener los colores
 * @param {Array<string>} fallback paleta utilizada si no se pueden extraer colores
 * @returns {Array<string>} paleta de colores extraída o alternativa
 */
function extractPalette(image, fallback) {
  const canvas = document.createElement("canvas");
  canvas.width = 32;
  canvas.height = 32;
  const context = canvas.getContext("2d", { willReadFrequently: true });
  if (!context) return fallback;

  context.drawImage(image, 0, 0, canvas.width, canvas.height);
  const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data;
  const hueBins = new Map();

  for (let index = 0; index < pixels.length; index += 16) {
    if (pixels[index + 3] < 180) continue;
    const color = rgbToHsl(pixels[index], pixels[index + 1], pixels[index + 2]);
    if (color.saturation < 0.18 || color.lightness < 0.08 || color.lightness > 0.92) continue;
    const hue = Math.round(color.hue / 12) * 12 % 360;
    const centeredLightness = 1 - Math.abs(color.lightness - 0.52);
    const weight = (0.25 + color.saturation) * centeredLightness;
    hueBins.set(hue, (hueBins.get(hue) || 0) + weight);
  }

  const rankedHues = [...hueBins.entries()].sort((first, second) => second[1] - first[1]);
  if (!rankedHues.length) return fallback;

  const primaryHue = rankedHues[0][0];
  const secondaryHue = rankedHues.find(([hue]) => hueDistance(primaryHue, hue) >= 32)?.[0]
    ?? (primaryHue + 64) % 360;

  return [
    `hsl(${primaryHue}, 94%, 61%)`,
    `hsl(${secondaryHue}, 90%, 60%)`,
  ];
}

/**
 * Comprueba si una imagen puede procesarse desde el origen actual.
 * @param {string} imageUrl URL de la imagen que se desea analizar
 * @returns {boolean} indica si la imagen puede ser muestreada
 */
function canSampleImage(imageUrl) {
  try {
    const url = new URL(imageUrl, window.location.href);
    return url.origin === window.location.origin;
  } catch {
    return false;
  }
}

/**
 * Solicita la extracción de una paleta de una imagen y gestiona su caché.
 * @param {string} imageUrl URL de la imagen que se desea analizar
 * @param {Array<string>} fallback paleta utilizada como alternativa
 * @returns {Promise<Array<string>>} promesa con la paleta obtenida
 */
function requestPalette(imageUrl, fallback) {
  if (paletteCache.has(imageUrl)) return Promise.resolve(paletteCache.get(imageUrl));
  if (paletteRequests.has(imageUrl)) return paletteRequests.get(imageUrl);
  if (!canSampleImage(imageUrl)) {
    paletteCache.set(imageUrl, fallback);
    return Promise.resolve(fallback);
  }

  const request = new Promise((resolve) => {
    const image = new Image();
    image.crossOrigin = "anonymous";
    image.decoding = "async";
    image.onload = () => {
      let palette = fallback;
      try {
        palette = extractPalette(image, fallback);
      } catch {
        palette = fallback;
      }
      paletteCache.set(imageUrl, palette);
      resolve(palette);
    };
    image.onerror = () => resolve(fallback);
    image.src = imageUrl;
  }).finally(() => paletteRequests.delete(imageUrl));

  paletteRequests.set(imageUrl, request);
  return request;
}

/**
 * Obtiene una paleta de colores adaptada a la imagen de una obra.
 * @param {string} imageUrl URL de la imagen utilizada para extraer la paleta
 * @param {string|number} seed semilla utilizada para generar la paleta alternativa
 * @param {Array<string>} [preferredPalette] paleta preferida utilizada como alternativa
 * @returns {Array<string>} paleta de colores resuelta para la imagen
 */
export default function useArtworkPalette(imageUrl, seed, preferredPalette) {
  const fallback = useMemo(
    () => preferredPalette || fallbackPalette(`${seed}-${imageUrl}`),
    [seed, imageUrl, preferredPalette],
  );
  const [resolved, setResolved] = useState(null);

  useEffect(() => {
    if (!imageUrl) return undefined;
    let active = true;
    requestPalette(imageUrl, fallback).then((palette) => {
      if (active) setResolved({ imageUrl, palette });
    });
    return () => {
      active = false;
    };
  }, [imageUrl, fallback]);

  return resolved?.imageUrl === imageUrl ? resolved.palette : fallback;
}
