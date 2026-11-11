import type { Metadata } from "next";
import { RegisterForm } from "@/components/auth-forms";

export const metadata: Metadata = { title: "Account aanmaken" };

export default function RegisterPage() {
  return (
    <>
      <h1 className="pb-5 display text-[44px] leading-[1.05] max-sm:text-[34px]">Account aanmaken</h1>
      <RegisterForm />
    </>
  );
}
