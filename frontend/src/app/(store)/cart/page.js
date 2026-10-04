"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { LuArrowRight, LuLibrary, LuShieldCheck, LuShoppingCart, LuTrash2 } from "react-icons/lu";
import GameArtwork from "@/components/games/GameArtwork";
import Button, { buttonClasses } from "@/components/ui/Button";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import EmptyState from "@/components/ui/EmptyState";
import LoadingState from "@/components/ui/LoadingState";
import { useStore } from "@/context/StoreContext";
import { useToast } from "@/context/ToastContext";
import { useGames } from "@/hooks/useCatalog";
import { formatPrice, mergeGames } from "@/lib/games";

const EMPTY_GAMES = [];

/**
 * Presenta la página del carrito de compras. 
 * @returns {JSX.Element} página renderizada del carrito
 */
export default function CartPage() {
  const router = useRouter();
  const { cart, loading: storeLoading, removeFromCart, checkout } = useStore();
  const { notify } = useToast();
  const gamesQuery = useGames();
  const games = gamesQuery.data || EMPTY_GAMES;
  const [removing, setRemoving] = useState(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [checkingOut, setCheckingOut] = useState(false);

  const items = useMemo(() => mergeGames(cart, games), [cart, games]);
  const total = items.reduce((sum, item) => sum + Number(item.price), 0);

  /**
   * Elimina un videojuego del carrito.
   * @param {number} gameId identificador del videojuego
   * @returns {Promise<void>} promesa que representa la operación de eliminación
   */
  const handleRemove = async (gameId) => {
    setRemoving(gameId);
    let actionError = null;
    try {
      await removeFromCart(gameId);
    } catch (error) {
      actionError = error;
    }
    setRemoving(null);
    if (actionError) notify(actionError.message, "error");
  };

  /**
   * Confirma la compra de los juegos del carrito y redirige a la biblioteca.
   * @returns {Promise<void>} promesa que representa la operación de compra
   */

  const handleCheckout = async () => {
    setCheckingOut(true);
    let actionError = null;
    try {
      await checkout();
    } catch (error) {
      actionError = error;
    }
    setCheckingOut(false);
    if (actionError) {
      notify(actionError.message, "error");
      return;
    }
    setDialogOpen(false);
    router.push("/library");
  };

  if (storeLoading || gamesQuery.isPending) return <LoadingState label="Preparando tu carrito..." />;

  if (!items.length) {
    return (
      <div className="grid gap-8.5">
        <div><span className="text-xs font-extrabold tracking-widest text-brand-blue uppercase">Tu selección</span><h1 className="mt-1.5 text-[clamp(2.15rem,4vw,3.45rem)] leading-none font-black tracking-[-0.06em]">Carrito</h1></div>
        <EmptyState
          icon={LuShoppingCart}
          title="Tu carrito está vacío"
          description="Explorá el catálogo y agregá los juegos que querés sumar a tu biblioteca."
          action={<Link className={buttonClasses()} href="/catalog">Explorar juegos <LuArrowRight aria-hidden /></Link>}
        />
      </div>
    );
  }

  return (
    <div className="grid gap-8.5">
      <div>
        <span className="text-xs font-extrabold tracking-widest text-brand-blue uppercase">Tu selección</span>
        <h1 className="mt-1.5 text-[clamp(2.15rem,4vw,3.45rem)] leading-none font-black tracking-[-0.06em]">Carrito</h1>
        <p className="mt-3 max-w-2xl text-sm leading-relaxed text-copy-soft">Revisá los títulos antes de confirmar. No se procesa ningún pago en esta etapa.</p>
      </div>

      <div className="grid grid-cols-[minmax(0,1fr)_360px] items-start gap-6.5 max-lg:grid-cols-[minmax(0,1fr)_320px] max-md:grid-cols-1">
        <section className="grid gap-3" aria-label="Juegos en el carrito">
          {items.map((item) => (
            <article className="grid grid-cols-[92px_minmax(0,1fr)_auto_auto] items-center gap-5 rounded-2xl border border-line bg-panel p-4 shadow-card max-sm:grid-cols-[72px_minmax(0,1fr)] max-sm:gap-3" key={item.gameId}>
              <GameArtwork className="aspect-2/3 w-full rounded-xl" game={item} />
              <div className="min-w-0">
                <span className="text-[.68rem] font-extrabold tracking-widest text-copy-faint uppercase">{item.studio || "PlayHub"}</span>
                <h2 className="mt-1 truncate text-lg font-extrabold tracking-tight">{item.name}</h2>
                <p className="mt-1 line-clamp-2 text-sm leading-relaxed text-copy-soft">{item.description || `Estado: ${item.status}`}</p>
              </div>
              <strong className="text-base max-sm:col-start-2">{formatPrice(item.price)}</strong>
              <Button
                variant="danger-ghost"
                className="max-sm:col-start-2 max-sm:justify-self-start"
                loading={removing === item.gameId}
                onClick={() => handleRemove(item.gameId)}
                aria-label={`Quitar ${item.name} del carrito`}
              >
                <LuTrash2 aria-hidden /> Quitar
              </Button>
            </article>
          ))}
        </section>

        <aside className="sticky top-26 rounded-3xl bg-ink-900 p-7 text-white shadow-float max-md:static">
          <span className="text-xs font-extrabold tracking-widest text-brand-cyan uppercase">Resumen</span>
          <h2 className="mt-2 mb-6 text-2xl font-extrabold tracking-tight">Tu pedido</h2>
          <div className="flex justify-between border-b border-white/10 py-3 text-sm text-slate-300"><span>Juegos</span><strong className="text-white">{items.length}</strong></div>
          <div className="flex items-end justify-between py-4"><span className="text-sm text-slate-300">Total referencial</span><strong className="text-2xl">{formatPrice(total)}</strong></div>
          <div className="mb-5 flex gap-3 rounded-2xl bg-white/8 p-4 text-sm leading-relaxed text-slate-300"><LuShieldCheck className="mt-0.5 size-5 shrink-0 text-brand-cyan" aria-hidden /><p>Al confirmar, los juegos se incorporan inmediatamente a tu biblioteca.</p></div>
          <Button size="large" className="w-full" onClick={() => setDialogOpen(true)}>
            Confirmar selección <LuArrowRight aria-hidden />
          </Button>
        </aside>
      </div>

      <ConfirmDialog
        open={dialogOpen}
        onClose={() => setDialogOpen(false)}
        onConfirm={handleCheckout}
        loading={checkingOut}
        title="¿Agregar estos juegos a tu biblioteca?"
        description="Esta confirmación vaciará el carrito y registrará todos los títulos como parte de tu biblioteca personal."
        confirmLabel="Sí, confirmar"
      >
        <div className="mt-5 flex items-center gap-3 rounded-2xl border border-line bg-panel-soft p-4 text-sm"><LuLibrary className="size-5 text-brand-cyan" aria-hidden /><span className="flex-1">{items.length} {items.length === 1 ? "juego" : "juegos"}</span><strong>{formatPrice(total)}</strong></div>
      </ConfirmDialog>
    </div>
  );
}
