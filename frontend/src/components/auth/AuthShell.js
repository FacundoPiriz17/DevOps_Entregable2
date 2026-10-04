import { LuBadgeCheck, LuGamepad2, LuLibrary, LuSparkles } from "react-icons/lu";
import * as m from "motion/react-m";
import Brand from "@/components/brand/Brand";

/**
 * Presenta la estructura visual compartida de las páginas de autenticación.
 * @param {Object} props propiedades del componente 
 * @param {string} props.title título principal del formulario
 * @param {string} props.subtitle descripción complementaria del formulario
 * @param {React.ReactNode} props.children contenido principal de autenticación 
 */
export default function AuthShell({ title, subtitle, children }) {
  return (
    <main className="grid min-h-dvh bg-surface lg:grid-cols-[minmax(0,1.08fr)_minmax(480px,.92fr)]">
      <m.aside
        className="relative hidden min-h-dvh flex-col justify-between overflow-hidden bg-[radial-gradient(circle_at_20%_20%,rgba(0,189,248,.18),transparent_28%),radial-gradient(circle_at_80%_78%,rgba(125,27,255,.24),transparent_35%),linear-gradient(145deg,#050817_0%,#0b1130_54%,#121a3d_100%)] px-[clamp(40px,5vw,82px)] py-12 text-white lg:flex"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.4 }}
      >
        <div className="pointer-events-none absolute top-[10%] -right-40 size-105 rounded-full bg-brand-cyan/12 blur-2xl" />
        <div className="pointer-events-none absolute -bottom-45 -left-45 size-117 rounded-full bg-brand-violet/15 blur-2xl" />
        <Brand
          className="relative z-10 w-fit gap-3 rounded-2xl px-1 py-0.5 drop-shadow-[0_0_14px_rgba(255,255,255,0.14)] transition duration-300 hover:drop-shadow-[0_0_20px_rgba(255,255,255,0.2)] [&>span:first-child]:size-16 [&>span:first-child]:overflow-visible [&>span:first-child]:rounded-none [&>span:first-child]:border-0 [&>span:first-child]:bg-transparent [&>span:first-child>img]:size-16 [&>span:nth-child(2)]:text-[2rem]"
          href="/login"
        />

        <m.div className="relative z-10 max-w-2xl" initial={{ opacity: 0, y: 24 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.12 }}>
          <span className="inline-flex items-center gap-2 text-xs font-extrabold tracking-[0.1em] text-cyan-300 uppercase"><LuSparkles aria-hidden /> Tu próxima aventura empieza acá</span>
          <h1 className="my-5 text-[clamp(3.1rem,5.1vw,5.8rem)] leading-[.98] font-black tracking-[-0.065em]">Todos tus juegos.<br /><span className="text-brand">Un solo lugar.</span></h1>
          <p className="max-w-xl text-[clamp(1rem,1.4vw,1.22rem)] leading-relaxed text-slate-300">Explorá el catálogo, armá tu colección y guardá los títulos que querés jugar después.</p>
        </m.div>

        <div className="relative z-10 grid gap-3 xl:grid-cols-3">
          <div className="flex min-h-17 items-center gap-2.5 rounded-2xl border border-white/10 bg-white/6 p-3 backdrop-blur-lg"><LuGamepad2 className="size-6 shrink-0 text-cyan-300" aria-hidden /><span className="flex flex-col text-xs text-slate-300"><strong className="text-sm text-white">Descubrí</strong> nuevos mundos</span></div>
          <div className="flex min-h-17 items-center gap-2.5 rounded-2xl border border-white/10 bg-white/6 p-3 backdrop-blur-lg"><LuLibrary className="size-6 shrink-0 text-cyan-300" aria-hidden /><span className="flex flex-col text-xs text-slate-300"><strong className="text-sm text-white">Organizá</strong> tu biblioteca</span></div>
          <div className="flex min-h-17 items-center gap-2.5 rounded-2xl border border-white/10 bg-white/6 p-3 backdrop-blur-lg max-xl:hidden"><LuBadgeCheck className="size-6 shrink-0 text-cyan-300" aria-hidden /><span className="flex flex-col text-xs text-slate-300"><strong className="text-sm text-white">Elegí</strong> con confianza</span></div>
        </div>
      </m.aside>

      <section className="flex min-h-dvh flex-col justify-between border-l border-white/7 bg-[radial-gradient(circle_at_100%_0%,rgba(0,189,248,.1),transparent_30%),linear-gradient(160deg,#0d1429,#080d1e)] px-[clamp(20px,5vw,78px)] py-7 lg:py-10">
        <Brand
          className="self-start rounded-xl drop-shadow-[0_0_11px_rgba(255,255,255,0.12)] [&>span:first-child]:overflow-visible [&>span:first-child]:border-0 [&>span:first-child]:bg-transparent [&>span:nth-child(2)]:text-copy"
          href="/login"
        />
        <m.div className="mx-auto my-9 w-full max-w-xl" initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} transition={{ duration: 0.35 }}>
          <span className="text-xs font-extrabold tracking-[0.1em] text-brand-blue uppercase">Bienvenido a PlayHub</span>
          <h2 className="mt-3 mb-2.5 text-[clamp(2.1rem,3.3vw,3rem)] leading-none font-black tracking-[-0.055em] text-copy">{title}</h2>
          <p className="leading-relaxed text-copy-soft">{subtitle}</p>
          <div className="mt-8.5">{children}</div>
        </m.div>
        <p className="m-0 text-center text-xs text-copy-faint">PlayHub · Tu colección, a tu manera.</p>
      </section>
    </main>
  );
}
