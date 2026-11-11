import { toMinutes } from "@/lib/format";

export type Day = { day: string; durationSeconds: number; isToday: boolean };

const WEEKDAYS = ["ma", "di", "wo", "do", "vr", "za", "zo"];

/** One sentence about where the week stands; the same words on every screen that shows the goal. */
export function goalSentence(minutes: number, goal: number, days: Day[]): string {
  const todayIndex = Math.max(
    days.findIndex((day) => day.isToday),
    0,
  );
  const daysLeft = 6 - todayIndex;
  if (minutes >= goal) {
    return minutes === goal ? "Weekdoel precies gehaald." : `Weekdoel gehaald, ${minutes - goal} min erboven.`;
  }
  const left = `Nog ${goal - minutes} min tot je weekdoel`;
  if (daysLeft === 0) return `${left}, vandaag is de laatste dag.`;
  return `${left}, ${daysLeft === 1 ? "nog 1 dag" : `nog ${daysLeft} dagen`} na vandaag.`;
}

/**
 * The week against its goal: a track as long as the goal (or as the week, once it runs past the goal,
 * with a tick where the goal sits) and the seven days underneath.
 */
export function WeekGoal({ seconds, goalMinutes, days, large = false }: { seconds: number; goalMinutes: number; days: Day[]; large?: boolean }) {
  const minutes = toMinutes(seconds);
  const scale = Math.max(minutes, goalMinutes);
  const todayIndex = days.findIndex((day) => day.isToday);
  const dayMinutes = days.map((day) => toMinutes(day.durationSeconds));
  const maxDay = Math.max(...dayMinutes, 1);

  return (
    <div>
      <p className="num flex items-baseline gap-1.5">
        <span className={`${large ? "text-[30px] leading-9" : "text-[24px] leading-8"} font-medium tracking-[-0.01em]`}>{minutes}</span>
        <span className="text-muted">van {goalMinutes} min</span>
      </p>
      <p className="mt-1 text-muted">{goalSentence(minutes, goalMinutes, days)}</p>

      <div
        className="relative mt-4 h-2 rounded-full bg-raised"
        role="progressbar"
        aria-label="Weekdoel"
        aria-valuemin={0}
        aria-valuemax={goalMinutes}
        aria-valuenow={Math.min(minutes, goalMinutes)}
        aria-valuetext={`${minutes} van ${goalMinutes} minuten`}
      >
        {minutes > 0 ? <div className="h-full rounded-full bg-hue" style={{ width: `${(minutes / scale) * 100}%` }} /> : null}
        {minutes > goalMinutes ? (
          <span className="absolute -top-1 h-4 w-0.5 bg-ink" style={{ left: `${(goalMinutes / scale) * 100}%` }} aria-hidden />
        ) : null}
      </div>
      <div className="num mt-1.5 flex justify-between text-[12px] leading-4 text-muted">
        <span>0</span>
        {minutes > goalMinutes ? <span>doel {goalMinutes} · nu {minutes} min</span> : <span>{goalMinutes} min</span>}
      </div>

      <ol className="mt-4 grid grid-cols-7 gap-1.5" aria-label="Minuten per dag deze week">
        {days.map((day, i) => {
          const future = todayIndex >= 0 && i > todayIndex;
          return (
            <li key={day.day} className="flex flex-col items-center">
              <span className="flex h-10 w-full items-end justify-center" aria-hidden>
                {dayMinutes[i] > 0 ? (
                  <span className="w-full max-w-[28px] rounded-t-[3px] bg-ink" style={{ height: `max(2px, ${(dayMinutes[i] / maxDay) * 100}%)` }} />
                ) : (
                  <span className="h-px w-full max-w-[28px] bg-control" />
                )}
              </span>
              <span className={`num mt-1 text-[12px] leading-4 ${dayMinutes[i] > 0 ? "text-ink" : "text-muted"}`}>
                {future ? "–" : dayMinutes[i]}
                <span className="sr-only"> minuten</span>
              </span>
              <span className={`text-[12px] leading-4 ${day.isToday ? "font-medium text-ink" : "text-muted"}`}>
                {WEEKDAYS[i]}
                {day.isToday ? <span className="sr-only"> (vandaag)</span> : null}
              </span>
            </li>
          );
        })}
      </ol>
    </div>
  );
}
