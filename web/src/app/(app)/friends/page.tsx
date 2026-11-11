import type { Metadata } from "next";
import Link from "next/link";
import {
  acceptFriendRequestAction,
  deleteFriendRequestAction,
  removeFriendAction,
  sendFriendRequestAction,
} from "@/app/actions/friends";
import { ActionButton } from "@/components/action-button";
import { CopyButton } from "@/components/client-bits";
import { LeaderboardList, leaderboardValue } from "@/components/leaderboard";
import { Avatar, Empty, PageTitle, Panel } from "@/components/ui";
import { formatWeekStart } from "@/lib/format";
import { listFriends, searchUsers, type Relation } from "@/server/friends";
import { getTimeZone, requireUser } from "@/server/session";
import { getLeaderboard, type LeaderboardMetric } from "@/server/stats";

export const metadata: Metadata = { title: "Vrienden" };

const METRICS: { id: LeaderboardMetric; label: string }[] = [
  { id: "duration", label: "Tijd" },
  { id: "distance", label: "Afstand" },
  { id: "count", label: "Aantal" },
];

const RELATION_NOTE: Record<Exclude<Relation, "none" | "incoming">, string> = {
  self: "Dit ben jij",
  friends: "Al vrienden",
  outgoing: "Verzoek verstuurd",
};

function Person({
  user,
  children,
  wrap = false,
}: {
  user: { username: string; displayName: string };
  children?: React.ReactNode;
  /** Lets the actions drop to a second line when the name and two buttons do not fit. */
  wrap?: boolean;
}) {
  return (
    <li className={`flex min-h-12 items-center gap-x-3 gap-y-2 border-t border-rule py-2 first:border-t-0 ${wrap ? "flex-wrap" : ""}`}>
      <Avatar username={user.username} name={user.displayName} size={32} />
      <Link href={`/u/${user.username}`} className={`min-w-0 flex-1 hover:underline ${wrap ? "basis-32" : ""}`}>
        <span className="block truncate font-medium">{user.displayName}</span>
        <span className="block truncate text-[12px] leading-4 text-muted">@{user.username}</span>
      </Link>
      <div className={`flex flex-none items-center gap-2 ${wrap ? "ml-auto" : ""}`}>{children}</div>
    </li>
  );
}

export default async function FriendsPage({ searchParams }: PageProps<"/friends">) {
  const [user, timeZone, query] = await Promise.all([requireUser(), getTimeZone(), searchParams]);
  const metric = METRICS.find((m) => m.id === query.metric)?.id ?? "duration";
  const q = typeof query.q === "string" ? query.q.trim() : "";

  const [{ friends, incoming, outgoing }, board, results] = await Promise.all([
    listFriends(user.id),
    getLeaderboard(user, metric, timeZone),
    q.length >= 2 ? searchUsers(user.id, q) : Promise.resolve([]),
  ]);

  const profileUrl = `${(process.env.APP_URL ?? "http://localhost:3000").replace(/\/$/, "")}/u/${user.username}`;
  const leader = board.entries[0];
  const finding =
    incoming.length > 0
      ? `${incoming.length === 1 ? "1 vriendschapsverzoek wacht" : `${incoming.length} vriendschapsverzoeken wachten`} op je antwoord.`
      : board.entries.length > 1 && leader.value > 0
        ? `${leader.isMe ? "Jij staat" : `${leader.user.displayName} staat`} deze week bovenaan met ${leaderboardValue(metric, leader.value)}.`
        : friends.length === 0
          ? "Deel je profiel-link om je eerste vriend toe te voegen."
          : undefined;

  return (
    <>
      <PageTitle title="Vrienden" sub={finding} action={<CopyButton value={profileUrl} label="Kopieer je profiel-link" className="btn btn-primary" />} />

      {/* 776 + 12 + 364 = 1152 */}
      <div className="grid items-start gap-3 lg:grid-cols-[minmax(0,1fr)_364px]">
        <div className="flex flex-col gap-3">
          <Panel
            title="Ranglijst van deze week"
            aside={board.weekStart ? <span className="text-[12px]">sinds maandag {formatWeekStart(board.weekStart)}</span> : null}
          >
            <div className="mb-3 inline-flex rounded-control bg-raised p-0.5" role="group" aria-label="Rangschikken op">
              {METRICS.map((m) => (
                <Link
                  key={m.id}
                  href={m.id === "duration" ? "/friends" : `/friends?metric=${m.id}`}
                  aria-current={m.id === metric ? "true" : undefined}
                  className={`flex h-8 items-center rounded-[4px] px-3 font-medium ${m.id === metric ? "bg-surface text-ink" : "text-muted hover:text-ink"}`}
                >
                  {m.label}
                </Link>
              ))}
            </div>
            <LeaderboardList board={board} />
          </Panel>

          <Panel title="Je vrienden" aside={<span className="num text-[12px]">{friends.length}</span>}>
            {friends.length === 0 ? (
              <Empty>Je hebt nog geen vrienden toegevoegd. Zoek iemand op gebruikersnaam of deel je profiel-link.</Empty>
            ) : (
              <ul>
                {friends.map((friend) => (
                  <Person key={friend.id} user={friend}>
                    <ActionButton
                      action={removeFriendAction.bind(null, friend.id)}
                      className="btn btn-sm btn-outline"
                      confirm={`${friend.displayName} verwijderen als vriend? Jullie zien elkaars activiteiten voor vrienden dan niet meer.`}
                    >
                      Verwijderen
                    </ActionButton>
                  </Person>
                ))}
              </ul>
            )}
          </Panel>
        </div>

        <div className="flex flex-col gap-3 max-lg:order-first">
          {incoming.length > 0 || outgoing.length > 0 ? (
            <Panel title="Verzoeken" aside={incoming.length > 0 ? <span className="num text-[12px]">{incoming.length} nieuw</span> : null}>
              <ul>
                {incoming.map((request) => (
                  <Person key={request.id} user={request.user} wrap>
                    <ActionButton action={acceptFriendRequestAction.bind(null, request.id)} className="btn btn-sm btn-primary">
                      Accepteren
                    </ActionButton>
                    <ActionButton action={deleteFriendRequestAction.bind(null, request.id)} className="btn btn-sm btn-outline">
                      Weigeren
                    </ActionButton>
                  </Person>
                ))}
                {outgoing.map((request) => (
                  <Person key={request.id} user={request.user}>
                    <span className="text-[12px] text-muted max-[400px]:hidden">Verstuurd</span>
                    <ActionButton action={deleteFriendRequestAction.bind(null, request.id)} className="btn btn-sm btn-outline">
                      Intrekken
                    </ActionButton>
                  </Person>
                ))}
              </ul>
            </Panel>
          ) : null}

          <Panel title="Vriend zoeken">
            <form action="/friends" className="flex gap-2" role="search">
              <label htmlFor="q" className="sr-only">
                Naam of gebruikersnaam
              </label>
              <input id="q" name="q" defaultValue={q} minLength={2} required placeholder="Naam of gebruikersnaam" className="input" autoCapitalize="none" />
              {metric !== "duration" ? <input type="hidden" name="metric" value={metric} /> : null}
              <button type="submit" className="btn btn-secondary h-10">
                Zoeken
              </button>
            </form>
            {q.length >= 2 ? (
              results.length === 0 ? (
                <p className="mt-3 text-muted">Niemand gevonden voor “{q}”.</p>
              ) : (
                <ul className="mt-2">
                  {results.map((result) => (
                    <Person key={result.id} user={result}>
                      {result.relation === "none" ? (
                        <ActionButton action={sendFriendRequestAction.bind(null, result.username)} className="btn btn-sm btn-primary">
                          Uitnodigen
                        </ActionButton>
                      ) : result.relation === "incoming" ? (
                        <ActionButton action={sendFriendRequestAction.bind(null, result.username)} className="btn btn-sm btn-primary">
                          Accepteren
                        </ActionButton>
                      ) : (
                        <span className="text-[12px] text-muted">{RELATION_NOTE[result.relation]}</span>
                      )}
                    </Person>
                  ))}
                </ul>
              )
            ) : null}
          </Panel>

          <Panel title="Je profiel-link">
            <p className="text-muted">Wie deze link opent kan je een verzoek sturen en ziet je openbare activiteiten.</p>
            <p className="mt-3 break-all rounded-control bg-raised px-3 py-2.5 font-mono text-[12px] leading-4">{profileUrl}</p>
          </Panel>
        </div>
      </div>
    </>
  );
}
