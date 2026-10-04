import "./globals.css";
import Providers from "./providers";

export const metadata = {
  title: {
    default: "PlayHub",
    template: "%s | PlayHub",
  },
  description: "Descubrí, elegí y organizá tus próximos videojuegos en PlayHub.",
  icons: {
    icon: "/playhub-mark.png",
    apple: "/playhub-mark.png",
  },
};

export const viewport = {
  colorScheme: "dark",
  themeColor: "#050817",
};

/**
 * Define la estructura raíz de la aplicación y sus proveedores globales.
 * @param {Object} props propiedades del componente 
 * @param {React.ReactNode} props.children contenido de las páginas de la aplicación
 * @returns {JSX.Element} Estructura HTML raíz de la aplicación.
 */
export default function RootLayout({ children }) {
  return (
    <html lang="es">
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
