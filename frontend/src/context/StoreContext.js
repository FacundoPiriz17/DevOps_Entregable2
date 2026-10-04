"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import { api } from "@/lib/api";
import { useAuth } from "./AuthContext";
import { useToast } from "./ToastContext";

const StoreContext = createContext(null);

/**
 * Proporciona el estado y las operaciones del carrito, biblioteca y lista de deseados.
 * @param {Object} props propiedades del componente
 * @param {React.ReactNode} props.children contenido que tendrá acceso al contexto 
 * @returns {JSX.Element} proveedor de la tienda renderizado
 */
export function StoreProvider({ children }) {
  const { ready, isUser } = useAuth();
  const { notify } = useToast();
  const [cart, setCart] = useState([]);
  const [library, setLibrary] = useState([]);
  const [wishlist, setWishlist] = useState([]);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async () => {
    if (!isUser) {
      setCart([]);
      setLibrary([]);
      setWishlist([]);
      setLoading(false);
      return;
    }

    setLoading(true);
    let loadError = null;
    try {
      const [nextCart, nextLibrary, nextWishlist] = await Promise.all([
        api.cart.list(),
        api.library.list(),
        api.wishlist.list(),
      ]);
      setCart(nextCart);
      setLibrary(nextLibrary);
      setWishlist(nextWishlist);
    } catch (error) {
      loadError = error;
    }
    setLoading(false);
    if (loadError) notify(loadError.message, "error");
  }, [isUser, notify]);

  useEffect(() => {
    if (!ready) return undefined;
    const timer = window.setTimeout(refresh, 0);
    return () => window.clearTimeout(timer);
  }, [ready, refresh]);

  const addToCart = useCallback(async (gameId) => {
    const item = await api.cart.add(gameId);
    setCart((current) => current.some((entry) => entry.gameId === gameId) ? current : [...current, item]);
    notify(`${item.name} se agregó al carrito.`, "success");
    return item;
  }, [notify]);

  const removeFromCart = useCallback(async (gameId) => {
    await api.cart.remove(gameId);
    setCart((current) => current.filter((entry) => entry.gameId !== gameId));
    notify("Juego eliminado del carrito.", "info");
  }, [notify]);

  const checkout = useCallback(async () => {
    const entries = await api.cart.checkout();
    const purchasedIds = new Set(entries.map((entry) => entry.gameId));
    const wishlistPurchases = wishlist.filter((item) => purchasedIds.has(item.gameId));
    await Promise.allSettled(wishlistPurchases.map((item) => api.wishlist.remove(item.gameId)));
    setCart([]);
    setLibrary((current) => [...current, ...entries]);
    setWishlist((current) => current.filter((item) => !purchasedIds.has(item.gameId)));
    notify("Compra confirmada. Los juegos ya están en tu biblioteca.", "success");
    return entries;
  }, [wishlist, notify]);

  const toggleWishlist = useCallback(async (gameId) => {
    const existing = wishlist.find((item) => item.gameId === gameId);

    if (existing) {
      await api.wishlist.remove(gameId);
      setWishlist((current) => current.filter((item) => item.gameId !== gameId));
      notify("Juego eliminado de deseados.", "info");
      return false;
    }

    const item = await api.wishlist.add(gameId);
    setWishlist((current) => [...current, item]);
    notify(`${item.name} se agregó a deseados.`, "success");
    return true;
  }, [wishlist, notify]);

  const toggleFavorite = useCallback(async (gameId) => {
    const current = library.find((entry) => entry.gameId === gameId);
    if (!current) return null;
    const updated = await api.library.favorite(gameId, !current.favorite);
    setLibrary((entries) => entries.map((entry) => entry.gameId === gameId ? updated : entry));
    notify(updated.favorite ? "Marcado como favorito." : "Quitado de favoritos.", "success");
    return updated;
  }, [library, notify]);

  const value = useMemo(() => ({
    cart,
    library,
    wishlist,
    loading,
    refresh,
    addToCart,
    removeFromCart,
    checkout,
    toggleWishlist,
    toggleFavorite,
    inCart: (gameId) => cart.some((item) => item.gameId === gameId),
    inLibrary: (gameId) => library.some((item) => item.gameId === gameId),
    inWishlist: (gameId) => wishlist.some((item) => item.gameId === gameId),
  }), [cart, library, wishlist, loading, refresh, addToCart, removeFromCart, checkout, toggleWishlist, toggleFavorite]);

  return <StoreContext.Provider value={value}>{children}</StoreContext.Provider>;
}

/**
 * Obtiene el contexto de la tienda disponible para el componente actual.
 * @returns {Object} estado y operaciones de la tienda
 * @throws {Error} si se utiliza fuera de un StoreProvider
 */
export function useStore() {
  const context = useContext(StoreContext);
  if (!context) throw new Error("useStore debe utilizarse dentro de StoreProvider");
  return context;
}
