import type { Metadata } from "next";
import { NewActivityForm } from "@/components/activity-forms";
import { PageTitle } from "@/components/ui";
import { toLocalInputValue } from "@/lib/format";
import { getTimeZone, requireUser } from "@/server/session";

export const metadata: Metadata = { title: "Activiteit toevoegen" };

export default async function NewActivityPage() {
  const user = await requireUser();
  const timeZone = await getTimeZone();
  // Default to half an hour ago: the usual case is logging something you just finished.
  const defaultStart = toLocalInputValue(new Date(Date.now() - 30 * 60 * 1000), timeZone);

  return (
    <>
      <PageTitle title="Activiteit toevoegen" />
      {/* 440 + 12 + 700 = 1152 */}
      <div className="grid items-start gap-3 lg:grid-cols-[440px_minmax(0,700px)]">
        <div className="max-w-[40ch] text-muted lg:pt-1">
          <p>
            Workouts die je met de iPhone- of Watch-app opneemt komen hier vanzelf binnen, met route en hartslag. Dit
            formulier is voor alles wat je zonder horloge deed.
          </p>
          <p className="mt-3">Tempo of snelheid berekenen we uit afstand en duur.</p>
        </div>
        <NewActivityForm defaultStart={defaultStart} defaultVisibility={user.defaultVisibility} />
      </div>
    </>
  );
}
