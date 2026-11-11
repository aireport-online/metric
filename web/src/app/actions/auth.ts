"use server";

import { refresh } from "next/cache";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { deleteMeSchema, loginSchema, registerSchema, updateMeSchema } from "@/lib/schemas";
import { authenticate, deleteUser, registerUser, updateUser } from "@/server/auth";
import { formError, formOk, type FormState } from "@/server/form";
import { rateLimit } from "@/server/rate-limit";
import { endWebSession, requireUser, startWebSession } from "@/server/session";

async function clientIp() {
  return (await headers()).get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
}

const field = (form: FormData, name: string) => String(form.get(name) ?? "");

export async function loginAction(_prev: FormState, form: FormData): Promise<FormState> {
  try {
    const input = loginSchema.parse({ email: field(form, "email"), password: field(form, "password") });
    rateLimit(`login:${await clientIp()}:${input.email}`, 10, 15 * 60 * 1000);
    const user = await authenticate(input);
    await startWebSession(user.id);
  } catch (error) {
    return formError(error, form);
  }
  redirect("/feed");
}

export async function registerAction(_prev: FormState, form: FormData): Promise<FormState> {
  try {
    rateLimit(`register:${await clientIp()}`, 10, 60 * 60 * 1000);
    const input = registerSchema.parse({
      email: field(form, "email"),
      password: field(form, "password"),
      username: field(form, "username"),
      displayName: field(form, "displayName"),
    });
    const user = await registerUser(input);
    await startWebSession(user.id);
  } catch (error) {
    return formError(error, form);
  }
  redirect("/feed");
}

export async function logoutAction() {
  await endWebSession();
  redirect("/");
}

export async function updateProfileAction(_prev: FormState, form: FormData): Promise<FormState> {
  const user = await requireUser();
  try {
    // Each settings panel posts only its own fields.
    const raw: Record<string, unknown> = {};
    if (form.has("displayName")) raw.displayName = field(form, "displayName");
    if (form.has("bio")) raw.bio = field(form, "bio");
    if (form.has("weeklyGoalMinutes")) raw.weeklyGoalMinutes = Number(field(form, "weeklyGoalMinutes"));
    if (form.has("defaultVisibility")) raw.defaultVisibility = field(form, "defaultVisibility");
    await updateUser(user.id, updateMeSchema.parse(raw));
  } catch (error) {
    return formError(error, form);
  }
  refresh();
  return formOk();
}

export async function deleteAccountAction(_prev: FormState, form: FormData): Promise<FormState> {
  const user = await requireUser();
  try {
    const { password } = deleteMeSchema.parse({ password: field(form, "password") });
    await deleteUser(user, password);
    await endWebSession();
  } catch (error) {
    return formError(error, form);
  }
  redirect("/");
}
