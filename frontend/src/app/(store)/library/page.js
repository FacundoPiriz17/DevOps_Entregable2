"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { LuArrowRight, LuHeart, LuLibrary, LuSearch, LuStar } from "react-icons/lu";
import GameArtwork from "@/components/games/GameArtwork";
import Button, { buttonClasses } from "@/components/ui/Button";
import EmptyState from "@/components/ui/EmptyState";
import LoadingState from "@/components/ui/LoadingState";
import { useStore } from "@/context/StoreContext";
import { useToast } from "@/context/ToastContext";
import { useGames } from "@/hooks/useCatalog";
import { formatDate, mergeGames } from "@/lib/games";

const EMPTY_GAMES = [];

/**
 * Presenta la biblioteca de videojuegos del usuario.
 * @returns {JSX.Element} página renderizada de la biblioteca
 */
export default function LibraryPage() {
  const { library, loading: storeLoading, toggleFavorite } = useStore();
  const { notify } = useToast();
  const gamesQuery = useGames();
  const games = gamesQuery.data || EMPTY_GAMES;
  const [query, setQuery] = useState("");
  const [favoritesOnly, setFavoritesOnly] = useState(false);
  const [updating, setUpdating] = useState(null);

  const entries = useMemo(() => {
    const normalized = query.toLocaleLowerCase("es").trim();
    return mergeGames(library, games).filter((item) => {
      const matchesText = !normalized || item.name.toLocaleLowerCase("es").includes(normalized)
        || item.studio?.toLocaleLowerCase("es").includes(normalized);
      return matchesText && (!favoritesOnly || item.favorite);
    });
  }, [library, games, query, favoritesOnly]);

  /**
   * Cambia el estado de favorito de un videojuego.
   * @param {number} gameId identificador del videojuego
   * @returns {Promise<void>} promesa que representa la actualización
   */
  const handleFavorite = async (gameId) => {
    setUpdating(gameId);
    let actionError = null;
    try {
      await toggleFavorite(gameId);
    } catch (error) {
      actionError = error;
    }
    setUpdating(null);
    if (actionError) notify(actionError.message, "error");
  };

  if (storeLoading || gamesQuery.isPending) return <LoadingState label="Ordenando tu biblioteca..." />;

  return (
    <div className="grid gap-8.5">
      <div className="flex items-end justify-between gap-5 max-sm:flex-col max-sm:items-start">
        <div><span className="text-xs font-extrabold tracking-widest text-brand-blue uppercase">Tu colección</span><h1 className="mt-1.5 text-[clamp(2.15rem,4vw,3.45rem)] leading-none font-black tracking-[-0.06em]">Biblioteca</h1><p className="mt-3 text-sm text-copy-soft">{library.length} títulos forman parte de tu cuenta.</p></div>
        {library.length > 0 && <div className="flex items-center gap-2 rounded-full border border-line bg-panel px-4 py-2 shadow-card"><LuLibrary className="text-brand-cyan" aria-hidden /><strong>{library.length}</strong><span className="text-xs text-copy-faint">juegos</span></div>}
      </div>

      {!library.length ? (
        <EmptyState
          icon={LuLibrary}
          title="Tu biblioteca está esperando"
          description="Los juegos aparecen acá inmediatamente después de confirmar el carrito."
          action={<Link className={buttonClasses()} href="/catalog">Explorar catálogo <LuArrowRight aria-hidden /></Link>}
        />
      ) : (
        <>
          <div className="flex gap-3 max-sm:flex-col">
            <label className="flex min-h-11 flex-1 items-center rounded-xl border border-line bg-panel px-3 text-copy-faint focus-within:outline-3 focus-within:outline-brand-cyan/20"><LuSearch className="size-4.5" aria-hidden /><input className="min-w-0 flex-1 border-0 bg-transparent px-2.5 text-copy outline-0 placeholder:text-copy-faint" type="search" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Buscar en mi biblioteca..." /></label>
            <Button variant={favoritesOnly ? "secondary" : "ghost"} onClick={() => setFavoritesOnly((current) => !current)}>
              <LuHeart aria-hidden /> {favoritesOnly ? "Mostrando favoritos" : "Solo favoritos"}
            </Button>
          </div>

          {entries.length ? (
            <div className="grid grid-cols-2 gap-5 max-lg:grid-cols-1">
              {entries.map((item) => (
                <article className="grid grid-cols-[150px_minmax(0,1fr)] overflow-hidden rounded-2xl border border-line bg-panel shadow-card max-sm:grid-cols-[105px_minmax(0,1fr)]" key={item.gameId}>
                  <GameArtwork className="h-full min-h-62.5 w-full" game={item} />
                  <div className="flex min-w-0 flex-col p-5 max-sm:p-4">
                    <span className="text-[.68rem] font-extrabold tracking-widest text-copy-faint uppercase">{item.studio}</span>
                    <h2 className="mt-1 text-xl font-extrabold tracking-tight">{item.name}</h2>
                    <p className="mt-2 line-clamp-3 text-sm leading-relaxed text-copy-soft">{item.description}</p>
                    <small className="mt-3 text-xs text-copy-faint">En tu biblioteca desde {formatDate(item.purchasedAt)}</small>
                    <div className="mt-auto flex flex-wrap gap-2 pt-5">
                      <Link className={buttonClasses({ variant: "ghost" })} href={`/games/${item.gameId}`}>Ver detalles</Link>
                      <Button
                        variant={item.favorite ? "favorite" : "secondary"}
                        loading={updating === item.gameId}
                        onClick={() => handleFavorite(item.gameId)}
                      >
                        <LuStar aria-hidden /> {item.favorite ? "Favorito" : "Marcar favorito"}
                      </Button>
                    </div>
                  </div>
                </article>
              ))}
            </div>
          ) : (
            <EmptyState icon={LuSearch} title="No hay coincidencias" description="Probá con otro término o mostr&aacute; todos los juegos." />
          )}
        </>
      )}
    </div>
  );
}
