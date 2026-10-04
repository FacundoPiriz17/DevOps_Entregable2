"use client";

import { useEffect, useMemo, useState } from "react";
import { LuGamepad2, LuSearch, LuSlidersHorizontal } from "react-icons/lu";
import FeaturedCarousel from "@/components/games/FeaturedCarousel";
import GameCard from "@/components/games/GameCard";
import EmptyState from "@/components/ui/EmptyState";
import LoadingState from "@/components/ui/LoadingState";
import { useAuth } from "@/context/AuthContext";
import { useCategories, useGames } from "@/hooks/useCatalog";
import { pickRandomGames } from "@/lib/games";

const EMPTY_GAMES = [];
const EMPTY_CATEGORIES = [];

/**
 * Presenta el catálogo de videojuegos con búsqueda, filtros y ordenamiento.
 * @returns {JSX.Element} página renderizada del catálogo
 */
export default function CatalogPage() {
  const { user } = useAuth();
  const gamesQuery = useGames();
  const categoriesQuery = useCategories();
  const games = gamesQuery.data || EMPTY_GAMES;
  const categories = categoriesQuery.data || EMPTY_CATEGORIES;
  const [featured, setFeatured] = useState([]);
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState("all");
  const [sort, setSort] = useState("featured");

  useEffect(() => {
    if (!games.length) return undefined;
    const timer = window.setTimeout(() => {
      setFeatured(pickRandomGames(games.filter((game) => game.available), 5));
    }, 0);
    return () => window.clearTimeout(timer);
  }, [games]);

  const visibleGames = useMemo(() => {
    const normalizedQuery = query.trim().toLocaleLowerCase("es");
    const filtered = games.filter((game) => {
      const matchesText = !normalizedQuery || [game.name, game.description, game.studio]
        .some((value) => value?.toLocaleLowerCase("es").includes(normalizedQuery));
      const matchesCategory = category === "all" || game.categories?.some((item) => String(item.id) === category);
      return matchesText && matchesCategory;
    });

    const compareGames = (first, second) => {
      if (sort === "name") return first.name.localeCompare(second.name, "es");
      if (sort === "price-low") return Number(first.price) - Number(second.price);
      if (sort === "price-high") return Number(second.price) - Number(first.price);
      if (sort === "newest") return String(second.releaseDate).localeCompare(String(first.releaseDate));
      return Number(second.available) - Number(first.available);
    };

    return typeof filtered.toSorted === "function"
      ? filtered.toSorted(compareGames)
      : filtered.slice().sort(compareGames);
  }, [games, query, category, sort]);

  if (gamesQuery.isPending || categoriesQuery.isPending) return <LoadingState label="Buscando grandes juegos..." />;

  if (gamesQuery.isError || categoriesQuery.isError) {
    const error = gamesQuery.error || categoriesQuery.error;
    return <EmptyState icon={LuGamepad2} title="No pudimos cargar el catálogo" description={error.message} />;
  }

  return (
    <div className="grid gap-8.5">
      <section className="flex items-end justify-between max-sm:flex-col max-sm:items-start max-sm:gap-2.5">
        <div>
          <span className="text-xs font-extrabold tracking-widest text-brand-blue uppercase">Hola, {user?.name?.split(" ")[0]}</span>
          <h1 className="mt-2 text-[clamp(2.15rem,4vw,3.45rem)] leading-none font-black tracking-[-0.06em] text-copy">¿Qué vas a jugar hoy?</h1>
        </div>
        <p className="mb-1 text-sm text-copy-faint">{games.length} títulos esperan en el catálogo</p>
      </section>

      <FeaturedCarousel games={featured} />

      <section className="grid gap-6">
        <div className="flex items-end justify-between max-sm:flex-col max-sm:items-start max-sm:gap-2">
          <div>
            <span className="text-xs font-extrabold tracking-widest text-brand-blue uppercase">Explorar</span>
            <h2 className="mt-1.5 text-[clamp(1.7rem,3vw,2.45rem)] font-black tracking-tight">Catálogo de juegos</h2>
          </div>
          <span className="text-xs text-copy-faint">{visibleGames.length} resultados</span>
        </div>

        <div className="grid grid-cols-[minmax(280px,1fr)_auto_auto] items-center gap-3 rounded-2xl border border-line bg-panel p-3 shadow-card max-md:grid-cols-2 max-sm:grid-cols-1">
          <label className="flex min-h-11 items-center rounded-xl bg-panel-soft px-3 text-copy-faint focus-within:outline-3 focus-within:outline-brand-cyan/20 max-md:col-span-2 max-sm:col-span-1">
            <LuSearch className="size-4.5 shrink-0" aria-hidden />
            <input
              className="min-w-0 flex-1 border-0 bg-transparent px-2.5 text-copy outline-0"
              type="search"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Buscar por juego, estudio o descripción..."
              aria-label="Buscar juegos"
            />
          </label>
          <label className="flex min-h-11 items-center rounded-xl bg-panel-soft px-3 text-copy-faint focus-within:outline-3 focus-within:outline-brand-cyan/20">
            <LuSlidersHorizontal className="size-4.5 shrink-0" aria-hidden />
            <select className="min-w-42 border-0 bg-transparent px-2 text-copy outline-0 max-sm:min-w-0 max-sm:flex-1" value={category} onChange={(event) => setCategory(event.target.value)} aria-label="Filtrar por categoría">
              <option value="all">Todas las categorías</option>
              {categories.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
            </select>
          </label>
          <label className="flex min-h-11 items-center rounded-xl bg-panel-soft px-3 text-copy-faint focus-within:outline-3 focus-within:outline-brand-cyan/20">
            <select className="min-w-42 border-0 bg-transparent px-2 text-copy outline-0 max-sm:min-w-0 max-sm:flex-1" value={sort} onChange={(event) => setSort(event.target.value)} aria-label="Ordenar catálogo">
              <option value="featured">Destacados primero</option>
              <option value="name">Nombre A–Z</option>
              <option value="price-low">Menor precio</option>
              <option value="price-high">Mayor precio</option>
              <option value="newest">Más recientes</option>
            </select>
          </label>
        </div>

        {visibleGames.length ? (
          <div className="grid grid-cols-4 gap-5.5 max-xl:grid-cols-3 max-md:grid-cols-2 max-sm:grid-cols-1">
            {visibleGames.map((game) => <GameCard game={game} key={game.id} />)}
          </div>
        ) : (
          <EmptyState
            icon={LuGamepad2}
            title="No encontramos juegos"
            description="Probá cambiando la búsqueda o quitando alguno de los filtros."
          />
        )}
      </section>
    </div>
  );
}
