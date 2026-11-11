import type { Metadata } from "next";
import { RegisterForm } from "@/components/auth-forms";

export const metadata: Metadata = { title: "Account aanmaken" };

export default function RegisterPage() {
  return (
    <>
      <h1 className="pb-5 text-[24px] font-bold leading-8 tracking-[-0.01em]">Account aanmaken</h1>
      <RegisterForm />
    </>
  );
}
