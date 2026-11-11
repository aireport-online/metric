import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { acceptFriendRequestAction, deleteFriendRequestAction, sendFriendRequestAction } from "@/app/actions/friends";
import { ActionButton } from "@/components/action-button";
import { ActivityCard } from "@/components/activity-card";
import { CopyButton } from "@/components/client-bits";
import { Avatar, Empty, Panel } from "@/components/ui";
import { formatCount, formatHoursMinutes, formatKm, formatMonthYear } from "@/lib/format";
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
  const { username } = await params;
  const profile = await loadProfile(null, username);
  if (!profile) return { title: "Profiel", robots: { index: false } };
  const title = `${profile.user.displayName} (@${profile.user.username})`;
  const description = profile.user.bio || `Bekijk de sportactiviteiten van ${profile.user.displayName} op Metric.`;
  return {
    title,
    description,
    openGraph: { title, description, url: `${appUrl()}/u/${profile.user.username}`, siteName: "Metric", type: "profile", locale: "nl_NL" },
    twitter: { card: "summary", title, description },
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
      <header className="flex flex-wrap items-end justify-between gap-x-6 gap-y-4 pb-6 pt-8 max-sm:pt-5">
        <div className="flex min-w-0 items-center gap-4">
          <Avatar username={user.username} name={user.displayName} size={56} />
          <div className="min-w-0">
            <h1 className="truncate text-[24px] font-bold leading-8 tracking-[-0.01em]">{user.displayName}</h1>
            <p className="text-muted">
              @{user.username} · lid sinds {formatMonthYear(user.createdAt)}
            </p>
          </div>
        </div>
        <div className="flex flex-none flex-wrap items-center gap-2">
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

      {/* 776 + 12 + 364 = 1152 */}
      <div className="grid items-start gap-3 lg:grid-cols-[minmax(0,1fr)_364px]">
        <div className="flex flex-col gap-3">
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

        <div className="flex flex-col gap-3 max-lg:order-first">
          <Panel title="Totaal" aside={<span className="text-[12px]">{scope}</span>}>
            <dl className="grid grid-cols-3 gap-3">
              <div>
                <dt className="text-[12px] leading-4 text-muted">Activiteiten</dt>
                <dd className="num mt-1 text-[24px] leading-8">{formatCount(stats.count)}</dd>
              </div>
              <div>
                <dt className="text-[12px] leading-4 text-muted">Tijd</dt>
                <dd className="num mt-1 text-[24px] leading-8">
                  {formatCount(Math.round(stats.durationSeconds / 3600))}
                  <span className="ml-1 text-[14px] text-muted">u</span>
                </dd>
              </div>
              <div>
                <dt className="text-[12px] leading-4 text-muted">Afstand</dt>
                <dd className="num mt-1 text-[24px] leading-8">
                  {formatCount(Math.round(stats.distanceMeters / 1000))}
                  <span className="ml-1 text-[14px] text-muted">km</span>
                </dd>
              </div>
            </dl>
            <p className="num mt-3 border-t border-rule pt-3 text-muted">
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
