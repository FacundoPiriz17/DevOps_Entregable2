import { LuLoaderCircle } from "react-icons/lu";
import { cn } from "@/lib/cn";

const variants = {
  primary: "bg-brand text-white shadow-[0_10px_24px_rgba(44,91,255,0.24)] hover:shadow-[0_14px_30px_rgba(90,11,212,0.3)]",
  secondary: "border border-indigo-400/20 bg-indigo-400/12 text-indigo-200 hover:bg-indigo-400/20",
  ghost: "border border-line bg-transparent text-copy-soft hover:bg-white/7 hover:text-copy",
  glass: "border border-white/25 bg-white/10 text-white backdrop-blur-xl hover:bg-white/20",
  success: "border border-emerald-400/20 bg-emerald-400/12 text-emerald-200 hover:bg-emerald-400/20",
  favorite: "border border-amber-400/20 bg-amber-400/12 text-amber-200 hover:bg-amber-400/20",
  "danger-ghost": "border border-rose-400/15 bg-rose-400/10 text-rose-300 hover:bg-rose-400/18",
};

const sizes = {
  medium: "min-h-10.5 px-4 text-sm",
  large: "min-h-12.5 px-5 text-base",
};

/**
 * Genera las clases CSS para un botón según su variante y tamaño.
 * @param {Object} [options={}] opciones de configuración del botón 
 * @param {string} [options.variant="primary"] variante visual del botón
 * @param {string} [options.size="medium"] tamaño del botón
 * @param {string} [options.className] clases CSS adicionales
 * @returns {string} clases CSS combinadas para el botón
 */
export function buttonClasses({ variant = "primary", size = "medium", className } = {}) {
  return cn(
    "inline-flex items-center justify-center gap-2 rounded-xl border-0 font-semibold leading-none transition duration-200 hover:-translate-y-0.5 focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-brand-cyan/30 disabled:cursor-not-allowed disabled:opacity-55 disabled:hover:translate-y-0 [&_svg]:size-4.5",
    variants[variant],
    sizes[size],
    className,
  );
}
/**
 * Presenta un botón con variantes visuales y estado de carga.
 * @param {Object} props propiedades del componente
 * @param {React.ReactNode} props.children contenido mostrado dentro del botón
 * @param {string} [props.variant="primary"] variante visual del botón
 * @param {string} [props.size="medium"] tamaño del botón
 * @param {boolean} [props.loading=false] indica si el botón está procesando una operación
 * @param {string} [props.className=""] clases CSS adicionales
 * @param {boolean} [props.disabled] indica si el botón está deshabilitado
 * @returns {JSX.Element} botón renderizado
 */
export default function Button({
  children,
  variant = "primary",
  size = "medium",
  loading = false,
  className = "",
  disabled,
  ...props
}) {
  return (
    <button
      className={buttonClasses({ variant, size, className })}
      disabled={disabled || loading}
      {...props}
    >
      {loading && <LuLoaderCircle className="animate-spin" aria-hidden />}
      {children}
    </button>
  );
}
