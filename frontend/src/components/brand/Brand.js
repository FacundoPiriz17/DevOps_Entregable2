import Image from "next/image";
import Link from "next/link";
import { cn } from "@/lib/cn";

/**
 * Presenta la identidad visual de PlayHub con opción de enlace y formato compacto.
 * @param {Object} props propiedades del componente
 * @param {string} [props.href="/catalog"] ruta de destino del enlace
 * @param {boolean} [props.compact=false] indica si solo se muestra el logotipo
 * @param {string} [props.className=""] clases CSS adicionales
 * @returns {JSX.Element} identidad visual de PlayHub renderizada 
 */
export default function Brand({ href = "/catalog", compact = false, className = "" }) {
  const content = (
    <>
      <span className="flex size-11.5 items-center justify-center overflow-hidden rounded-[14px] border border-white/10 bg-white/8">
        <Image className="size-11 object-contain" src="/playhub-mark.png" alt="" width={64} height={64} priority />
      </span>
      {!compact && (
        <span className="text-[1.55rem] leading-none font-black tracking-[-0.065em] text-white" aria-label="PlayHub">
          <span>Play</span><span className="text-brand">Hub</span>
        </span>
      )}
    </>
  );

  const classes = cn("inline-flex shrink-0 items-center gap-2.5", className);
  if (!href) return <span className={classes}>{content}</span>;
  return <Link className={classes} href={href}>{content}</Link>;
}
