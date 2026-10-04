"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { LuArrowRight, LuHeart, LuShoppingCart, LuTrash2 } from "react-icons/lu";
import GameArtwork from "@/components/games/GameArtwork";
import Button, { buttonClasses } from "@/components/ui/Button";
import EmptyState from "@/components/ui/EmptyState";
import LoadingState from "@/components/ui/LoadingState";
import { useStore } from "@/context/StoreContext";
import { useToast } from "@/context/ToastContext";
import { useGames } from "@/hooks/useCatalog";
import { formatPrice, mergeGames } from "@/lib/games";

const EMPTY_GAMES = [];

/**
 * Presenta la lista de videojuegos guardados como deseados.
 * @returns {JSX.Element} página renderizada de la lista de deseados 
 */
export default function WishlistPage() {
  const { wishlist, loading: storeLoading, addToCart, toggleWishlist, inCart, inLibrary } = useStore();
  const { notify } = useToast();
  const gamesQuery = useGames();
  const games = gamesQuery.data || EMPTY_GAMES;
  const [updating, setUpdating] = useState(null);

  const items = useMemo(() => mergeGames(wishlist, games), [wishlist, games]);

  /**
   * Ejecuta una acción sobre un videojuego y notifica los errores producidos.
   * @param {number} gameId identificador del videojuego 
   * @param {() => Promise<void>} action función asíncrona que realiza la acción
   * @returns {Promise<void>} promesa que representa la ejecución de la acción 
   */
  const runAction = async (gameId, action) => {
    setUpdating(gameId);
    let actionError = null;
    try {
      await action();
    } catch (error) {
      actionError = error;
    }
    setUpdating(null);
    if (actionError) notify(actionError.message, "error");
  };

  if (storeLoading || gamesQuery.isPending) return <LoadingState label="Buscando tus deseados..." />;

  return (
    <div className="grid gap-8.5">
      <div><span className="text-xs font-extrabold tracking-widest text-brand-blue uppercase">Para más adelante</span><h1 className="mt-1.5 text-[clamp(2.15rem,4vw,3.45rem)] leading-none font-black tracking-[-0.06em]">Lista de deseados</h1><p className="mt-3 text-sm text-copy-soft">Guardá acá los juegos que no querés perder de vista.</p></div>

      {!items.length ? (
        <EmptyState
          icon={LuHeart}
          title="Todavía no guardaste juegos"
          description="Usá el corazón de cualquier card para armar tu lista personal."
          action={<Link className={buttonClasses()} href="/catalog">Descubrir juegos <LuArrowRight aria-hidden /></Link>}
        />
      ) : (
        <div className="grid gap-3">
          {items.map((item) => {
            const added = inCart(item.gameId);
            const owned = inLibrary(item.gameId);
            return (
              <article className="grid grid-cols-[100px_minmax(0,1fr)_auto_auto] items-center gap-5 rounded-2xl border border-line bg-panel p-4 shadow-card max-md:grid-cols-[82px_minmax(0,1fr)] max-md:gap-3" key={item.gameId}>
                <GameArtwork className="aspect-2/3 w-full rounded-xl" game={item} />
                <div className="min-w-0">
                  <span className="text-[.68rem] font-extrabold tracking-widest text-copy-faint uppercase">{item.studio || item.status}</span>
                  <h2 className="mt-1 text-lg font-extrabold tracking-tight">{item.name}</h2>
                  <p className="mt-1 line-clamp-2 text-sm leading-relaxed text-copy-soft">{item.description || `Agregado a deseados el ${item.addedAt}`}</p>
                  <div className="mt-2 flex flex-wrap gap-1.5">{item.categories?.slice(0, 3).map((category) => <span className="rounded-full border border-indigo-400/15 bg-indigo-400/10 px-2.5 py-1 text-[.68rem] font-bold text-indigo-200" key={category.id}>{category.name}</span>)}</div>
                </div>
                <strong className="text-base max-md:col-start-2">{formatPrice(item.price)}</strong>
                <div className="flex flex-wrap justify-end gap-2 max-md:col-start-2 max-md:justify-start">
                  {owned ? (
                    <Link className={buttonClasses({ variant: "success" })} href="/library">En biblioteca</Link>
                  ) : added ? (
                    <Link className={buttonClasses({ variant: "secondary" })} href="/cart"><LuShoppingCart aria-hidden /> En carrito</Link>
                  ) : (
                    <Button
                      loading={updating === item.gameId}
                      disabled={!item.available}
                      onClick={() => runAction(item.gameId, () => addToCart(item.gameId))}
                    >
                      <LuShoppingCart aria-hidden /> Agregar
                    </Button>
                  )}
                  <Button variant="danger-ghost" onClick={() => runAction(item.gameId, () => toggleWishlist(item.gameId))}>
                    <LuTrash2 aria-hidden /> Quitar
                  </Button>
                </div>
              </article>
            );
          })}
        </div>
      )}
    </div>
  );
}
