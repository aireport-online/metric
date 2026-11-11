"use client";

export default function AppError({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <div className="rise pt-8">
      <h1 className="display text-[44px] leading-[1.05] max-sm:text-[34px]">Dit scherm kon niet worden geladen</h1>
      <p className="mt-1 text-muted">Er ging iets mis bij het ophalen van de gegevens. Je activiteiten zijn veilig.</p>
      <button type="button" className="btn btn-primary mt-5" onClick={() => reset()}>
        Opnieuw proberen
      </button>
    </div>
  );
}
