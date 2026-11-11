/** The final layout with flat bars where the values will land; no shimmer, no layout shift. */
export default function Loading() {
  return (
    <div aria-busy="true" aria-label="Laden">
      <div className="pb-6 pt-8 max-sm:pt-5">
        <div className="skeleton h-8 w-40" />
        <div className="skeleton mt-2 h-5 w-72 max-w-full" />
      </div>
      <div className="grid items-start gap-3 lg:grid-cols-[minmax(0,1fr)_364px]">
        <div className="flex flex-col gap-3">
          {[0, 1, 2].map((i) => (
            <div key={i} className="panel p-5">
              <div className="flex gap-3">
                <div className="skeleton h-10 w-10 rounded-full" />
                <div className="flex-1">
                  <div className="skeleton h-5 w-48 max-w-full" />
                  <div className="skeleton mt-2 h-4 w-28" />
                  <div className="skeleton mt-3 h-6 w-64 max-w-full" />
                </div>
              </div>
            </div>
          ))}
        </div>
        <div className="panel p-5 max-lg:hidden">
          <div className="skeleton h-6 w-28" />
          <div className="skeleton mt-4 h-8 w-36" />
          <div className="skeleton mt-4 h-2 w-full" />
        </div>
      </div>
    </div>
  );
}
