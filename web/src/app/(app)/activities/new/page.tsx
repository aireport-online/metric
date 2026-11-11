import type { Metadata } from "next";
import { NewActivityForm } from "@/components/activity-forms";
import { PageTitle, Panel } from "@/components/ui";
import { recentStartValue } from "@/lib/format";
import { getTimeZone, requireUser } from "@/server/session";

export const metadata: Metadata = { title: "Activiteit toevoegen" };

export default async function NewActivityPage() {
  const user = await requireUser();
  const timeZone = await getTimeZone();
  const defaultStart = recentStartValue(timeZone);

  return (
    <>
      <PageTitle title="Activiteit toevoegen" sub="Voor alles wat je zonder iPhone of Apple Watch deed." />
      <div className="grid grid-cols-[minmax(0,1fr)] items-start gap-4 lg:grid-cols-[minmax(0,1fr)_380px]">
        <NewActivityForm defaultStart={defaultStart} defaultVisibility={user.defaultVisibility} />
        <Panel title="Automatisch bijhouden">
          <p>
            Workouts die je met de iPhone- of Watch-app opneemt komen hier vanzelf binnen, met route, hartslag en
            energie.
          </p>
          <p className="mt-3 text-muted">
            Wat je hier invoert telt net zo mee voor je weekdoel en je reeks. Tempo of snelheid berekenen we uit afstand
            en duur.
          </p>
        </Panel>
      </div>
    </>
  );
}
