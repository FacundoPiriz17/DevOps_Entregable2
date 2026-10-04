"use client";

import { useState } from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { domAnimation, LazyMotion } from "motion/react";
import { AuthProvider } from "@/context/AuthContext";
import { ToastProvider } from "@/context/ToastContext";

/**
 * Configura los proveedores globales de estado, autenticación, notificaciones y consultas.
 * @param {Object} props propiedades del componente
 * @param {React.ReactNode} props.children contenido de la aplicación
 * @returns {JSX.Element} árbol de proveedores renderizado 
 */
export default function Providers({ children }) {
  const [queryClient] = useState(() => new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 5 * 60 * 1000,
        refetchOnWindowFocus: false,
        retry: 1,
      },
    },
  }));

  return (
    <LazyMotion features={domAnimation} strict>
      <QueryClientProvider client={queryClient}>
        <ToastProvider>
          <AuthProvider>{children}</AuthProvider>
        </ToastProvider>
      </QueryClientProvider>
    </LazyMotion>
  );
}
