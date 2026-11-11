import type { Metadata } from "next";
import { LoginForm } from "@/components/auth-forms";

export const metadata: Metadata = { title: "Inloggen" };

export default function LoginPage() {
  return (
    <>
      <h1 className="pb-5 display text-[44px] leading-[1.05] max-sm:text-[34px]">Inloggen</h1>
      <LoginForm />
    </>
  );
}
