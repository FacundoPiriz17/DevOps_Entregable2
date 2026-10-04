import { NextResponse } from "next/server";

const AUTH_COOKIE = "playhub_session";
const AUTH_ROUTES = new Set(["/login", "/register"]);

/**
 * Controla el acceso a las rutas según el estado de autenticación del usuario.
 * @param {import("next/server").NextRequest} request solicitud recibida por el proxy
 * @returns {import("next/server").NextResponse} respuesta de redirección o continuación de la solicitud
 */
export function proxy(request) {
  const { pathname } = request.nextUrl;
  const authenticated = Boolean(request.cookies.get(AUTH_COOKIE)?.value);

  if (authenticated && AUTH_ROUTES.has(pathname)) {
    return NextResponse.redirect(new URL("/catalog", request.url));
  }

  if (!authenticated && !AUTH_ROUTES.has(pathname)) {
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("next", pathname);
    return NextResponse.redirect(loginUrl);
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    "/login",
    "/register",
    "/catalog/:path*",
    "/games/:path*",
    "/library/:path*",
    "/wishlist/:path*",
    "/cart/:path*",
  ],
};
