"use client";

import Link from "next/link";
import { useActionState } from "react";
import { loginAction, registerAction } from "@/app/actions/auth";
import { SubmitButton } from "./client-bits";
import { FormMessage } from "./ui";

export function LoginForm() {
  const [state, action] = useActionState(loginAction, undefined);
  return (
    <form action={action} key={state?.nonce ?? "form"} className="panel flex flex-col gap-4 p-5">
      <div>
        <label htmlFor="email" className="label">
          E-mailadres
        </label>
        <input id="email" name="email" type="email" autoComplete="email" required defaultValue={state?.values?.email} className="input" />
      </div>
      <div>
        <label htmlFor="password" className="label">
          Wachtwoord
        </label>
        <input id="password" name="password" type="password" autoComplete="current-password" required className="input" />
      </div>
      <FormMessage state={state} />
      <SubmitButton pendingLabel="Inloggen…">Inloggen</SubmitButton>
      <p className="text-muted">
        Nog geen account?{" "}
        <Link href="/register" className="link">
          Account aanmaken
        </Link>
      </p>
    </form>
  );
}

export function RegisterForm() {
  const [state, action] = useActionState(registerAction, undefined);
  return (
    <form action={action} key={state?.nonce ?? "form"} className="panel flex flex-col gap-4 p-5">
      <div>
        <label htmlFor="displayName" className="label">
          Naam
        </label>
        <input id="displayName" name="displayName" autoComplete="name" required maxLength={50} defaultValue={state?.values?.displayName} className="input" />
      </div>
      <div>
        <label htmlFor="username" className="label">
          Gebruikersnaam
        </label>
        <input
          id="username"
          name="username"
          autoComplete="username"
          autoCapitalize="none"
          required
          minLength={3}
          maxLength={20}
          pattern="[A-Za-z0-9_]{3,20}"
          aria-describedby="username-help"
          defaultValue={state?.values?.username}
          className="input"
        />
        <p id="username-help" className="mt-1.5 text-[12px] text-muted">
          3–20 letters, cijfers of _. Hiermee vinden vrienden je en dit staat in je profiel-link.
        </p>
      </div>
      <div>
        <label htmlFor="email" className="label">
          E-mailadres
        </label>
        <input id="email" name="email" type="email" autoComplete="email" required defaultValue={state?.values?.email} className="input" />
      </div>
      <div>
        <label htmlFor="password" className="label">
          Wachtwoord
        </label>
        <input
          id="password"
          name="password"
          type="password"
          autoComplete="new-password"
          required
          minLength={8}
          aria-describedby="password-help"
          className="input"
        />
        <p id="password-help" className="mt-1.5 text-[12px] text-muted">
          Minimaal 8 tekens.
        </p>
      </div>
      <FormMessage state={state} />
      <SubmitButton pendingLabel="Account aanmaken…">Account aanmaken</SubmitButton>
      <p className="text-muted">
        Heb je al een account?{" "}
        <Link href="/login" className="link">
          Inloggen
        </Link>
      </p>
    </form>
  );
}
