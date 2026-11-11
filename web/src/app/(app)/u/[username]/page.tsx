import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { connection } from "next/server";
import { acceptFriendRequestAction, deleteFriendRequestAction, sendFriendRequestAction } from "@/app/actions/friends";
import { ActionButton } from "@/components/action-button";
import { ActivityCard } from "@/components/activity-card";
import { CopyButton } from "@/components/client-bits";
import { CountUp } from "@/components/count-up";
import { Avatar, Empty, Figure, Panel } from "@/components/ui";
import { formatHoursMinutes, formatKm, formatMonthYear } from "@/lib/format";
import { getProfile } from "@/server/activities";
import { ApiError } from "@/server/errors";
import { getSessionUser, getTimeZone } from "@/server/session";

type Props = PageProps<"/u/[username]">;

const appUrl = () => (process.env.APP_URL ?? "http://localhost:3000").replace(/\/$/, "");

async function loadProfile(viewerId: string | null, username: string) {
  if (!/^[a-z0-9_]{3,20}$/i.test(username)) return null;
  try {
    return await getProfile(viewerId, username, { withRoutePreview: true });
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) return null;
    throw error;
  }
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  await connection();
  const { username } = await params;
  const profile = await loadProfile(null, username);
  if (!profile) return { title: "Profiel", robots: { index: false } };
  const title = `${profile.user.displayName} (@${profile.user.username})`;
  const description = profile.user.bio || `Bekijk de sportactiviteiten van ${profile.user.displayName} op Metric.`;
  return {
    title,
    description,
    openGraph: { title, description, url: `${appUrl()}/u/${profile.user.username}`, siteName: "Metric", type: "profile", locale: "nl_NL", images: ["/opengraph-image.png"] },
    twitter: { card: "summary_large_image", title, description, images: ["/opengraph-image.png"] },
  };
}

export default async function ProfilePage({ params }: Props) {
  const [{ username }, viewer, timeZone] = await Promise.all([params, getSessionUser(), getTimeZone()]);
  const profile = await loadProfile(viewer?.id ?? null, username);
  if (!profile) notFound();
  const { user, relation, requestId, stats, activities } = profile;

  const scope =
    relation === "self"
      ? "al je activiteiten"
      : relation === "friends"
        ? "gedeeld met vrienden en openbaar"
        : "alleen openbare activiteiten";

  return (
    <>
      <header className="rise flex flex-wrap items-end justify-between gap-x-6 gap-y-4 pb-6 pt-8 max-sm:pt-5">
        <div className="flex min-w-0 items-center gap-4">
          <Avatar name={user.displayName} size={72} />
          <div className="min-w-0">
            <h1 className="display truncate text-[44px] leading-[1.05] max-sm:text-[34px]">{user.displayName}</h1>
            <p className="text-muted">
              @{user.username} · lid sinds {formatMonthYear(user.createdAt)}
            </p>
          </div>
        </div>
        <div className="flex max-w-full flex-wrap items-center gap-2">
          {!viewer ? (
            <Link href="/register" className="btn btn-primary">
              Maak een account om {user.displayName} toe te voegen
            </Link>
          ) : relation === "self" ? (
            <>
              <CopyButton value={`${appUrl()}/u/${user.username}`} label="Kopieer profiel-link" className="btn btn-primary" />
              <Link href="/settings" className="btn btn-secondary">
                Profiel bewerken
              </Link>
            </>
          ) : relation === "friends" ? (
            <span className="text-muted">Jullie zijn vrienden</span>
          ) : relation === "outgoing" && requestId ? (
            <>
              <span className="text-muted">Verzoek verstuurd</span>
              <ActionButton action={deleteFriendRequestAction.bind(null, requestId)} className="btn btn-outline">
                Intrekken
              </ActionButton>
            </>
          ) : relation === "incoming" && requestId ? (
            <>
              <ActionButton action={acceptFriendRequestAction.bind(null, requestId)} className="btn btn-primary">
                Verzoek accepteren
              </ActionButton>
              <ActionButton action={deleteFriendRequestAction.bind(null, requestId)} className="btn btn-outline">
                Weigeren
              </ActionButton>
            </>
          ) : (
            <ActionButton action={sendFriendRequestAction.bind(null, user.username)} className="btn btn-primary">
              Vriend toevoegen
            </ActionButton>
          )}
        </div>
      </header>
      <div className="grid grid-cols-[minmax(0,1fr)] items-start gap-4 lg:grid-cols-[minmax(0,1fr)_380px]">
        <div className="stagger flex flex-col gap-4">
          {activities.length === 0 ? (
            <Panel title="Activiteiten">
              <Empty>
                {relation === "self"
                  ? "Je hebt nog geen activiteiten."
                  : relation === "friends"
                    ? `${user.displayName} heeft nog niets met vrienden gedeeld.`
                    : `${user.displayName} heeft geen openbare activiteiten. Vrienden zien meer.`}
              </Empty>
            </Panel>
          ) : (
            activities.map((activity) => (
              <ActivityCard key={activity.id} activity={activity} timeZone={timeZone} viewerId={viewer?.id ?? null} />
            ))
          )}
        </div>

        <div className="stagger flex flex-col gap-4 max-lg:order-first">
          <Panel title="Totaal" aside={<span className="text-[14px]">{scope}</span>}>
            <div className="grid grid-cols-3 gap-x-4 gap-y-4 pt-1">
              <Figure label="Activiteiten" value={<CountUp value={stats.count} />} />
              <Figure label="Uur" value={<CountUp value={Math.round(stats.durationSeconds / 3600)} />} />
              <Figure label="Kilometer" value={<CountUp value={Math.round(stats.distanceMeters / 1000)} />} />
            </div>
            <p className="num mt-4 border-t border-line pt-4 text-muted">
              {formatHoursMinutes(stats.durationSeconds)} en {formatKm(stats.distanceMeters, 1)} km in totaal.
            </p>
          </Panel>
          {user.bio ? (
            <Panel title={`Over ${user.displayName}`}>
              <p className="whitespace-pre-line">{user.bio}</p>
            </Panel>
          ) : null}
        </div>
      </div>
    </>
  );
}
