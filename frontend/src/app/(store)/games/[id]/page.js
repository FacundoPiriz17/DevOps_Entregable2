"use client";

import { useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import {
  LuArrowLeft,
  LuCalendarDays,
  LuCheck,
  LuHeart,
  LuShoppingCart,
  LuSparkles,
  LuTag,
} from "react-icons/lu";
import GameArtwork from "@/components/games/GameArtwork";
import NeonFrame from "@/components/games/NeonFrame";
import Button, { buttonClasses } from "@/components/ui/Button";
import LoadingState from "@/components/ui/LoadingState";
import { useAuth } from "@/context/AuthContext";
import { useStore } from "@/context/StoreContext";
import { useToast } from "@/context/ToastContext";
import { useGame } from "@/hooks/useCatalog";
import { formatDate, formatPrice } from "@/lib/games";

/**
 * Presenta los detalles de un videojuego y permite gestionar sus acciones.
 * @returns {JSX.Element} página renderizada con los detalles del videojuego
 */
export default function GameDetailPage() {
  const { id } = useParams();
  const { isUser } = useAuth();
  const { addToCart, toggleWishlist, inCart, inLibrary, inWishlist } = useStore();
  const { notify } = useToast();
  const gameQuery = useGame(id);
  const game = gameQuery.data;
  const [actionLoading, setActionLoading] = useState("");

  if (gameQuery.isPending) return <LoadingState label="Cargando detalles del juego..." />;

  if (gameQuery.isError || !game) {
    return (
      <div className="grid min-h-100 place-items-center gap-5 rounded-3xl border border-line bg-panel p-8 text-center shadow-card">
        <h1 className="text-3xl font-black tracking-tight">{gameQuery.error?.message || "No encontramos este juego"}</h1>
        <Link className={buttonClasses()} href="/catalog"><LuArrowLeft aria-hidden /> Volver al catálogo</Link>
      </div>
    );
  }

  const added = inCart(game.id);
  const owned = inLibrary(game.id);
  const wished = inWishlist(game.id);

  /**
   * Ejecuta una acción del videojuego y notifica los errores producidos.
   * @param {string} name nombre de la acción que se está ejecutando 
   * @param {() => Promise<void>} action función asíncrona que realiza la acción
   * @returns {Promise<void>} promesa que representa la ejecución de la acción
   */
  const runAction = async (name, action) => {
    setActionLoading(name);
    let actionError = null;
    try {
      await action();
    } catch (error) {
      actionError = error;
    }
    setActionLoading("");
    if (actionError) notify(actionError.message, "error");
  };

  return (
    <div className="grid gap-5">
      <Link className="inline-flex w-fit items-center gap-2 text-sm font-bold text-copy-soft transition hover:text-brand-blue" href="/catalog"><LuArrowLeft aria-hidden /> Volver al catálogo</Link>

      <NeonFrame game={game} imageType="banner" radius={29} className="rounded-4xl">
        <section className="relative min-h-162.5 overflow-hidden rounded-[inherit] bg-ink-900 text-white max-md:min-h-0">
        <GameArtwork game={game} type="banner" className="absolute inset-0 scale-105 opacity-55 blur-[2px]" />
        <div className="absolute inset-0 bg-[linear-gradient(90deg,rgba(5,8,23,.96),rgba(5,8,23,.74)_58%,rgba(5,8,23,.42)),linear-gradient(0deg,rgba(5,8,23,.9),transparent_62%)]" />
        <div className="relative grid min-h-162.5 grid-cols-[minmax(240px,330px)_minmax(0,1fr)] items-center gap-[clamp(34px,5vw,75px)] p-[clamp(38px,6vw,86px)] max-lg:grid-cols-[240px_minmax(0,1fr)] max-md:min-h-0 max-md:grid-cols-1 max-md:p-8 max-sm:p-6">
          <GameArtwork game={game} className="aspect-2/3 w-full rounded-3xl border-2 border-white/20 shadow-[0_30px_80px_rgba(0,0,0,.38)] max-md:max-w-57.5" />
          <div>
            <span className="inline-flex items-center gap-2 text-xs font-extrabold tracking-widest text-brand-cyan uppercase"><LuSparkles aria-hidden /> {game.studio}</span>
            <h1 className="my-4 text-[clamp(3rem,6vw,6.3rem)] leading-[.92] font-black tracking-[-.07em] max-lg:text-[clamp(2.8rem,6vw,4.5rem)] max-md:text-[clamp(2.7rem,13vw,4.6rem)]">{game.name}</h1>
            <p className="mb-5 max-w-3xl text-base leading-7 text-slate-300">{game.description}</p>
            <div className="flex flex-wrap gap-2">
              {game.categories?.map((category) => <span className="rounded-full bg-white/10 px-3 py-1.5 text-xs font-bold text-slate-200" key={category.id}>{category.name}</span>)}
            </div>
            <div className="mt-5 flex flex-wrap gap-4 text-xs text-slate-400">
              <span><LuCalendarDays aria-hidden /> Lanzamiento: {formatDate(game.releaseDate)}</span>
              <span><LuTag aria-hidden /> Estado: {game.status}</span>
            </div>
            <div className="mt-7 flex flex-wrap items-center gap-2.5">
              <strong className="mr-2 text-3xl">{formatPrice(game.price)}</strong>
              {isUser && owned && (
                <Link className={buttonClasses({ variant: "success", size: "large" })} href="/library"><LuCheck aria-hidden /> En tu biblioteca</Link>
              )}
              {isUser && !owned && added && (
                <Link className={buttonClasses({ variant: "secondary", size: "large" })} href="/cart"><LuShoppingCart aria-hidden /> Ver carrito</Link>
              )}
              {isUser && !owned && !added && (
                <Button
                  size="large"
                  loading={actionLoading === "cart"}
                  disabled={!game.available}
                  onClick={() => runAction("cart", () => addToCart(game.id))}
                >
                  <LuShoppingCart aria-hidden /> {game.available ? "Agregar al carrito" : "No disponible"}
                </Button>
              )}
              {isUser && !owned && (
                <Button
                  size="large"
                  variant="glass"
                  loading={actionLoading === "wish"}
                  onClick={() => runAction("wish", () => toggleWishlist(game.id))}
                >
                  <LuHeart aria-hidden /> {wished ? "Quitar de deseados" : "Guardar en deseados"}
                </Button>
              )}
            </div>
          </div>
        </div>
        </section>
      </NeonFrame>
    </div>
  );
}
