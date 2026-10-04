"use client";

import { useEffect, useRef } from "react";
import useArtworkPalette from "@/hooks/useArtworkPalette";
import { cn } from "@/lib/cn";
import { gameImage } from "@/lib/games";

const gamePalettes = {
  "dark souls": ["hsl(28, 96%, 58%)", "hsl(8, 92%, 55%)"],
  spyro: ["hsl(274, 92%, 63%)", "hsl(38, 96%, 58%)"],
  persona: ["hsl(354, 94%, 58%)", "hsl(12, 92%, 56%)"],
  hades: ["hsl(8, 94%, 58%)", "hsl(42, 96%, 57%)"],
  "hollow knight": ["hsl(190, 92%, 62%)", "hsl(226, 88%, 68%)"],
  zelda: ["hsl(154, 84%, 54%)", "hsl(48, 95%, 58%)"],
  mario: ["hsl(355, 92%, 59%)", "hsl(212, 94%, 62%)"],
  baldur: ["hsl(350, 88%, 58%)", "hsl(38, 94%, 57%)"],
  nier: ["hsl(48, 32%, 70%)", "hsl(205, 52%, 64%)"],
  celeste: ["hsl(326, 92%, 65%)", "hsl(254, 91%, 67%)"],
  bloodborne: ["hsl(350, 82%, 56%)", "hsl(22, 92%, 58%)"],
  "grand theft auto": ["hsl(326, 92%, 62%)", "hsl(190, 94%, 57%)"],
};

/**
 * Obtiene la paleta de colores asociada a un videojuego.
 * @param {Object} game información del videojuego
 * @returns {Array<string>|undefined} colores de la paleta encontrada
 */
function paletteFor(game) {
  const name = game?.name?.toLocaleLowerCase("es") || "";
  return Object.entries(gamePalettes).find(([key]) => name.includes(key))?.[1];
}

/**
 * Presenta un marco visual con efecto de neón adaptado al videojuego.
 * @param {Object} props propiedades del componente
 * @param {Object} props.game información del videojuego
 * @param {string} [props.imageType="portada"] tipo de imagen utilizada para obtener la paleta
 * @param {string} [props.imageUrl] URL personalizada de la imagen
 * @param {number} [props.radius=22] radio de las esquinas del marco
 * @param {boolean} [props.activateFromParent=false] indica si el efecto se activa desde el elemento padre
 * @param {number} [props.speed=380] velocidad utilizada para calcular la duración del efecto
 * @param {string} [props.className] clases CSS adicionales
 * @param {Object} [props.style] estilos adicionales del contenedor
 * @param {React.ReactNode} props.children contenido mostrado dentro del marco
 * @returns {JSX.Element} marco de neón renderizado
 */
export default function NeonFrame({
  game,
  imageType = "portada",
  imageUrl,
  radius = 22,
  activateFromParent = false,
  speed = 380,
  className,
  style,
  children,
}) {
  const frameRef = useRef(null);
  const artworkUrl = imageUrl ?? gameImage(game, imageType);
  const palette = useArtworkPalette(
    artworkUrl,
    `${game?.id}-${game?.name}-${imageType}`,
    paletteFor(game),
  );

  useEffect(() => {
    const frame = frameRef.current;
    if (!frame) return undefined;

    const updateDuration = () => {
      const bounds = frame.getBoundingClientRect();
      const perimeter = 2 * (bounds.width + bounds.height);
      frame.style.setProperty("--neon-duration", `${Math.max(perimeter / speed, 1.4)}s`);
    };

    updateDuration();
    const observer = new ResizeObserver(updateDuration);
    observer.observe(frame);
    return () => observer.disconnect();
  }, [speed]);

  return (
    <div
      ref={frameRef}
      className={cn("neon-frame", activateFromParent && "neon-frame--parent", className)}
      style={{
        ...style,
        "--neon-a": palette[0],
        "--neon-b": palette[1],
        "--neon-radius": `${radius}px`,
      }}
    >
      <svg className="neon-frame__border" aria-hidden="true" focusable="false">
        <rect className="neon-frame__ambient" />
        <rect className="neon-frame__glow" pathLength="100" />
        <rect className="neon-frame__runner" pathLength="100" />
        <rect className="neon-frame__core" pathLength="100" />
      </svg>
      {children}
    </div>
  );
}
