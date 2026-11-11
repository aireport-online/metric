import Link from "next/link";
import { Logo } from "@/components/logo";

export default function NotFound() {
  return (
    <div className="column">
      <header className="flex h-12 items-center">
        <Link href="/" aria-label="Metric, naar de startpagina">
          <Logo />
        </Link>
      </header>
      <main className="pt-8">
        <h1 className="text-[24px] font-bold leading-8">Niet gevonden</h1>
        <p className="mt-1 text-muted">Deze pagina bestaat niet (meer).</p>
        <Link href="/" className="btn btn-primary mt-5">
          Naar de startpagina
        </Link>
      </main>
    </div>
  );
}
