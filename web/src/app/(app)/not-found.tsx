import Link from "next/link";

export default function NotFound() {
  return (
    <div className="pt-8">
      <h1 className="text-[24px] font-bold leading-8">Niet gevonden</h1>
      <p className="mt-1 max-w-xl text-muted">
        Deze pagina bestaat niet, of is alleen zichtbaar voor de eigenaar en diens vrienden. Log in met het juiste
        account als iemand deze link met je heeft gedeeld.
      </p>
      <div className="mt-5 flex gap-2">
        <Link href="/feed" className="btn btn-primary">
          Naar je feed
        </Link>
        <Link href="/login" className="btn btn-secondary">
          Inloggen
        </Link>
      </div>
    </div>
  );
}
