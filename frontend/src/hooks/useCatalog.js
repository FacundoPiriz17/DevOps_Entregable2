"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";

/**
 * Obtiene la lista de videojuegos mediante React Query.
 * @returns {Object} consulta con los videojuegos y su estado de carga
 */
export function useGames() {
  return useQuery({
    queryKey: ["games"],
    queryFn: api.games.list,
  });
}

/**
 * Obtiene la lista de categorías mediante React Query.
 * @returns {Object} consulta con las categorías y su estado de carga
 */
export function useCategories() {
  return useQuery({
    queryKey: ["categories"],
    queryFn: api.categories.list,
  });
}
/**
 * Obtiene un videojuego específico mediante React Query.
 * @param {string|number} id identificador del videojuego
 * @returns {Object} consulta con el videojuego y su estado de carga
 */
export function useGame(id) {
  const queryClient = useQueryClient();

  return useQuery({
    queryKey: ["games", String(id)],
    queryFn: () => api.games.get(id),
    enabled: Boolean(id),
    initialData: () => queryClient.getQueryData(["games"])
      ?.find((game) => String(game.id) === String(id)),
    initialDataUpdatedAt: () => queryClient.getQueryState(["games"])?.dataUpdatedAt,
  });
}
