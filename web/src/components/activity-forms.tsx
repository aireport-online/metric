"use client";

import Link from "next/link";
import { useActionState } from "react";
import { addCommentAction, createActivityAction, deleteActivityAction, updateActivityAction } from "@/app/actions/activities";
import { ACTIVITY_INFO, VISIBILITY_LABEL } from "@/lib/activity-types";
import { ACTIVITY_TYPES, VISIBILITIES, type ActivityType, type Visibility } from "@/lib/constants";
import { ConfirmSubmit, SubmitButton } from "./client-bits";
import { SportIcon } from "./icons";
import { FormMessage } from "./ui";

/** Sport as a row of chips: each with its pictogram in its own tint, one of them chosen. */
function SportPicker({ defaultValue }: { defaultValue: ActivityType }) {
  return (
    <fieldset>
      <legend className="label">Sport</legend>
      <div className="flex flex-wrap gap-2">
        {ACTIVITY_TYPES.map((type) => (
          <label
            key={type}
            className="press flex h-11 cursor-pointer items-center gap-2 rounded-full bg-raised pl-3.5 pr-4 text-[15px] font-medium text-muted transition-colors duration-200 hover:text-ink has-[:checked]:bg-ink has-[:checked]:text-on-accent has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-offset-2 has-[:focus-visible]:outline-ink"
          >
            <input type="radio" name="type" value={type} defaultChecked={type === defaultValue} className="peer sr-only" />
            <span className="peer-checked:hidden">
              <SportIcon type={type} size={18} />
            </span>
            <span className="hidden peer-checked:block">
              <SportIcon type={type} size={18} tinted={false} />
            </span>
            {ACTIVITY_INFO[type].label}
          </label>
        ))}
      </div>
    </fieldset>
  );
}

function VisibilitySelect({ defaultValue }: { defaultValue: Visibility }) {
  return (
    <select id="visibility" name="visibility" defaultValue={defaultValue} className="input">
      {VISIBILITIES.map((visibility) => (
        <option key={visibility} value={visibility}>
          {VISIBILITY_LABEL[visibility]}
        </option>
      ))}
    </select>
  );
}

export function NewActivityForm({ defaultStart, defaultVisibility }: { defaultStart: string; defaultVisibility: Visibility }) {
  const [state, action] = useActionState(createActivityAction, undefined);
  const v = state?.values;
  return (
    <form action={action} key={state?.nonce ?? "form"} className="panel flex flex-col gap-5 p-6 max-sm:p-5">
      <SportPicker defaultValue={(v?.type as ActivityType | undefined) ?? "run"} />
      <div className="sm:max-w-[50%] sm:pr-2">
        <label htmlFor="startedAt" className="label">
          Begonnen op
        </label>
        <input id="startedAt" name="startedAt" type="datetime-local" required defaultValue={v?.startedAt ?? defaultStart} className="input" />
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <fieldset>
          <legend className="label">Duur</legend>
          <div className="flex items-center gap-2">
            <input name="hours" inputMode="numeric" type="number" min={0} max={167} placeholder="0" aria-label="Uren" defaultValue={v?.hours} className="input num" />
            <span className="figure-label text-muted">u</span>
            <input name="minutes" inputMode="numeric" type="number" min={0} max={59} placeholder="30" aria-label="Minuten" defaultValue={v?.minutes} className="input num" />
            <span className="figure-label text-muted">min</span>
          </div>
        </fieldset>
        <div>
          <label htmlFor="distanceKm" className="label">
            Afstand <span className="font-normal text-muted">(optioneel)</span>
          </label>
          <div className="flex items-center gap-2">
            <input id="distanceKm" name="distanceKm" inputMode="decimal" placeholder="5,0" defaultValue={v?.distanceKm} className="input num" />
            <span className="figure-label text-muted">km</span>
          </div>
        </div>
      </div>
      <div>
        <label htmlFor="title" className="label">
          Titel <span className="font-normal text-muted">(optioneel)</span>
        </label>
        <input id="title" name="title" maxLength={80} placeholder="Ochtendrun langs de Amstel" defaultValue={v?.title} className="input" />
      </div>
      <div>
        <label htmlFor="notes" className="label">
          Notitie <span className="font-normal text-muted">(optioneel)</span>
        </label>
        <textarea id="notes" name="notes" rows={3} maxLength={2000} defaultValue={v?.notes} className="input" />
      </div>
      <div className="sm:max-w-[50%] sm:pr-2">
        <label htmlFor="visibility" className="label">
          Zichtbaar voor
        </label>
        <VisibilitySelect defaultValue={(v?.visibility as Visibility | undefined) ?? defaultVisibility} />
      </div>
      <FormMessage state={state} />
      <div className="flex gap-2">
        <SubmitButton pendingLabel="Opslaan…">Activiteit opslaan</SubmitButton>
        <Link href="/activities" className="btn btn-secondary">
          Annuleren
        </Link>
      </div>
    </form>
  );
}

export function EditActivityForm({
  id,
  title,
  fallbackTitle,
  notes,
  type,
  visibility,
}: {
  id: string;
  title: string;
  /** What the activity is called while it has no title of its own. */
  fallbackTitle: string;
  notes: string;
  type: ActivityType;
  visibility: Visibility;
}) {
  const [state, action] = useActionState(updateActivityAction.bind(null, id), undefined);
  return (
    <div className="panel p-6 max-sm:p-5">
      <h2 className="display text-[24px] leading-[1.1]">Activiteit bewerken</h2>
      <form action={action} key={state?.nonce ?? "form"} className="mt-4 flex flex-col gap-5">
        <div>
          <label htmlFor="title" className="label">
            Titel
          </label>
          <input id="title" name="title" maxLength={80} defaultValue={state?.values?.title ?? title} placeholder={fallbackTitle} className="input" />
        </div>
        <SportPicker defaultValue={(state?.values?.type as ActivityType | undefined) ?? type} />
        <div className="sm:max-w-[50%] sm:pr-2">
          <label htmlFor="visibility" className="label">
            Zichtbaar voor
          </label>
          <VisibilitySelect defaultValue={(state?.values?.visibility as Visibility | undefined) ?? visibility} />
        </div>
        <div>
          <label htmlFor="notes" className="label">
            Notitie
          </label>
          <textarea id="notes" name="notes" rows={4} maxLength={2000} defaultValue={state?.values?.notes ?? notes} className="input" />
        </div>
        <FormMessage state={state} />
        <div className="flex gap-2">
          <SubmitButton pendingLabel="Opslaan…">Opslaan</SubmitButton>
          <Link href={`/activities/${id}`} className="btn btn-secondary">
            Annuleren
          </Link>
        </div>
      </form>
      <form action={deleteActivityAction.bind(null, id)} className="mt-5 flex flex-wrap items-center justify-between gap-3 border-t border-rule pt-4">
        <p className="text-muted">Verwijderen haalt de activiteit ook weg uit de feed van je vrienden.</p>
        <ConfirmSubmit message="Deze activiteit definitief verwijderen?">Activiteit verwijderen</ConfirmSubmit>
      </form>
    </div>
  );
}

export function CommentForm({ activityId }: { activityId: string }) {
  const [state, action] = useActionState(addCommentAction.bind(null, activityId), undefined);
  return (
    // Remounting after a successful post clears the field.
    <form action={action} key={state?.ok ? state.nonce : "form"} className="flex flex-col gap-2">
      <label htmlFor="comment-body" className="sr-only">
        Reactie
      </label>
      <textarea id="comment-body" name="body" rows={2} maxLength={500} required placeholder="Schrijf een reactie" className="input" />
      <FormMessage state={state} />
      <div>
        <SubmitButton className="btn btn-sm btn-primary" pendingLabel="Plaatsen…">
          Plaatsen
        </SubmitButton>
      </div>
    </form>
  );
}
