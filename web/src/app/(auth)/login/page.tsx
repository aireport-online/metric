import type { Metadata } from "next";
import { LoginForm } from "@/components/auth-forms";

export const metadata: Metadata = { title: "Inloggen" };

export default function LoginPage() {
  return (
    <>
      <h1 className="pb-5 text-[24px] font-bold leading-8 tracking-[-0.01em]">Inloggen</h1>
      <LoginForm />
    </>
  );
}
