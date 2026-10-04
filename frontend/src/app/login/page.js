"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { LuArrowRight, LuEye, LuEyeOff, LuLockKeyhole, LuMail } from "react-icons/lu";
import AuthShell from "@/components/auth/AuthShell";
import Button from "@/components/ui/Button";
import Input from "@/components/ui/Input";
import { useAuth } from "@/context/AuthContext";
import { useToast } from "@/context/ToastContext";
import { loginSchema } from "@/lib/authSchemas";

/**
 * Presenta el formulario de inicio de sesión de la aplicación
 * @returns {JSX.Element} página de inicio de sesión renderizada
 */
export default function LoginPage() {
  const router = useRouter();
  const { login } = useAuth();
  const { notify } = useToast();
  const [showPassword, setShowPassword] = useState(false);
  const { register, handleSubmit, setError, formState: { errors, isSubmitting } } = useForm({
    resolver: zodResolver(loginSchema),
    defaultValues: { email: "", password: "" },
  });

  /**
   * Procesa las credenciales del formulario e inicia la sesión
   * @param {Object} form datos introducidos por el usuario
   * @param {string} form.email correo electrónico del usuario
   * @param {string} form.password contraseña del usuario
   * @returns {Promise<void>} promesa que representa el proceso de autenticación 
   */
  const onSubmit = async (form) => {
    try {
      const nextSession = await login({
        email: form.email.trim(),
        password: form.password,
      });
      notify(`¡Hola, ${nextSession.user.name}!`, "success");
      router.replace("/catalog");
    } catch (requestError) {
      setError("root.server", { message: requestError.message });
    }
  };

  return (
    <AuthShell
      title="Iniciá sesión"
      subtitle="Volvé a tu catálogo, carrito y biblioteca personal."
    >
      <form className="grid gap-5" onSubmit={handleSubmit(onSubmit)} noValidate>
        <Input
          label="Correo electrónico"
          icon={LuMail}
          type="email"
          autoComplete="email"
          placeholder="tu@email.com"
          error={errors.email?.message}
          {...register("email")}
        />

        <Input
          label="Contraseña"
          icon={LuLockKeyhole}
          type={showPassword ? "text" : "password"}
          autoComplete="current-password"
          placeholder="Mínimo 8 caracteres"
          error={errors.password?.message}
          action={(
            <button
              type="button"
              className="inline-flex border-0 bg-transparent p-1.5 text-slate-400"
              onClick={() => setShowPassword((current) => !current)}
              aria-label={showPassword ? "Ocultar contraseña" : "Mostrar contraseña"}
            >
              {showPassword ? <LuEyeOff aria-hidden /> : <LuEye aria-hidden />}
            </button>
          )}
          {...register("password")}
        />

        {errors.root?.server && <p className="rounded-xl border border-rose-400/30 bg-rose-400/10 p-3 text-sm text-rose-200" role="alert">{errors.root.server.message}</p>}

        <Button type="submit" size="large" loading={isSubmitting} className="w-full">
          Entrar a PlayHub <LuArrowRight aria-hidden />
        </Button>
      </form>

      <p className="mt-6 text-center text-sm text-copy-soft">
        ¿Todavía no tenés cuenta? <Link className="font-bold text-brand-blue hover:underline" href="/register">Creá una</Link>
      </p>
    </AuthShell>
  );
}
