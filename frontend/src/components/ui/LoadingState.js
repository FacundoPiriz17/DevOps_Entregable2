import Image from "next/image";

/**
 * Presenta un estado de carga con el logotipo de PlayHub y un mensaje.
 * @param {Object} props propiedades del componente 
 * @param {string} [props.label="Cargando PlayHub..."] mensaje mostrado durante la carga
 * @returns {JSX.Element} Elemento que representa el estado de carga.
 */
export default function LoadingState({ label = "Cargando PlayHub..." }) {
  return (
    <div className="flex min-h-[60vh] flex-col items-center justify-center gap-3.5 text-sm font-semibold text-copy-soft" role="status">
      <span className="animate-float-mark inline-flex">
        <Image className="size-20.5 object-contain" src="/playhub-mark.png" alt="" width={88} height={88} />
      </span>
      <span>{label}</span>
    </div>
  );
}
