import clsx from "clsx";
import { twMerge } from "tailwind-merge";

/**
 * Combina clases CSS y resuelve conflictos entre clases de Tailwind CSS.
 * @param {...*} inputs valores de clases CSS a combinar
 * @returns {string} clases CSS combinadas y optimizadas
 */
export function cn(...inputs) {
  return twMerge(clsx(inputs));
}
