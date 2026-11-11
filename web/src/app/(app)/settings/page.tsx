import type { Metadata } from "next";
import { logoutAction } from "@/app/actions/auth";
import { DeleteAccountForm, GoalForm, ProfileForm, VisibilityForm } from "@/components/settings-forms";
import { PageTitle } from "@/components/ui";
import { VISIBILITY_LABEL } from "@/lib/activity-types";
import { requireUser } from "@/server/session";

export const metadata: Metadata = { title: "Instellingen" };

/** One settings section: what it is on the left, its controls on the right. 440 + 12 + 700 = 1152. */
function Section({ title, description, children }: { title: string; description: React.ReactNode; children: React.ReactNode }) {
  return (
    <section className="grid gap-x-3 gap-y-4 border-t border-line py-8 first:border-t-0 first:pt-0 lg:grid-cols-[440px_minmax(0,700px)]">
      <div className="max-w-[44ch] lg:pt-2">
        <h2 className="text-[16px] font-medium leading-6">{title}</h2>
        <div className="mt-1 text-muted">{description}</div>
      </div>
      <div className="rounded-card bg-surface p-5 ring-1 ring-line">{children}</div>
    </section>
  );
}

export default async function SettingsPage() {
  const user = await requireUser();
  return (
    <>
      <PageTitle title="Instellingen" sub={`@${user.username} · ${user.email}`} />
      <Section title="Profiel" description="Je naam en beschrijving staan op je profiel en bij je activiteiten in de feed van vrienden.">
        <ProfileForm displayName={user.displayName} bio={user.bio} />
      </Section>
      <Section
        title="Weekdoel"
        description={
          <>
            Hoeveel minuten je per week wilt bewegen. Nu: <span className="num text-ink">{user.weeklyGoalMinutes} minuten</span>. De
            iPhone- en Watch-app gebruiken hetzelfde doel.
          </>
        }
      >
        <GoalForm weeklyGoalMinutes={user.weeklyGoalMinutes} />
      </Section>
      <Section
        title="Zichtbaarheid"
        description={
          <>
            Geldt voor nieuwe activiteiten; per activiteit kun je het daarna nog aanpassen. Nu:{" "}
            <span className="text-ink">{VISIBILITY_LABEL[user.defaultVisibility].toLowerCase()}</span>.
          </>
        }
      >
        <VisibilityForm defaultVisibility={user.defaultVisibility} />
      </Section>
      <Section title="Sessie" description="Uitloggen op dit apparaat. De app op je iPhone blijft ingelogd.">
        <form action={logoutAction} className="flex justify-end">
          <button type="submit" className="btn btn-secondary">
            Uitloggen
          </button>
        </form>
      </Section>
      <Section
        title="Account verwijderen"
        description="Verwijdert je account, al je activiteiten, kudos, reacties en vriendschappen. Dit kan niet ongedaan worden gemaakt."
      >
        <DeleteAccountForm username={user.username} />
      </Section>
    </>
  );
}
