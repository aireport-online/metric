import Link from "next/link";
import { Logo } from "@/components/logo";

export default function NotFound() {
  return (
    <div className="column">
      <header className="flex h-16 items-center">
        <Link href="/" aria-label="Metric, naar de startpagina">
          <Logo />
        </Link>
      </header>
      <main className="rise pt-8">
        <h1 className="display text-[44px] leading-[1.05] max-sm:text-[34px]">Niet gevonden</h1>
        <p className="mt-1 text-muted">Deze pagina bestaat niet (meer).</p>
        <Link href="/" className="btn btn-primary mt-5">
          Naar de startpagina
        </Link>
      </main>
    </div>
  );
}
