import type { CSSProperties } from "react";
import { toMinutes } from "@/lib/format";
import { CountUp } from "./count-up";
import { Track } from "./track";

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
 * The week as a track: the outer lane is the minutes against the goal, the inner lane the days
 * with an activity out of seven. The minutes count up in the infield while the lanes run out, and
 * the seven days stand underneath as lane numbers.
 */
export function WeekGoal({
  seconds,
  goalMinutes,
  days,
  large = false,
  sentence = true,
}: {
  seconds: number;
  goalMinutes: number;
  days: Day[];
  large?: boolean;
  sentence?: boolean;
}) {
  const minutes = toMinutes(seconds);
  const todayIndex = days.findIndex((day) => day.isToday);
  const dayMinutes = days.map((day) => toMinutes(day.durationSeconds));
  const maxDay = Math.max(...dayMinutes, 1);
  const activeDays = dayMinutes.filter((m) => m > 0).length;
  const reached = minutes >= goalMinutes;

  return (
    <div>
      <Track
        className="mx-auto"
        width={large ? 520 : 320}
        thickness={large ? 16 : 10}
        lanes={[{ progress: goalMinutes > 0 ? minutes / goalMinutes : 0 }, { progress: activeDays / 7 }]}
        label={`Weekdoel: ${minutes} van ${goalMinutes} minuten. ${activeDays} van 7 dagen actief.`}
      >
        <span className={`figure-xl ${large ? "text-[96px] max-sm:text-[64px]" : "text-[56px]"} ${reached ? "text-volt" : ""}`}>
          <CountUp value={minutes} />
        </span>
        <span className="figure-label text-muted">van {goalMinutes} min</span>
      </Track>

      <ul className="mt-4 flex flex-wrap justify-center gap-x-5 gap-y-1 text-[14px] text-muted">
        <li className="flex items-center gap-2">
          <span className="h-[3px] w-4 rounded-full bg-accent" aria-hidden />
          Minuten
        </li>
        <li className="flex items-center gap-2">
          <span className="h-[3px] w-4 rounded-full bg-ink" aria-hidden />
          <span className="num">{activeDays} van 7 dagen actief</span>
        </li>
      </ul>

      {sentence ? <p className="mt-3 text-center text-muted">{goalSentence(minutes, goalMinutes, days)}</p> : null}

      <ol className={`mx-auto mt-5 grid grid-cols-7 gap-1.5 ${large ? "max-w-[520px]" : "max-w-[320px]"}`} aria-label="Minuten per dag deze week">
        {days.map((day, i) => {
          const future = todayIndex >= 0 && i > todayIndex;
          return (
            <li key={day.day} className="flex flex-col items-center">
              <span className="flex h-12 w-full items-end justify-center" aria-hidden>
                {dayMinutes[i] > 0 ? (
                  <span
                    className={`grow-y w-full max-w-[26px] rounded-t-[6px] ${day.isToday ? "bg-accent" : "bg-ink"}`}
                    style={{ height: `max(4px, ${(dayMinutes[i] / maxDay) * 100}%)`, "--i": i } as CSSProperties}
                  />
                ) : (
                  <span className="h-[3px] w-full max-w-[26px] rounded-full bg-line" />
                )}
              </span>
              <span className={`figure mt-1.5 text-[20px] ${dayMinutes[i] > 0 ? "text-ink" : "text-quiet"}`}>
                {future ? "–" : dayMinutes[i]}
                <span className="sr-only"> minuten</span>
              </span>
              <span className={`text-[13px] leading-5 ${day.isToday ? "font-semibold text-ink" : "text-quiet"}`}>
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
