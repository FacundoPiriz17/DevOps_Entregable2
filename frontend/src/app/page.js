import { redirect } from "next/navigation";

/**
 * Redirige la página principal hacia el catálogo de videojuegos.
 * @returns {never} la ejecución no continúa después de la redirección
 */
export default function Home() {
  redirect("/catalog");
}
