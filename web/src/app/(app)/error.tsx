"use client";

export default function AppError({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <div className="pt-8">
      <h1 className="text-[24px] font-bold leading-8">Dit scherm kon niet worden geladen</h1>
      <p className="mt-1 text-muted">Er ging iets mis bij het ophalen van de gegevens. Je activiteiten zijn veilig.</p>
      <button type="button" className="btn btn-primary mt-5" onClick={() => reset()}>
        Opnieuw proberen
      </button>
    </div>
  );
}
