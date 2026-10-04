"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { AnimatePresence } from "motion/react";
import * as m from "motion/react-m";
import {
  LuChevronDown,
  LuHeart,
  LuLibrary,
  LuLogOut,
  LuMenu,
  LuShieldCheck,
  LuShoppingCart,
  LuStore,
  LuUserRound,
  LuX,
} from "react-icons/lu";
import Brand from "@/components/brand/Brand";
import LoadingState from "@/components/ui/LoadingState";
import { useAuth } from "@/context/AuthContext";
import { useStore } from "@/context/StoreContext";
import { cn } from "@/lib/cn";

const baseLink = { href: "/catalog", label: "Tienda", icon: LuStore };
const userLinks = [
  { href: "/library", label: "Biblioteca", icon: LuLibrary },
  { href: "/wishlist", label: "Deseados", icon: LuHeart },
  { href: "/cart", label: "Carrito", icon: LuShoppingCart, count: "cart" },
];

/**
 * Presenta la estructura principal de la aplicación con navegación, perfil y contenido.
 * @param {Object} props propiedades del componente
 * @param {React.ReactNode} props.children contenido principal de la aplicación
 * @returns {JSX.Element} estructura principal de la aplicación renderizada 
 */
export default function AppShell({ children }) {
  const pathname = usePathname();
  const { authenticated, ready, user, isUser, isAdmin, logout } = useAuth();
  const { cart } = useStore();
  const [mobileOpen, setMobileOpen] = useState(false);
  const [profileOpen, setProfileOpen] = useState(false);

  if (!ready || !authenticated) return <LoadingState label="Preparando tu espacio..." />;

  const links = isUser ? [baseLink, ...userLinks] : [baseLink];

  return (
    <div className="min-h-dvh">
      <header className="sticky top-0 z-100 bg-ink-950/96 text-white shadow-[0_8px_30px_rgba(5,8,23,.17)] backdrop-blur-xl">
        <div className="mx-auto flex h-18.5 max-w-375 items-center gap-7.5 px-7 max-md:h-17 max-md:px-4.5">
          <Brand />

          <nav className={cn(
            "ml-7 flex items-center gap-1 max-lg:ml-0 max-md:absolute max-md:top-17 max-md:right-0 max-md:left-0 max-md:hidden max-md:flex-col max-md:items-stretch max-md:border-t max-md:border-white/10 max-md:bg-ink-900 max-md:p-4",
            mobileOpen && "max-md:flex",
          )} aria-label="Navegación principal">
            {links.map(({ href, label, icon: Icon, count }) => {
              const active = pathname === href
                || (href === "/catalog" && pathname.startsWith("/games"))
                || (href !== "/catalog" && pathname.startsWith(href));
              return (
                <Link
                  className={cn(
                    "inline-flex min-h-10.5 items-center gap-2 rounded-xl px-3 text-sm font-semibold text-slate-400 transition hover:bg-white/8 hover:text-white focus-visible:outline-3 focus-visible:outline-brand-cyan/30 max-lg:[&>span:not(.nav-count)]:hidden max-md:[&>span:not(.nav-count)]:inline",
                    active && "bg-white/8 text-white shadow-[inset_0_-2px_0_#5fdcff]",
                  )}
                  href={href}
                  key={href}
                  onClick={() => setMobileOpen(false)}
                >
                  <Icon className="size-4.5" aria-hidden />
                  <span>{label}</span>
                  {count === "cart" && cart.length > 0 && <span className="nav-count bg-brand inline-flex h-5 min-w-5 items-center justify-center rounded-full px-1.5 text-[.65rem] text-white">{cart.length}</span>}
                </Link>
              );
            })}
          </nav>

          <div className="ml-auto flex items-center gap-2">
            <div className="relative">
              <button
                type="button"
                className="flex min-h-12 items-center gap-2.5 rounded-2xl border border-white/10 bg-white/6 p-1.5 pr-3 text-white max-md:border-0 max-md:p-1"
                onClick={() => setProfileOpen((current) => !current)}
                aria-expanded={profileOpen}
              >
                <span className="bg-brand inline-flex size-9 items-center justify-center rounded-xl text-sm font-black">{user?.name?.slice(0, 1).toUpperCase()}</span>
                <span className="flex max-w-32 flex-col text-left max-md:hidden">
                  <strong className="truncate text-xs">{user?.name}</strong>
                  <small className="text-[.65rem] text-slate-400">{isAdmin ? "Administrador" : "Jugador"}</small>
                </span>
                <LuChevronDown className="size-4 text-slate-400 max-md:hidden" aria-hidden />
              </button>

              <AnimatePresence>
                {profileOpen && (
                  <m.div
                    className="absolute top-[calc(100%+10px)] right-0 min-w-68 overflow-hidden rounded-2xl border border-line bg-panel p-2 text-copy shadow-float"
                    initial={{ opacity: 0, y: 8, scale: 0.98 }}
                    animate={{ opacity: 1, y: 0, scale: 1 }}
                    exit={{ opacity: 0, y: 6, scale: 0.98 }}
                  >
                    <div className="flex items-center gap-2.5 p-2.5">
                      <LuUserRound className="size-9.5 rounded-xl bg-indigo-400/10 p-2 text-brand-cyan" aria-hidden />
                      <span className="flex min-w-0 flex-col"><strong className="truncate text-sm">{user?.name}</strong><small className="truncate text-xs text-copy-faint">{user?.email}</small></span>
                    </div>
                    <div className="mx-1.5 mb-2 flex items-center gap-1.5 rounded-lg bg-panel-soft p-2 text-xs font-bold text-copy-soft"><LuShieldCheck aria-hidden /> {user?.role}</div>
                    <button className="flex w-full items-center gap-2 rounded-lg border-0 bg-transparent p-2.5 text-sm font-semibold text-rose-300 hover:bg-rose-400/10" type="button" onClick={logout}><LuLogOut aria-hidden /> Cerrar sesión</button>
                  </m.div>
                )}
              </AnimatePresence>
            </div>

            <button
              className="hidden size-10.5 items-center justify-center rounded-xl border-0 bg-white/8 text-white max-md:inline-flex"
              type="button"
              onClick={() => setMobileOpen((current) => !current)}
              aria-label={mobileOpen ? "Cerrar menú" : "Abrir menú"}
            >
              {mobileOpen ? <LuX aria-hidden /> : <LuMenu aria-hidden />}
            </button>
          </div>
        </div>
      </header>

      {isAdmin && (
        <div className="flex items-center justify-center gap-2 border-b border-blue-400/20 bg-blue-400/10 px-6 py-2.5 text-center text-xs font-semibold text-blue-200">
          <LuShieldCheck aria-hidden />
          Estás usando una cuenta administradora. En esta etapa podés consultar el catálogo; la gestión se incorporará en el siguiente módulo.
        </div>
      )}

      <main className="mx-auto min-h-[calc(100dvh-190px)] max-w-375 px-7 pt-8.5 pb-18 max-md:px-4.5 max-md:pt-6.5 max-md:pb-14">{children}</main>

      <footer className="flex min-h-27 items-center justify-center gap-6 bg-ink-950 p-6 text-slate-400 max-sm:flex-col max-sm:gap-2.5">
        <Brand className="[&>span:first-child]:size-9 [&>span:first-child>img]:size-8.5 [&>span:nth-child(2)]:text-xl" href={null} />
        <p className="m-0 text-xs">Tu colección, a tu manera.</p>
        <span className="border-l border-slate-700 pl-6 text-xs max-sm:border-l-0 max-sm:pl-0">© 2026 PlayHub</span>
      </footer>
    </div>
  );
}
