/**
 * Presenta un estado vacío con icono, título, descripción y acción opcional.
 * @param {Object} props propiedades del componente
 * @param {React.ComponentType} [props.icon] componente de icono mostrado en el estado vacío
 * @param {string} props.title título principal del estado
 * @param {string} props.description descripción del estado 
 * @param {React.ReactNode} [props.action] acción opcional mostrada al usuario
 * @returns {JSX.Element} Elemento que representa el estado vacío.
 */
export default function EmptyState({ icon: Icon, title, description, action }) {
  return (
    <div className="flex min-h-82.5 flex-col items-center justify-center rounded-3xl border border-dashed border-line bg-panel p-10 text-center shadow-card">
      {Icon && <Icon className="size-16.5 rounded-2xl border border-indigo-400/15 bg-indigo-400/10 p-4 text-brand-cyan" aria-hidden />}
      <h2 className="mt-4.5 mb-2 text-2xl font-bold tracking-tight">{title}</h2>
      <p className="mb-5 max-w-md leading-relaxed text-copy-soft">{description}</p>
      {action}
    </div>
  );
}
