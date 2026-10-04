"use client";

import { useState } from "react";
import Link from "next/link";
import { LuCheck, LuHeart, LuInfo, LuShoppingCart } from "react-icons/lu";
import Button, { buttonClasses } from "@/components/ui/Button";
import { useAuth } from "@/context/AuthContext";
import { useStore } from "@/context/StoreContext";
import { useToast } from "@/context/ToastContext";
import { formatPrice } from "@/lib/games";
import { cn } from "@/lib/cn";
import GameArtwork from "./GameArtwork";
import NeonFrame from "./NeonFrame";

const statusLabels = {
  publicado: "Disponible",
  preventa: "Preventa",
  pausado: "Pausado",
  retirado: "Retirado",
};

/**
 * Presenta la información y acciones principales de un videojuego.
 * @param {Object} props propiedades del componente
 * @param {Object} props.game información del videojuego
 * @returns {JSX.Element} tarjeta del videojuego renderizada
 */
export default function GameCard({ game }) {
  const { isUser } = useAuth();
  const { addToCart, toggleWishlist, inCart, inLibrary, inWishlist } = useStore();
  const { notify } = useToast();
  const [cartLoading, setCartLoading] = useState(false);
  const [wishLoading, setWishLoading] = useState(false);
  const owned = inLibrary(game.id);
  const added = inCart(game.id);
  const wished = inWishlist(game.id);

  /**
   * Añade el videojuego al carrito y notifica los errores de la operación.
   * @returns {Promise<void>} promesa que representa la operación de agregado
   */
  const handleCart = async () => {
    setCartLoading(true);
    let actionError = null;
    try {
      await addToCart(game.id);
    } catch (error) {
      actionError = error;
    }
    setCartLoading(false);
    if (actionError) notify(actionError.message, "error");
  };

  /**
   * Añade o elimina el videojuego de la lista de deseados.
   * @returns {Promise<void>} promesa que representa la operación de actualización
   */
  const handleWishlist = async () => {
    setWishLoading(true);
    let actionError = null;
    try {
      await toggleWishlist(game.id);
    } catch (error) {
      actionError = error;
    }
    setWishLoading(false);
    if (actionError) notify(actionError.message, "error");
  };

  return (
    <NeonFrame game={game} radius={25} className="h-full rounded-3xl">
      <article className="group flex h-full min-w-0 flex-col overflow-hidden rounded-[inherit] border border-line bg-panel shadow-[0_8px_25px_rgba(0,0,0,.18)] transition duration-200 hover:-translate-y-1 hover:border-white/20 hover:bg-panel-hover hover:shadow-card max-sm:grid max-sm:grid-cols-[125px_minmax(0,1fr)]">
        <div className="relative aspect-4/5 max-sm:aspect-auto max-sm:min-h-67.5">
        <div className="relative size-full overflow-hidden rounded-[inherit] bg-ink-850">
          <GameArtwork className="size-full transition-transform duration-350 group-hover:scale-[1.035]" game={game} />
          <Link className="absolute inset-0 z-10" href={`/games/${game.id}`} aria-label={`Ver detalles de ${game.name}`} />
          <span className={cn(
            "absolute top-3 left-3 z-20 rounded-full border border-white/15 bg-ink-950/85 px-2.5 py-1.5 text-[.65rem] font-extrabold text-white capitalize backdrop-blur-lg",
            game.status === "publicado" && "bg-emerald-700/90",
            game.status === "preventa" && "bg-violet-700/90",
          )}>{statusLabels[game.status] || game.status}</span>
          {isUser && !owned && (
            <button
              className={cn(
                "absolute top-3 right-3 z-20 inline-flex size-10 items-center justify-center rounded-full border border-white/15 bg-ink-950/75 text-white backdrop-blur-lg [&_svg]:size-4.5",
                wished && "border-rose-300 bg-rose-500 [&_svg]:fill-current",
              )}
              type="button"
              onClick={handleWishlist}
              disabled={wishLoading}
              aria-label={wished ? `Quitar ${game.name} de deseados` : `Agregar ${game.name} a deseados`}
            >
              <LuHeart aria-hidden />
            </button>
          )}
        </div>
        </div>

      <div className="flex flex-1 flex-col p-4.5">
        <div className="flex items-start justify-between gap-3 max-sm:flex-col max-sm:gap-1">
          <div>
            <span className="mb-1 block text-[.67rem] font-bold tracking-wider text-copy-faint uppercase">{game.studio}</span>
            <h3 className="m-0 text-[1.05rem] leading-tight font-bold tracking-tight"><Link className="transition hover:text-brand-cyan" href={`/games/${game.id}`}>{game.name}</Link></h3>
          </div>
          <strong className="shrink-0 text-sm text-brand-violet-dark">{formatPrice(game.price)}</strong>
        </div>

        <p className="my-3 line-clamp-3 text-[.8rem] leading-relaxed text-copy-soft max-sm:line-clamp-4">{game.description}</p>

        <div className="flex flex-wrap gap-1.5">
          {game.categories?.slice(0, 3).map((category) => (
            <span className="rounded-full border border-white/6 bg-white/6 px-2 py-1.5 text-[.63rem] font-semibold text-copy-soft" key={category.id}>{category.name}</span>
          ))}
        </div>

        <div className="mt-auto grid grid-cols-[auto_1fr] gap-2 pt-4.5 max-sm:grid-cols-1 [&_.button-link]:px-3 [&_.button-link]:text-xs">
          <Link className={buttonClasses({ variant: "ghost", className: "button-link" })} href={`/games/${game.id}`}>
            <LuInfo aria-hidden /> Detalles
          </Link>
          {isUser && (
            owned ? (
              <Link className={buttonClasses({ variant: "success", className: "button-link" })} href="/library">
                <LuCheck aria-hidden /> En biblioteca
              </Link>
            ) : added ? (
              <Link className={buttonClasses({ variant: "secondary", className: "button-link" })} href="/cart">
                <LuShoppingCart aria-hidden /> En carrito
              </Link>
            ) : (
              <Button onClick={handleCart} loading={cartLoading} disabled={!game.available}>
                <LuShoppingCart aria-hidden /> {game.available ? "Agregar" : "No disponible"}
              </Button>
            )
          )}
        </div>
      </div>
      </article>
    </NeonFrame>
  );
}
