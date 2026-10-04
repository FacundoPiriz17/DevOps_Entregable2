"use client";

import { createContext, useCallback, useContext, useMemo } from "react";
import { sileo, Toaster } from "sileo";

const ToastContext = createContext(null);

const toastOptions = {
  fill: "#0d1330",
  roundness: 18,
  duration: 4200,
  styles: {
    title: "!font-semibold !text-white",
    description: "!text-slate-300",
  },
};

/**
 * Proporciona el sistema de notificaciones de la aplicación a los componentes hijos.
 * @param {Object} props propiedades del componente
 * @param {React.ReactNode} props.children contenido que tendrá acceso al contexto
 * @returns {JSX.Element} proveedor de notificaciones renderizado
 */
export function ToastProvider({ children }) {
  const notify = useCallback((message, type = "info") => {
    const method = ["success", "error", "warning", "info"].includes(type) ? type : "info";
    sileo[method]({ ...toastOptions, title: message });
  }, []);

  const value = useMemo(() => ({ notify }), [notify]);

  return (
    <ToastContext.Provider value={value}>
      <Toaster position="top-right" offset={{ top: 82, right: 16 }} options={toastOptions}>
        {children}
      </Toaster>
    </ToastContext.Provider>
  );
}

/**
 * Obtiene el contexto de notificaciones disponible para el componente actual.
 * @returns {Object} función para mostrar notificaciones
 * @throws {Error} si se utiliza fuera de un ToastProvider
 */
export function useToast() {
  const context = useContext(ToastContext);
  if (!context) throw new Error("useToast debe utilizarse dentro de ToastProvider");
  return context;
}
