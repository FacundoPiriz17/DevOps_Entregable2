import AppShell from "@/components/layout/AppShell";
import { StoreProvider } from "@/context/StoreContext";

/**
 * Presenta el layout principal de la tienda.
 * @param {Object} props propiedades del componente
 * @param {React.ReactNode} props.children contenido de la página 
 * @returns {JSX.Element} estructura principal de la tienda
 */
export default function StoreLayout({ children }) {
  return (
    <StoreProvider>
      <AppShell>{children}</AppShell>
    </StoreProvider>
  );
}
