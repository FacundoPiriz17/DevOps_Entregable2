"use client";

import { useState } from "react";
import Image from "next/image";
import { LuGamepad2 } from "react-icons/lu";
import { gameImage, gameImageAlt } from "@/lib/games";
import { cn } from "@/lib/cn";

/**
 * Presenta la imagen de un videojuego con adaptación según el tipo de contenido.
 * @param {Object} props propiedades del componente
 * @param {Object} props.game información del videojuego
 * @param {string} [props.type="portada"] tipo de imagen a mostrar
 * @param {string} [props.className=""] clases CSS adicionales
 * @param {boolean} [props.priority=false] indica si la imagen debe cargarse con prioridad
 * @returns {JSX.Element} imagen o marcador visual del videojuego renderizado 
 */
export default function GameArtwork({ game, type = "portada", className = "", priority = false }) {
  const image = gameImage(game, type);
  const [failedUrl, setFailedUrl] = useState(null);
  const [loadedImage, setLoadedImage] = useState(null);
  const failed = failedUrl === image;
  const dimensions = loadedImage?.url === image ? loadedImage : null;

  if (!image || failed) {
    return (
      <div className={cn("flex flex-col items-center justify-center gap-2 bg-[radial-gradient(circle_at_30%_20%,rgba(0,189,248,.25),transparent_33%),linear-gradient(145deg,#0d1330,#161c48)] bg-center bg-cover text-slate-400", className)} role="img" aria-label={`Sin portada para ${game?.name || "el juego"}`}>
        <LuGamepad2 className="size-10.5" aria-hidden />
        <span className="text-xs font-extrabold tracking-widest uppercase">PlayHub</span>
      </div>
    );
  }

  const ratio = dimensions ? dimensions.width / dimensions.height : null;
  const mismatchedArtwork = ratio && (
    (type === "portada" && ratio > 1.05)
    || (type === "banner" && ratio < 1.25)
  );
  const lowResolution = dimensions && (
    (type === "portada" && dimensions.width < 480)
    || (type === "banner" && dimensions.width < 960)
  );
  const framedArtwork = mismatchedArtwork || lowResolution;

  return (
    <div
      className={cn("relative overflow-hidden bg-ink-850", className)}
      role="img"
      aria-label={gameImageAlt(game, type)}
    >
      {framedArtwork && (
        <Image
          aria-hidden="true"
          alt=""
          className="absolute inset-0 size-full scale-115 object-cover opacity-45 blur-xl"
          fill
          quality={45}
          sizes={type === "banner" ? "100vw" : "300px"}
          src={image}
          unoptimized
        />
      )}
      <Image
        alt=""
        className={cn(
          "z-1 transition-opacity duration-200",
          framedArtwork ? (lowResolution ? "object-contain p-[7%]" : "object-contain p-[4%]") : "object-cover",
        )}
        fill
        onError={() => setFailedUrl(image)}
        onLoad={(event) => setLoadedImage({
          url: image,
          width: event.currentTarget.naturalWidth,
          height: event.currentTarget.naturalHeight,
        })}
        priority={priority}
        referrerPolicy="no-referrer"
        sizes={type === "banner"
          ? "(max-width: 768px) 100vw, 75vw"
          : "(max-width: 640px) 50vw, (max-width: 1024px) 33vw, 300px"}
        src={image}
        unoptimized
      />
    </div>
  );
}
