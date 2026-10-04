import { forwardRef } from "react";
import { cn } from "@/lib/cn";

/**
 * Presenta un campo de entrada con etiqueta, icono, mensaje de error y acción opcional.
 * @param {Object} props propiedades del componente
 * @param {string} props.label etiqueta descriptiva del campo
 * @param {React.ComponentType} [props.icon] componente de icono mostrado en el campo
 * @param {string} [props.error] mensaje de error mostrado debajo del campo
 * @param {React.ReactNode} [props.action] acción adicional mostrada dentro del campo
 * @param {string} [props.className] clases CSS adicionales
 * @param {Object} props.ref referencia del elemento de entrada
 * @returns {JSX.Element} campo de entrada renderizado
 */
const Input = forwardRef(function Input({ label, icon: Icon, error, action, className, ...props }, ref) {
  return (
    <label className={cn("grid gap-2 text-sm font-semibold text-copy", className)}>
      <span>{label}</span>
      <span className={cn(
        "flex min-h-12.5 items-center overflow-hidden rounded-[13px] border bg-panel-soft px-3.5 transition focus-within:border-brand-blue focus-within:bg-panel-hover focus-within:outline-3 focus-within:outline-offset-2 focus-within:outline-brand-cyan/20",
        error ? "border-rose-400/70" : "border-line",
      )}>
        {Icon && <Icon className="size-4.5 shrink-0 text-copy-faint" aria-hidden />}
        <input
          ref={ref}
          className="min-w-0 flex-1 border-0 bg-transparent px-2.5 text-copy outline-0 placeholder:text-copy-faint"
          aria-invalid={Boolean(error)}
          {...props}
        />
        {action}
      </span>
      {error && <span className="text-xs font-medium text-rose-300" role="alert">{error}</span>}
    </label>
  );
});

export default Input;
