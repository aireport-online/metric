import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { connection } from "next/server";
import { z } from "zod";
import { deleteCommentAction } from "@/app/actions/activities";
import { KudosButton } from "@/components/activity-card";
import { CommentForm, EditActivityForm } from "@/components/activity-forms";
import { ConfirmSubmit, CopyButton } from "@/components/client-bits";
import { RouteMap } from "@/components/route-map";
import { Avatar, Empty, Panel } from "@/components/ui";
import { ACTIVITY_INFO, SOURCE_LABEL, VISIBILITY_LABEL, activityTitle } from "@/lib/activity-types";
import { formatClock, formatCount, formatFullDate, formatKm, formatRate, formatWhen } from "@/lib/format";
import { getActivityDetail } from "@/server/activities";
import { ApiError } from "@/server/errors";
import { getSessionUser, getTimeZone } from "@/server/session";

type Props = PageProps<"/activities/[id]">;

const appUrl = () => (process.env.APP_URL ?? "http://localhost:3000").replace(/\/$/, "");

async function loadDetail(viewerId: string | null, id: string) {
  if (!z.guid().safeParse(id).success) return null;
  try {
    return await getActivityDetail(viewerId, id);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) return null;
    throw error;
  }
}

/** Link previews are built from what anyone may see, so only public activities get a real title. */
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  // Always looked up for the request at hand; an activity can change visibility at any moment.
  await connection();
  const { id } = await params;
  const detail = await loadDetail(null, id);
  if (!detail) return { title: "Activiteit", robots: { index: false } };
  const { activity } = detail;
  const title = `${activityTitle(activity)} van ${activity.user.displayName}`;
  const parts = [
    ACTIVITY_INFO[activity.type].label,
    activity.distanceMeters ? `${formatKm(activity.distanceMeters)} km` : null,
    formatClock(activity.durationSeconds),
  ].filter(Boolean);
  const description = `${parts.join(" · ")} — bekijk deze activiteit op Metric.`;
  return {
    title,
    description,
    openGraph: { title, description, url: `${appUrl()}/activities/${activity.id}`, siteName: "Metric", type: "article", locale: "nl_NL" },
    twitter: { card: "summary", title, description },
  };
}

function Stat({ label, value, unit }: { label: string; value: string; unit?: string }) {
  return (
    <div>
      <dt className="text-[12px] leading-4 text-muted">{label}</dt>
      <dd className="num mt-1 text-[24px] leading-8">
        {value}
        {unit ? <span className="ml-1 text-[14px] text-muted">{unit}</span> : null}
      </dd>
    </div>
  );
}

export default async function ActivityPage({ params, searchParams }: Props) {
  const [{ id }, query, viewer, timeZone] = await Promise.all([params, searchParams, getSessionUser(), getTimeZone()]);
  const detail = await loadDetail(viewer?.id ?? null, id);
  if (!detail) notFound();

  const { activity, comments } = detail;
  const info = ACTIVITY_INFO[activity.type];
  const isOwner = viewer?.id === activity.user.id;
  const editing = isOwner && query.edit !== undefined;
  const rate = formatRate(activity.type, activity.distanceMeters, activity.durationSeconds);
  const shareUrl = `${appUrl()}/activities/${activity.id}`;

  return (
    <>
      <header className="flex flex-wrap items-end justify-between gap-x-6 gap-y-4 pb-6 pt-8 max-sm:pt-5">
        <div className="min-w-0">
          <h1 className="text-[24px] font-bold leading-8 tracking-[-0.01em]">{activityTitle(activity)}</h1>
          <p className="mt-2 flex items-center gap-2">
            <Avatar username={activity.user.username} name={activity.user.displayName} size={24} />
            <Link href={`/u/${activity.user.username}`} className="font-medium hover:underline">
              {activity.user.displayName}
            </Link>
          </p>
          <p className="mt-1 text-muted">
            {info.label} · <time dateTime={activity.startedAt}>{formatFullDate(activity.startedAt, timeZone)}</time> · via{" "}
            {SOURCE_LABEL[activity.source]}
          </p>
        </div>
        <div className="flex max-w-full flex-wrap items-center gap-2">
          <KudosButton activityId={activity.id} count={activity.kudosCount} on={activity.hasKudoed} canKudo={viewer !== null} size="md" />
          {activity.visibility === "public" || isOwner ? (
            <CopyButton value={shareUrl} />
          ) : null}
          {isOwner && !editing ? (
            <Link href={`/activities/${activity.id}?edit`} className="btn btn-secondary">
              Bewerken
            </Link>
          ) : null}
        </div>
      </header>

      {/* 776 + 12 + 364 = 1152 */}
      <div className="grid items-start gap-3 lg:grid-cols-[minmax(0,1fr)_364px]">
        <div className="flex flex-col gap-3">
          <section className="panel p-5" aria-label="Cijfers">
            <dl className="grid grid-cols-2 gap-x-8 gap-y-5 sm:grid-cols-3 lg:grid-cols-4">
              {activity.distanceMeters ? <Stat label="Afstand" value={formatKm(activity.distanceMeters)} unit="km" /> : null}
              <Stat label="Duur" value={formatClock(activity.durationSeconds)} />
              {rate ? <Stat label={rate.label} value={rate.value} unit={rate.unit} /> : null}
              {activity.avgHeartRate ? <Stat label="Gemiddelde hartslag" value={String(activity.avgHeartRate)} unit="bpm" /> : null}
              {activity.maxHeartRate ? <Stat label="Hoogste hartslag" value={String(activity.maxHeartRate)} unit="bpm" /> : null}
              {activity.activeEnergyKcal ? <Stat label="Energie" value={formatCount(activity.activeEnergyKcal)} unit="kcal" /> : null}
              {activity.elevationGainMeters ? <Stat label="Hoogtemeters" value={formatCount(activity.elevationGainMeters)} unit="m" /> : null}
            </dl>
          </section>

          {editing ? (
            <EditActivityForm id={activity.id} title={activity.title} notes={activity.notes} type={activity.type} visibility={activity.visibility} />
          ) : null}

          {activity.route && activity.route.length >= 2 ? (
            <Panel
              title="Route"
              aside={
                <ul className="flex items-center gap-4 text-[12px]">
                  <li className="flex items-center gap-1.5">
                    <span className="h-2.5 w-2.5 rounded-full border-2 border-ink bg-surface" aria-hidden />
                    Start
                  </li>
                  <li className="flex items-center gap-1.5">
                    <span className="h-2.5 w-2.5 rounded-full bg-ink" aria-hidden />
                    Finish
                  </li>
                </ul>
              }
            >
              <RouteMap route={activity.route} label={`Route van ${activityTitle(activity)}`} />
            </Panel>
          ) : null}

          {activity.notes && !editing ? (
            <Panel title="Notitie">
              <p className="max-w-[70ch] whitespace-pre-line">{activity.notes}</p>
            </Panel>
          ) : null}
        </div>

        <div className="flex flex-col gap-3">
          <Panel title="Reacties" aside={<span className="num text-[12px]">{comments.length}</span>}>
            <div id="reacties" className="flex scroll-mt-4 flex-col gap-4">
              {comments.length === 0 ? <Empty>Nog geen reacties.</Empty> : null}
              {comments.map((comment) => (
                <div key={comment.id} className="flex gap-3">
                  <Avatar username={comment.user.username} name={comment.user.displayName} size={32} />
                  <div className="min-w-0 flex-1">
                    <p className="flex flex-wrap items-baseline gap-x-2">
                      <Link href={`/u/${comment.user.username}`} className="font-medium hover:underline">
                        {comment.user.displayName}
                      </Link>
                      <span className="text-[12px] text-muted">{formatWhen(comment.createdAt, timeZone)}</span>
                    </p>
                    <p className="whitespace-pre-line break-words">{comment.body}</p>
                    {viewer && (viewer.id === comment.user.id || isOwner) ? (
                      <form action={deleteCommentAction.bind(null, comment.id)}>
                        <ConfirmSubmit message="Deze reactie verwijderen?" className="mt-0.5 text-[12px] text-muted underline-offset-2 hover:text-negative hover:underline">
                          Verwijderen
                        </ConfirmSubmit>
                      </form>
                    ) : null}
                  </div>
                </div>
              ))}
              {viewer ? (
                <CommentForm activityId={activity.id} />
              ) : (
                <p className="text-muted">
                  <Link href="/login" className="link">
                    Log in
                  </Link>{" "}
                  om kudos te geven of te reageren.
                </p>
              )}
            </div>
          </Panel>

          <Panel title="Zichtbaarheid">
            <p>
              {VISIBILITY_LABEL[activity.visibility]}
              <span className="text-muted">
                {activity.visibility === "private"
                  ? " — niemand anders ziet deze activiteit."
                  : activity.visibility === "friends"
                    ? " — de link werkt alleen voor ingelogde vrienden."
                    : " — iedereen met de link kan deze activiteit bekijken."}
              </span>
            </p>
          </Panel>
        </div>
      </div>
    </>
  );
}
