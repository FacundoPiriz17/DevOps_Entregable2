import { z } from "zod";


/**
 * Define las reglas de validación para el formulario de inicio de sesión.
 * @returns {import("zod").ZodObject} esquema de validación de las credenciales
 */
export const loginSchema = z.object({
  email: z.string().trim().min(1, "Ingresá tu correo.").email("Ingresá un correo válido."),
  password: z.string().min(1, "Ingresá tu contraseña."),
});

/**
 * Define las reglas de validación para el formulario de registro.
 * @returns {import("zod").ZodEffects} esquema de validación de los datos de registro
 */
export const registerSchema = z.object({
  name: z.string().trim().min(2, "Ingresá al menos 2 caracteres."),
  email: z.string().trim().min(1, "Ingresá tu correo.").email("Ingresá un correo válido."),
  country: z.string().trim().min(2, "Ingresá tu país."),
  password: z.string().min(8, "La contraseña debe tener al menos 8 caracteres."),
  confirmPassword: z.string().min(1, "Repetí la contraseña."),
}).refine((data) => data.password === data.confirmPassword, {
  message: "Las contraseñas no coinciden.",
  path: ["confirmPassword"],
});
