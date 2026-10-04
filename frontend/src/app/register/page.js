"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { LuArrowRight, LuEarth, LuLockKeyhole, LuMail, LuUserRound } from "react-icons/lu";
import AuthShell from "@/components/auth/AuthShell";
import Button from "@/components/ui/Button";
import Input from "@/components/ui/Input";
import { useAuth } from "@/context/AuthContext";
import { useToast } from "@/context/ToastContext";
import { registerSchema } from "@/lib/authSchemas";

const initialForm = {
  name: "",
  email: "",
  country: "Uruguay",
  password: "",
  confirmPassword: "",
};

/**
 * Presenta el formulario de registro de una nueva cuenta.
 * @returns {JSX.Element} página renderizada de registro 
 */
export default function RegisterPage() {
  const router = useRouter();
  const { register: createAccount } = useAuth();
  const { notify } = useToast();
  const { register, handleSubmit, setError, formState: { errors, isSubmitting } } = useForm({
    resolver: zodResolver(registerSchema),
    defaultValues: initialForm,
  });

  /**
   * Procesa el registro de una nueva cuenta y gestiona los errores de la solicitud.
   * @param {Object} form datos ingresados en el formulario
   * @param {string} form.name nombre del usuario
   * @param {string} form.email correo electrónico del usuario
   * @param {string} form.country país del usuario
   * @param {string} form.password contraseña elegida
   * @param {string} form.confirmPassword confirmación de la contraseña
   * @returns {Promise<void>} promesa que representa el proceso de registro
   */
  const onSubmit = async (form) => {
    try {
      await createAccount({
        name: form.name.trim(),
        email: form.email.trim(),
        country: form.country.trim(),
        password: form.password,
      });
      notify("Tu cuenta de PlayHub quedó pronta.", "success");
      router.replace("/catalog");
    } catch (requestError) {
      setError("root.server", { message: requestError.message });
    }
  };

  return (
    <AuthShell
      title="Creá tu cuenta"
      subtitle="Empezá a descubrir juegos y armá una biblioteca que sea realmente tuya."
    >
      <form className="grid gap-4" onSubmit={handleSubmit(onSubmit)} noValidate>
        <div className="grid gap-3.5 sm:grid-cols-2">
          <Input label="Nombre" icon={LuUserRound} type="text" autoComplete="name" placeholder="Tu nombre" error={errors.name?.message} {...register("name")} />
          <Input label="País" icon={LuEarth} type="text" autoComplete="country-name" placeholder="Uruguay" error={errors.country?.message} {...register("country")} />
        </div>

        <Input label="Correo electrónico" icon={LuMail} type="email" autoComplete="email" placeholder="tu@email.com" error={errors.email?.message} {...register("email")} />

        <div className="grid gap-3.5 sm:grid-cols-2">
          <Input label="Contraseña" icon={LuLockKeyhole} type="password" autoComplete="new-password" placeholder="8+ caracteres" error={errors.password?.message} {...register("password")} />
          <Input label="Confirmar" icon={LuLockKeyhole} type="password" autoComplete="new-password" placeholder="Repetí la contraseña" error={errors.confirmPassword?.message} {...register("confirmPassword")} />
        </div>

        {errors.root?.server && <p className="rounded-xl border border-rose-400/30 bg-rose-400/10 p-3 text-sm text-rose-200" role="alert">{errors.root.server.message}</p>}

        <Button type="submit" size="large" loading={isSubmitting} className="w-full">
          Crear mi cuenta <LuArrowRight aria-hidden />
        </Button>
      </form>

      <p className="mt-6 text-center text-sm text-copy-soft">
        ¿Ya tenés cuenta? <Link className="font-bold text-brand-blue hover:underline" href="/login">Iniciá sesión</Link>
      </p>
    </AuthShell>
  );
}
