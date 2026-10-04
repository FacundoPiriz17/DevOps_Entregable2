"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { api } from "@/lib/api";

const AuthContext = createContext(null);
/**
 * Proporciona el estado y las operaciones de autenticación a los componentes hijos.
 * @param {Object} props propiedades del componente
 * @param {React.ReactNode} props.children contenido que tendrá acceso al contexto
 * @returns {JSX.Element} proveedor de autenticación renderizado
 */
export function AuthProvider({ children }) {
  const router = useRouter();
  const [session, setSession] = useState(null);
  const [ready, setReady] = useState(false);

  const clearSession = useCallback(() => {
    setSession(null);
  }, []);

  const logout = useCallback(async () => {
    let logoutError = null;
    try {
      await api.auth.logout();
    } catch (error) {
      logoutError = error;
    }
    clearSession();
    router.replace("/login");
    if (logoutError) throw logoutError;
  }, [clearSession, router]);

  useEffect(() => {
    api.users.me({ notifyUnauthorized: false })
      .then((user) => {
        setSession({ user });
      })
      .catch(clearSession)
      .finally(() => setReady(true));
  }, [clearSession]);

  useEffect(() => {
    const handleUnauthorized = () => {
      clearSession();
      api.auth.logout().catch(() => {}).finally(() => {
        router.replace("/login?expired=1");
      });
    };

    window.addEventListener("playhub:unauthorized", handleUnauthorized);
    return () => window.removeEventListener("playhub:unauthorized", handleUnauthorized);
  }, [clearSession, router]);

  const saveAuthResponse = useCallback((response) => {
    const user = {
      name: response.name,
      email: response.email,
      country: response.country,
      role: response.role,
      active: true,
    };
    const nextSession = { user };
    setSession(nextSession);
    return nextSession;
  }, []);

  const login = useCallback(async (credentials) => {
    const response = await api.auth.login(credentials);
    return saveAuthResponse(response);
  }, [saveAuthResponse]);

  const register = useCallback(async (data) => {
    const response = await api.auth.register(data);
    return saveAuthResponse(response);
  }, [saveAuthResponse]);

  const value = useMemo(() => ({
    session,
    user: session?.user || null,
    ready,
    authenticated: Boolean(session?.user),
    isUser: session?.user?.role === "USER",
    isAdmin: session?.user?.role === "ADMIN",
    login,
    register,
    logout,
  }), [session, ready, login, register, logout]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

/**
 * Obtiene el contexto de autenticación disponible para el componente actual.
 * @returns {Object} estado y operaciones de autenticación
 * @throws {Error} si se utiliza fuera de un AuthProvider 
 */
export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error("useAuth debe utilizarse dentro de AuthProvider");
  return context;
}
