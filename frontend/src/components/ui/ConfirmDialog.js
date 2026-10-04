"use client";

import { useEffect, useEffectEvent } from "react";
import { LuX } from "react-icons/lu";
import { AnimatePresence } from "motion/react";
import * as m from "motion/react-m";
import Button from "./Button";

/**
 * Presenta un diálogo modal para confirmar una acción.
 * @param {Object} props propiedades del componente
 * @param {boolean} props.open indica si el diálogo está visible
 * @param {string} props.title título principal del diálogo
 * @param {string} props.description descripción de la acción a confirmar
 * @param {string} [props.confirmLabel="Confirmar"] texto del botón de confirmación
 * @param {boolean} [props.loading=false] indica si la confirmación está en proceso
 * @param {Function} props.onClose función ejecutada al cerrar el diálogo
 * @param {Function} props.onConfirm función ejecutada al confirmar la acción
 * @param {React.ReactNode} [props.children] contenido adicional del diálogo 
 * @returns {JSX.Element} diálogo de confirmación renderizado
 */
export default function ConfirmDialog({
  open,
  title,
  description,
  confirmLabel = "Confirmar",
  loading = false,
  onClose,
  onConfirm,
  children,
}) {
  const closeFromEscape = useEffectEvent(() => {
    if (!loading) onClose();
  });

  useEffect(() => {
    if (!open) return undefined;
    const handleKey = (event) => {
      if (event.key === "Escape") closeFromEscape();
    };
    window.addEventListener("keydown", handleKey);
    return () => window.removeEventListener("keydown", handleKey);
  }, [open]);

  return (
    <AnimatePresence>
      {open && (
        <m.div
          className="fixed inset-0 z-300 flex items-center justify-center bg-ink-950/75 p-5 backdrop-blur-lg"
          role="presentation"
          onMouseDown={loading ? undefined : onClose}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
        >
          <m.section
            className="relative w-full max-w-lg rounded-3xl border border-line bg-panel p-8 text-copy shadow-float"
            role="dialog"
            aria-modal="true"
            aria-labelledby="dialog-title"
            onMouseDown={(event) => event.stopPropagation()}
            initial={{ opacity: 0, y: 18, scale: 0.97 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 12, scale: 0.98 }}
          >
            <button className="absolute top-4.5 right-4.5 flex size-9 items-center justify-center rounded-full border border-line bg-panel-soft text-copy-soft hover:bg-panel-hover" type="button" onClick={onClose} disabled={loading} aria-label="Cerrar">
              <LuX aria-hidden />
            </button>
            <span className="text-xs font-extrabold tracking-widest text-brand-blue uppercase">Confirmación</span>
            <h2 className="mt-2.5 mr-10 mb-2 text-2xl font-bold tracking-tight" id="dialog-title">{title}</h2>
            <p className="text-sm leading-relaxed text-copy-soft">{description}</p>
            {children}
            <div className="mt-6 flex justify-end gap-2 max-sm:flex-col-reverse">
              <Button type="button" variant="ghost" onClick={onClose} disabled={loading}>Volver</Button>
              <Button type="button" onClick={onConfirm} loading={loading}>{confirmLabel}</Button>
            </div>
          </m.section>
        </m.div>
      )}
    </AnimatePresence>
  );
}
