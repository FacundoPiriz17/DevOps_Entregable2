"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { AnimatePresence } from "motion/react";
import * as m from "motion/react-m";
import { LuArrowLeft, LuArrowRight, LuShoppingCart, LuSparkles } from "react-icons/lu";
import Button, { buttonClasses } from "@/components/ui/Button";
import { useAuth } from "@/context/AuthContext";
import { useStore } from "@/context/StoreContext";
import { useToast } from "@/context/ToastContext";
import { formatPrice, gameImage } from "@/lib/games";
import GameArtwork from "./GameArtwork";
import NeonFrame from "./NeonFrame";

/**
 * Presenta un carrusel animado con los videojuegos destacados.
 * @param {Object} props propiedades del componente 
 * @param {Array<Object>} props.games videojuegos disponibles para mostrar
 * @returns {JSX.Element|null} carrusel de videojuegos destacados renderizado
 */
export default function FeaturedCarousel({ games }) {
  const { isUser } = useAuth();
  const { addToCart, inCart, inLibrary } = useStore();
  const { notify } = useToast();
  const [index, setIndex] = useState(0);
  const [adding, setAdding] = useState(false);

  useEffect(() => {
    if (games.length < 2) return undefined;
    const interval = window.setInterval(() => {
      setIndex((current) => (current + 1) % games.length);
    }, 6500);
    return () => window.clearInterval(interval);
  }, [games.length]);

  if (!games.length) return null;

  const game = games[index] || games[0];
  const background = gameImage(game, "banner") || gameImage(game);
  const added = inCart(game.id);
  const owned = inLibrary(game.id);

  /**
   * Cambia el videojuego actualmente seleccionado en el carrusel.
   * @param {number} direction dirección del desplazamiento del carrusel
   * @returns {void} no devuelve ningún valor
   */
  const move = (direction) => {
    setIndex((current) => (current + direction + games.length) % games.length);
  };

  /**
   * Añade el videojuego destacado al carrito y notifica los errores.
   * @returns {Promise<void>} promesa que representa la operación de agregado
   */
  const handleAdd = async () => {
    setAdding(true);
    let actionError = null;
    try {
      await addToCart(game.id);
    } catch (error) {
      actionError = error;
    }
    setAdding(false);
    if (actionError) notify(actionError.message, "error");
  };

  return (
    <NeonFrame game={game} imageType="banner" imageUrl={background} radius={29} className="rounded-4xl max-md:rounded-3xl">
      <section className="relative min-h-120 overflow-hidden rounded-[inherit] bg-ink-900 text-white shadow-[0_28px_65px_rgba(9,14,38,.2)] max-md:min-h-125 max-sm:min-h-135" aria-roledescription="carrusel" aria-label="Juegos destacados">
      <AnimatePresence mode="popLayout">
        <m.div
          key={`image-${game.id}`}
          className="absolute inset-0 scale-[1.02]"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.45 }}
        >
          <GameArtwork game={game} type="banner" priority className="size-full" />
        </m.div>
      </AnimatePresence>
      <div className="absolute inset-0 bg-[linear-gradient(90deg,rgba(5,8,23,.97)_0%,rgba(5,8,23,.8)_43%,rgba(5,8,23,.2)_78%),linear-gradient(0deg,rgba(5,8,23,.8),transparent_55%)] max-md:bg-[linear-gradient(0deg,rgba(5,8,23,.98)_0%,rgba(5,8,23,.78)_68%,rgba(5,8,23,.3))]" />
      <AnimatePresence mode="wait">
        <m.div
          key={game.id}
          className="relative z-2 flex min-h-120 w-[min(720px,67%)] flex-col justify-center px-[clamp(32px,6vw,88px)] py-15 max-md:min-h-125 max-md:w-full max-md:justify-end max-md:px-6.5 max-md:pt-10 max-md:pb-19 max-sm:min-h-135"
          initial={{ opacity: 0, x: 22 }}
          animate={{ opacity: 1, x: 0 }}
          exit={{ opacity: 0, x: -18 }}
          transition={{ duration: 0.28 }}
        >
          <span className="inline-flex items-center gap-2 text-xs font-extrabold tracking-widest text-cyan-300 uppercase"><LuSparkles aria-hidden /> Selección destacada</span>
          <h1 className="my-4 text-[clamp(2.75rem,5.4vw,5.2rem)] leading-[.98] font-black tracking-[-0.065em] max-md:text-[clamp(2.5rem,12vw,4.1rem)]">{game.name}</h1>
          <p className="m-0 line-clamp-3 max-w-2xl leading-relaxed text-slate-300">{game.description}</p>
          <div className="mt-5.5 flex flex-wrap items-center gap-2">
            <strong className="mr-2 text-2xl">{formatPrice(game.price)}</strong>
            <span className="rounded-full border border-white/10 bg-white/10 px-2.5 py-1.5 text-xs text-slate-200">{game.studio}</span>
            {game.categories?.slice(0, 2).map((category) => <span className="rounded-full border border-white/10 bg-white/10 px-2.5 py-1.5 text-xs text-slate-200" key={category.id}>{category.name}</span>)}
          </div>
          <div className="mt-7 flex flex-wrap gap-2.5 max-sm:[&>*]:w-full">
            <Link className={buttonClasses({ size: "large" })} href={`/games/${game.id}`}>Conocer el juego</Link>
            {isUser && !owned && !added && game.available && (
              <Button size="large" variant="glass" onClick={handleAdd} loading={adding}>
                <LuShoppingCart aria-hidden /> Agregar al carrito
              </Button>
            )}
            {isUser && (owned || added) && (
              <Link className={buttonClasses({ variant: "glass", size: "large" })} href={owned ? "/library" : "/cart"}>
                {owned ? "Ver en biblioteca" : "Ver carrito"}
              </Link>
            )}
          </div>
        </m.div>
      </AnimatePresence>

      {games.length > 1 && (
        <>
          <div className="absolute right-7.5 bottom-7 z-3 flex gap-2 max-md:right-5.5 max-md:bottom-6">
            <button className="inline-flex size-10.5 items-center justify-center rounded-full border border-white/15 bg-white/10 text-white backdrop-blur-xl hover:bg-white/20" type="button" onClick={() => move(-1)} aria-label="Destacado anterior"><LuArrowLeft aria-hidden /></button>
            <button className="inline-flex size-10.5 items-center justify-center rounded-full border border-white/15 bg-white/10 text-white backdrop-blur-xl hover:bg-white/20" type="button" onClick={() => move(1)} aria-label="Destacado siguiente"><LuArrowRight aria-hidden /></button>
          </div>
          <div className="absolute bottom-9.5 left-1/2 z-3 flex -translate-x-1/2 gap-1.5 max-md:left-6.5 max-md:translate-x-0">
            {games.map((item, dotIndex) => (
              <button
                type="button"
                className={dotIndex === index ? "h-1.5 w-6.5 rounded-full border-0 bg-cyan-300 p-0" : "size-1.5 rounded-full border-0 bg-white/35 p-0"}
                key={item.id}
                onClick={() => setIndex(dotIndex)}
                aria-label={`Ver destacado ${dotIndex + 1}: ${item.name}`}
              />
            ))}
          </div>
        </>
      )}
      </section>
    </NeonFrame>
  );
}
